package packbin

import "reflect"

// A repeat or times round is addressed by index. In a map row each name a round holds takes a list,
// entry i for round i; pack reads each list at the round's index, and a value that is not a list goes
// to every round. Unpack gives every name a round can hold one entry a round, nil where the round
// skipped it, so a repack gives the same bytes. A group in a round takes one map a round (Go-4).

// roundShape is what a repeat or times asks of its values, worked out once when the scheme is built.
type roundShape struct {
	// names are the members of the round's row, one per name, in scheme order: the keys a round
	// holds in the map form.
	names []*node
	// optional are the names a flag bit can leave absent in a round: under flags or a flag bit (also
	// through a when below them), and a group that holds such a name.
	optional []*node
	// buffers are the names whose value is itself a byte run or a list (bytes, sized, bits, packed),
	// and groups are the groups, which can hold one: a lone one would reach every round.
	buffers []*node
	groups  []*node
	// dicts are the dict names: a lone dictionary would reach every round as well.
	dicts []*node
	// width is the slots a round charges against MaxSlots: the distinct names unpack gives an entry a
	// round (see roundWidth).
	width int
}

func makeRoundShape(r *node) *roundShape {
	sh := &roundShape{}
	seen := map[string]bool{}
	for _, m := range r.inner.members {
		if seen[m.name] {
			continue
		}
		seen[m.name] = true
		sh.names = append(sh.names, m)
		switch {
		case m.kind == kindBytes || m.kind == kindSized || m.kind == kindBits || m.kind == kindPacked:
			sh.buffers = append(sh.buffers, m)
		case m.kind == kindDict:
			sh.dicts = append(sh.dicts, m)
		case m.kind == kindGroup && m.inner != nil:
			sh.groups = append(sh.groups, m)
		}
	}
	sh.optional = optionalNames(r.fields, false, map[string]bool{}, nil)
	sh.width = roundWidth(r.fields)
	return sh
}

// roundWidth is the slots one round of fields charges: the distinct names it can hold, as every
// package counts them. One slot each for a value field, a sized, bits or packed name, a list or dict
// name (however many items), each name of a u2 and an empty group's own name; and one for each name
// inside a when (whether its condition holds or not), flags, flag bit or group, at any depth. A
// non-empty group's own name, a flags and its flag byte, a split flag byte and the anchors of when,
// repeat and times are no slot, and a name declared twice is one slot. A Nested row is a scope of its
// own, so it charges the width of its own members, apart from the names around it.
func roundWidth(fields []*node) int {
	names := map[string]bool{}
	return nameSlots(fields, names) + len(names)
}

// nameSlots collects the names of fields into names and returns the slots of the Nested rows in them.
func nameSlots(fields []*node, names map[string]bool) int {
	extra := 0
	for _, f := range fields {
		switch f.kind {
		case kindRepeat, kindTimes, kindFlagByte:
		case kindWhen, kindFlags, kindU2:
			extra += nameSlots(f.fields, names)
		case kindFlagBit:
			extra += nameSlots([]*node{f.field}, names)
		case kindGroup:
			switch {
			case len(f.fields) == 0:
				names[f.name] = true
			case f.nested:
				extra += roundWidth(f.fields)
			default:
				extra += nameSlots(f.fields, names)
			}
		default:
			names[f.name] = true
		}
	}
	return extra
}

// optionalNames collects the members a flag bit can leave absent: those reached through flags or a
// flag bit. A group is one name of the round; it is optional under a flag bit, or when it holds an
// optional name itself.
func optionalNames(fields []*node, underFlag bool, seen map[string]bool, out []*node) []*node {
	add := func(n *node) {
		if !seen[n.name] {
			seen[n.name] = true
			out = append(out, n)
		}
	}
	for _, f := range fields {
		switch f.kind {
		case kindFlagBit:
			out = optionalNames([]*node{f.field}, true, seen, out)
		case kindFlags:
			out = optionalNames(f.fields, true, seen, out)
		case kindWhen, kindU2:
			out = optionalNames(f.fields, underFlag, seen, out)
		case kindGroup:
			if underFlag || len(optionalNames(f.fields, false, map[string]bool{}, nil)) > 0 {
				add(f)
			}
		case kindRepeat, kindTimes, kindFlagByte:
		default:
			if underFlag {
				add(f)
			}
		}
	}
	return out
}

// typedRounds is the list of a round's name made from a typed row: one entry for each element of
// the bound slice, so its length is the rounds the row holds.
type typedRounds []any

// roundList is v as a list of round entries, each normalized (nil where absent), and true; false for
// a value that is not a list. A []byte is a byte run, not a list.
func roundList(v any) ([]any, bool) {
	switch x := v.(type) {
	case typedRounds:
		return x, true
	case []byte:
		return nil, false
	case []any:
		out := make([]any, len(x))
		for i, e := range x {
			out[i], _ = normalize(e)
		}
		return out, true
	}
	rv := reflect.ValueOf(v)
	if rv.Kind() != reflect.Slice {
		return nil, false
	}
	out := make([]any, rv.Len())
	for i := range out {
		out[i], _ = normalize(rv.Index(i).Interface())
	}
	return out, true
}

// isList reports a value normalized by mapValues or typedValues as a round list.
func isList(v any) ([]any, bool) {
	switch x := v.(type) {
	case typedRounds:
		return x, true
	case []any:
		return x, true
	}
	return nil, false
}

// roundCount is the longest list among the round's names; a value that is not a list is one round.
func roundCount(sh *roundShape, values map[string]any) int {
	count := 0
	for _, n := range sh.names {
		v, ok := values[n.name]
		if !ok {
			continue
		}
		if list, isL := isList(v); isL {
			count = max(count, len(list))
		} else {
			count = max(count, 1)
		}
	}
	return count
}

// sliceRound is the row of round i: each list read at i (an absent entry leaves the name out), a
// value that is not a list as it is.
func sliceRound(sh *roundShape, values map[string]any, i int) map[string]any {
	view := make(map[string]any, len(sh.names))
	for _, n := range sh.names {
		v, ok := values[n.name]
		if !ok {
			continue
		}
		if list, isL := isList(v); isL {
			if i < len(list) && list[i] != nil {
				view[n.name] = list[i]
			}
			continue
		}
		view[n.name] = v
	}
	return view
}

// refuseShortOptional: a repeat writes a round per entry of its longest list, and a flag bit leaves a
// member absent in a round only by a nil entry, so a non-empty list shorter than the rounds under a
// member a flag bit can leave absent does not say which rounds it belongs to.
func refuseShortOptional(sh *roundShape, values map[string]any, count int) error {
	for _, n := range sh.optional {
		if list, ok := isList(values[n.name]); ok && len(list) > 0 && len(list) < count {
			return packErr(n.id, n.name, "%s: %d items, repeat count %d; give one entry per round, nil where the member is absent",
				n.name, len(list), count)
		}
	}
	return nil
}

// refuseRoundsOverLimit: unpack refuses a round past MaxRounds, so pack refuses a times count past it
// before it writes any round: a lone scalar goes to every round, and a huge count would loop that
// many times.
func refuseRoundsOverLimit(f *node, count, limit int) error {
	if count <= limit {
		return nil
	}
	id, name := roundMember(f)
	return packErr(id, name, "%s: the times count is %d, above the limit of %d rounds", name, count, limit)
}

// refuseRepeatOverLimit: a repeat writes a round per entry of its longest list, so pack refuses, before
// any round, the first list among the round's names with more entries than MaxRounds, named by its own
// member.
func refuseRepeatOverLimit(f *node, values map[string]any, limit int) error {
	for _, n := range f.shape.names {
		if list, ok := isList(values[n.name]); ok && len(list) > limit {
			return packErr(n.id, n.name, "%s: the repeat count is %d, above the limit of %d rounds", n.name, len(list), limit)
		}
	}
	return nil
}

// refuseLongLists: a times writes exactly count rounds, so a list that holds more would lose its tail.
func refuseLongLists(sh *roundShape, values map[string]any, count int) error {
	for _, n := range sh.names {
		if list, ok := isList(values[n.name]); ok && len(list) > count {
			return packErr(n.id, n.name, "%s: %d items, times count %d", n.name, len(list), count)
		}
	}
	return nil
}

// refuseLoneBuffers: one byte run or item list given for a name of a round (also inside a group map
// given once for every round) would reach every round, so it is refused: one per round goes in a list.
func refuseLoneBuffers(sh *roundShape, values map[string]any) error {
	for _, n := range sh.buffers {
		if v, ok := values[n.name]; ok {
			if _, isL := isList(v); !isL {
				return packErr(n.id, n.name, "%s: a byte buffer in a repeat or times round needs a list with one buffer per round", n.name)
			}
		}
	}
	for _, n := range sh.dicts {
		if v, ok := values[n.name]; ok {
			if _, isL := isList(v); !isL {
				return packErr(NoField, n.name, "%s: a dictionary in a repeat or times round needs a list with one dictionary per round", n.name)
			}
		}
	}
	for _, g := range sh.groups {
		if sub, ok := values[g.name].(map[string]any); ok {
			if err := refuseBuffersIn(g.inner, sub); err != nil {
				return err
			}
		}
	}
	return nil
}

func refuseBuffersIn(pl *place, values map[string]any) error {
	for _, n := range pl.members {
		switch {
		case n.kind == kindBytes || n.kind == kindSized || n.kind == kindBits || n.kind == kindPacked:
			if _, ok := values[n.name]; ok {
				return packErr(n.id, n.name, "%s: a byte buffer in a repeat or times round needs a list with one buffer per round", n.name)
			}
		case n.kind == kindList || n.kind == kindDict:
			if _, ok := values[n.name]; ok {
				word := map[kind]string{kindList: "list", kindDict: "dictionary"}[n.kind]
				return packErr(NoField, n.name, "%s: a %s in a repeat or times round needs a list with one %s per round",
					n.name, word, word)
			}
		case n.kind == kindGroup && n.inner != nil:
			if sub, ok := values[n.name].(map[string]any); ok {
				if err := refuseBuffersIn(n.inner, sub); err != nil {
					return err
				}
			}
		}
	}
	return nil
}

// roundMember is the member a refusal about a whole round names: the first name its round holds,
// else the round itself.
func roundMember(r *node) (int, string) {
	if len(r.shape.names) > 0 {
		return r.shape.names[0].id, r.shape.names[0].name
	}
	return r.id, ""
}

// appendList joins the list a repeat built to what the scope already holds under that name.
func appendList(into map[string]any, name string, list []any) {
	switch prev := into[name].(type) {
	case nil:
		into[name] = list
	case []any:
		into[name] = append(prev, list...)
	default:
		into[name] = append([]any{prev}, list...)
	}
}
