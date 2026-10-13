package packbin

import (
	"math"
	"strconv"
)

// counted packs a sized, bits, packed, u2, repeat or times field.
func (p *packer) counted(f *node, values, wrote map[string]any) error {
	switch f.kind {
	case kindSized:
		return p.sized(f, values, wrote)
	case kindBits, kindPacked:
		return p.items(f, values, wrote)
	case kindU2:
		return p.u2(f, values, wrote)
	case kindRepeat:
		count := roundCount(f.shape, values)
		if err := refuseShortOptional(f.shape, values, count); err != nil {
			return err
		}
		if err := refuseLoneBuffers(f.shape, values); err != nil {
			return err
		}
		return p.rounds(f, count, values)
	case kindTimes:
		count, err := borrowedCount(f, 0, wrote)
		if err != nil {
			return err
		}
		if err := refuseTypedCount(f, values, count); err != nil {
			return err
		}
		if err := refuseLongLists(f.shape, values, count); err != nil {
			return err
		}
		if err := refuseLoneBuffers(f.shape, values); err != nil {
			return err
		}
		return p.rounds(f, count, values)
	}
	return nil
}

// rounds packs count rounds of f, each from its own row and with its own scope.
func (p *packer) rounds(f *node, count int, values map[string]any) error {
	saved := p.scope
	defer func() { p.scope = saved }()
	for i := range count {
		// A round starts here: the one place the round limits (AZ-2444) charge it.
		view := sliceRound(f.shape, values, i)
		p.scope = view
		if err := p.fields(f.fields, scopeRoot{f.fields, view}, view, map[string]any{}); err != nil {
			return err
		}
	}
	return nil
}

// refuseTypedCount: a typed times holds one element a round, so a count other than the elements is
// refused (as C#), naming the member.
func refuseTypedCount(f *node, values map[string]any, count int) error {
	for _, n := range f.shape.names {
		if list, typed := values[n.name].(typedRounds); typed {
			if len(list) != count {
				id, name := roundMember(f)
				return packErr(id, name, "%s: the times count is %d, but the row holds %d rounds", name, count, len(list))
			}
			return nil
		}
	}
	return nil
}

func (p *packer) sized(f *node, values, wrote map[string]any) error {
	count, err := writtenCount(f, wrote)
	if err != nil {
		return err
	}
	v := values[f.name]
	raw, ok := v.([]byte)
	if !ok {
		return packErr(f.id, f.name, "%s: expected []byte for sized, got %s", f.name, typeName(v))
	}
	if count.neg || count.mag != uint64(len(raw)) {
		return packErr(f.id, f.name, "%s: expected %s bytes, got %d", f.name, count, len(raw))
	}
	p.out = append(p.out, raw...)
	wrote[f.name] = v
	return nil
}

// items packs a bits or packed list: count items, width bits each, low bits first.
func (p *packer) items(f *node, values, wrote map[string]any) error {
	count, width, shown := -1, 1, ""
	if f.kind == kindBits {
		n, err := writtenCount(f, wrote)
		if err != nil {
			return err
		}
		shown = n.String()
		if c, ok := countOf(n, 0); ok {
			count = c
		}
	} else {
		var err error
		if count, err = borrowedCount(f, f.bias, wrote); err != nil {
			return err
		}
		shown, width = strconv.Itoa(count), f.width
	}
	v := values[f.name]
	list, ok := itemList(v)
	if !ok || len(list) != count {
		return packErr(f.id, f.name, "%s: expected a list of %s items for %s, got %s", f.name, shown, kindLabel(f), describeList(v))
	}
	top := uint64(1)<<width - 1
	out := make([]byte, itemBytes(width, count))
	for i, item := range list {
		n, isInt := asInt(item)
		if !isInt || n.neg || n.mag > top {
			return packErr(f.id, f.name, "%s: item %d is %s; expected 0..%d", f.name, i, describe(item), top)
		}
		out[i*width/8] |= byte(n.mag) << (i * width % 8)
	}
	p.out = append(p.out, out...)
	wrote[f.name] = v
	return nil
}

func (p *packer) u2(f *node, values, wrote map[string]any) error {
	out := make([]byte, (len(f.fields)+3)/4)
	for i, slot := range f.fields {
		v, given := values[slot.name]
		n, isInt := asInt(v)
		if !given || !isInt || n.neg || n.mag > 3 {
			return packErr(slot.id, slot.name, "%s: expected a 2-bit integer 0..3, got %s", slot.name, describe(v))
		}
		out[i>>2] |= byte(n.mag) << ((i & 3) * 2)
	}
	p.out = append(p.out, out...)
	for _, slot := range f.fields {
		wrote[slot.name] = values[slot.name]
	}
	return nil
}

// itemBytes is the bytes count items of width bits take, without overflow for any count.
func itemBytes(width, count int) int {
	c := max(count, 0)
	return c/8*width + (c%8*width+7)/8
}

// itemList is a bits or packed value as its items, each normalized: any slice, a []byte included.
func itemList(v any) ([]any, bool) {
	if v == nil {
		return nil, false
	}
	if raw, ok := v.([]byte); ok {
		out := make([]any, len(raw))
		for i, b := range raw {
			out[i] = b
		}
		return out, true
	}
	return roundList(v)
}

func describeList(v any) string {
	if list, ok := itemList(v); ok {
		return strconv.Itoa(len(list)) + " items"
	}
	return describe(v)
}

// writtenCount is the count pack wrote in the scope for f; a count field that was skipped or absent
// was not written, and unpack would not read it either.
func writtenCount(f *node, wrote map[string]any) (num, error) {
	raw, ok := wrote[f.ref]
	if !ok {
		return num{}, packErr(f.id, countOwner(f), "%s: count %s was not written", countLabel(f), f.ref)
	}
	n, _ := asInt(raw)
	return n, nil
}

// borrowedCount is the written count plus bias, refused when it is negative.
func borrowedCount(f *node, bias int, wrote map[string]any) (int, error) {
	n, err := writtenCount(f, wrote)
	if err != nil {
		return 0, err
	}
	count, ok := countOf(n, bias)
	if !ok {
		return 0, packErr(f.id, countOwner(f), "%s: item count %s", countLabel(f), withBias(n, bias))
	}
	return count, nil
}

// countLabel is how the text of a refusal about a count names its member: the member's name, or
// "times" (as TypeScript).
func countLabel(f *node) string {
	if f.kind == kindTimes {
		return "times"
	}
	return f.name
}

// countOwner is the name the refusal carries: the member, or a times's first round member.
func countOwner(f *node) string {
	if f.kind == kindTimes {
		_, name := roundMember(f)
		return name
	}
	return f.name
}

// countOf is a count read or written plus bias, as an int; false when it is negative or too large.
func countOf(n num, bias int) (int, bool) {
	if n.neg {
		return 0, false
	}
	if n.mag > math.MaxInt {
		return 0, false
	}
	c := int(n.mag) + bias
	return c, c >= 0
}

// withBias is n + bias (bias 0 or -1) as text, exact for every 64-bit n.
func withBias(n num, bias int) string {
	switch {
	case bias == 0:
		return n.String()
	case n.neg:
		return "-" + strconv.FormatUint(n.mag+1, 10)
	case n.mag == 0:
		return "-1"
	}
	return strconv.FormatUint(n.mag-1, 10)
}

func (n num) String() string {
	if n.neg {
		return "-" + strconv.FormatUint(n.mag, 10)
	}
	return strconv.FormatUint(n.mag, 10)
}

// rowCount is the count the row gives for f's count field, read from the scope's row along the groups
// that hold it; nil when the row gives none.
func (p *packer) rowCount(f *node) any {
	m := p.scope
	for _, g := range f.refPath {
		m, _ = m[g].(map[string]any)
	}
	return m[f.ref]
}

// rowCountAbove0 is a count the row gives as a whole number above 0 after bias (an integer, or a whole
// float), and its value before the bias.
func rowCountAbove0(raw any, bias int) (string, bool) {
	if n, ok := asInt(raw); ok {
		if n.neg {
			return "", false
		}
		// A count too large to read is still a count above 0 the row gives (U23).
		return n.String(), n.mag > math.MaxInt || int(n.mag)+bias > 0
	}
	x, ok := asNumber(raw)
	if !ok || x != math.Trunc(x) || x+float64(bias) <= 0 {
		return "", false
	}
	return strconv.FormatFloat(x, 'f', -1, 64), true
}

// refuseUnwrittenCount refuses a times, bits, packed or sized in the scope of f (itself, or under
// groups, flags, flag bits and a when whose condition holds) whose count the row gives above 0
// although no field wrote it, which is what a clear when that holds the count leaves: the bit is clear
// and nothing is read, so the count the row gives would mean nothing (U6, U11).
func (p *packer) refuseUnwrittenCount(f *node, values, wrote map[string]any) error {
	switch f.kind {
	case kindTimes, kindBits, kindPacked, kindSized:
		if _, ok := wrote[f.ref]; ok {
			return nil
		}
		shown, above := rowCountAbove0(p.rowCount(f), f.bias)
		if !above {
			return nil
		}
		if f.kind == kindTimes {
			id, name := roundMember(f)
			return packErr(id, name, "%s: the count %s is %s in the row, but no field wrote it (the when that holds it "+
				"is clear), so its times reads no round; give the count 0, leave it out, or make the when hold", name, f.ref, shown)
		}
		return packErr(f.id, f.name, "%s: the count %s is %s in the row, but no field wrote it (the when that holds it "+
			"is clear), so the member reads nothing; give the count 0, leave it out, or make the when hold", f.name, f.ref, shown)
	case kindWhen:
		if !sameValue(written(wrote, f.ref), f.eqValue) {
			return nil
		}
		return p.refuseUnwrittenIn(f.fields, values, wrote)
	case kindGroup:
		return p.refuseUnwrittenIn(f.fields, groupValues(values, f), wrote)
	case kindFlags:
		return p.refuseUnwrittenIn(f.fields, values, wrote)
	case kindFlagBit:
		return p.refuseUnwrittenCount(f.field, values, wrote)
	}
	return nil
}

func (p *packer) refuseUnwrittenIn(fields []*node, values, wrote map[string]any) error {
	for _, child := range fields {
		if err := p.refuseUnwrittenCount(child, values, wrote); err != nil {
			return err
		}
	}
	return nil
}
