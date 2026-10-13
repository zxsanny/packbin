package packbin

import (
	"math"
	"strconv"
)

// checkPresenceMarks refuses a bool or an empty group anywhere but directly under flags or as the
// field of a flag bit: it has no bytes, only a bit, so anywhere else it would always read as true.
func checkPresenceMarks(nodes []*node, onBit bool) error {
	for _, n := range nodes {
		if isMark(n) && !onBit {
			return schemeErr(n.id, n.name, "%s %s: allowed only directly inside flags or a flag bit; move it into flags",
				kindLabel(n), n.name)
		}
		var err error
		switch n.kind {
		case kindFlagBit:
			err = checkPresenceMarks([]*node{n.field}, true)
		case kindFlags:
			err = checkPresenceMarks(n.fields, true)
		case kindWhen, kindGroup, kindRepeat, kindTimes:
			err = checkPresenceMarks(n.fields, false)
		}
		if err != nil {
			return err
		}
	}
	return nil
}

// checkMemberNames refuses a name declared twice in one scope: a row holds one value per name. A
// group's own name belongs to the scope around it, and its members share that scope (as flags,
// flag bits and when do), so a member may not reuse a name of the row around the group either. A
// name under a when may be declared again (the branches of a chain may share a member), but only
// once outside every when.
func checkMemberNames(nodes []*node) error {
	always := map[string]bool{}
	var walk func(nodes []*node, conditional bool) error
	declare := func(n *node, conditional bool) error {
		first, seen := always[n.name]
		switch {
		case !seen:
			always[n.name] = !conditional
		case !conditional && first:
			return schemeErr(n.id, n.name,
				"member %s: declared twice in one scope; a row holds one value per name, so one would be lost", n.name)
		case !conditional:
			always[n.name] = true
		}
		return nil
	}
	walk = func(nodes []*node, conditional bool) error {
		for _, n := range nodes {
			var err error
			switch n.kind {
			case kindInt, kindFloat, kindBytes, kindBool, kindSized, kindBits, kindPacked, kindSlot:
				err = declare(n, conditional)
			case kindGroup:
				if err = declare(n, conditional); err == nil {
					err = walk(n.fields, conditional)
				}
			case kindWhen:
				err = walk(n.fields, true)
			case kindFlags, kindU2, kindRepeat, kindTimes:
				err = walk(n.fields, conditional)
			case kindFlagBit:
				err = walk([]*node{n.field}, conditional)
			}
			if err != nil {
				return err
			}
		}
		return nil
	}
	return walk(nodes, false)
}

// checkEq refuses a when whose eq names a field that is not an integer or a bool, a bool compared
// with anything but true (a clear bit is absent, so false never matches), and a value an integer
// field can never hold (a whole float such as 5.0 is the integer 5).
func checkEq(w, src *node) error {
	switch src.kind {
	case kindInt, kindSlot:
		if !eqInRange(w.eqValue, src) {
			lo, hi := intBounds(src)
			return schemeErr(w.id, "", "when %d tests %s field %d ('%s') against %s; the value must be a whole number from %s to %s",
				w.id, kindLabel(src), src.id, src.name, describe(w.eqValue), lo, hi)
		}
	case kindBool:
		if on, _ := w.eqValue.(bool); !on {
			return schemeErr(w.id, "", "when %d: eq names bool field id %d (%s) and accepts only true, not %s",
				w.id, src.id, src.name, describe(w.eqValue))
		}
	default:
		return schemeErr(w.id, "", "when %d: eq names field id %d (%s), which is not an integer or a bool",
			w.id, src.id, src.name)
	}
	return nil
}

func eqInRange(v any, src *node) bool {
	if src.kind == kindSlot {
		x, ok := asNumber(v)
		_, isInt := asInt(v)
		return ok && (isInt || x == math.Trunc(x)) && x >= 0 && x <= 3
	}
	if n, ok := asInt(v); ok {
		return n.fits(src.size, src.signed)
	}
	var x float64
	switch f := v.(type) {
	case float32:
		x = float64(f)
	case float64:
		x = f
	default:
		return false
	}
	if math.IsNaN(x) || math.IsInf(x, 0) || x != math.Trunc(x) {
		return false
	}
	bits := src.size * 8
	if src.signed {
		limit := math.Ldexp(1, bits-1)
		return x >= -limit && x < limit
	}
	return x >= 0 && x < math.Ldexp(1, bits)
}

func intBounds(n *node) (string, string) {
	if n.kind == kindSlot {
		return "0", "3"
	}
	bits := uint(n.size * 8)
	if n.signed {
		return strconv.FormatInt(-1<<(bits-1), 10), strconv.FormatInt(1<<(bits-1)-1, 10)
	}
	return "0", strconv.FormatUint(math.MaxUint64>>(64-bits), 10)
}

// describe shows a value in a message without calling its methods.
func describe(v any) string {
	switch x := v.(type) {
	case nil:
		return "nil"
	case string:
		return strconv.Quote(x)
	case bool:
		return strconv.FormatBool(x)
	case float32:
		return strconv.FormatFloat(float64(x), 'g', -1, 32)
	case float64:
		return strconv.FormatFloat(x, 'g', -1, 64)
	}
	if n, ok := asInt(v); ok {
		return n.String()
	}
	return "a value of type " + typeName(v)
}
