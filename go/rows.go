package packbin

import "reflect"

// mapValues is a map row as the walker reads it: each present value normalized, a group's value a
// map of its own read the same way, and a round's list of each name a []any of normalized entries
// (nil where absent; a group's entries are maps). A value of a group's member is read from the
// group's map only: one given in the row around an absent group is refused (owner decision Go-4:
// TypeScript packs it from the flat key). A bool or empty group given anything but a bool is refused
// (owner decision Go-1: TypeScript leaves the bit clear), and so is a group given anything but a map.
func mapValues(pl *place, m map[string]any) (map[string]any, error) {
	values := make(map[string]any, len(m))
	for k, v := range m {
		if nv, present := normalize(v); present {
			values[k] = nv
		}
	}
	for _, n := range pl.marks {
		if v, ok := values[n.name]; ok {
			if err := checkMark(n, v); err != nil {
				return nil, err
			}
		}
	}
	for _, g := range pl.rows {
		if v, ok := values[g.name]; ok {
			nested, err := nestRow(g, v)
			if err != nil {
				return nil, err
			}
			values[g.name] = nested
		}
	}
	for _, r := range pl.rounds {
		if err := roundValues(r, values); err != nil {
			return nil, err
		}
	}
	if err := refuseFlatMembers(pl, values); err != nil {
		return nil, err
	}
	return values, nil
}

func checkMark(n *node, v any) error {
	if _, isBool := v.(bool); !isBool {
		return packErr(n.id, n.name, "expected a bool for %s %s, got %s", kindLabel(n), n.name, typeName(v))
	}
	return nil
}

func nestRow(g *node, v any) (map[string]any, error) {
	sub, isMap := v.(map[string]any)
	if !isMap {
		return nil, packErr(g.id, g.name, "expected a map[string]any for group %s, got %s", g.name, typeName(v))
	}
	return mapValues(g.inner, sub)
}

// roundValues turns the value of each name of round r into a list of normalized entries, and checks
// the entries (or the one value that goes to every round) of its bools and groups.
func roundValues(r *node, values map[string]any) error {
	for _, n := range r.shape.names {
		if v, ok := values[n.name]; ok {
			if list, isL := roundList(v); isL {
				values[n.name] = list
			}
		}
	}
	for _, n := range r.inner.marks {
		err := eachEntry(values, n.name, func(v any) (any, error) { return v, checkMark(n, v) })
		if err != nil {
			return err
		}
	}
	for _, g := range r.inner.rows {
		err := eachEntry(values, g.name, func(v any) (any, error) { return nestRow(g, v) })
		if err != nil {
			return err
		}
	}
	return nil
}

// eachEntry applies check to every present entry of the list under name, or to its one value.
func eachEntry(values map[string]any, name string, check func(any) (any, error)) error {
	v, ok := values[name]
	if !ok {
		return nil
	}
	list, isL := isList(v)
	if !isL {
		nv, err := check(v)
		values[name] = nv
		return err
	}
	for i, e := range list {
		if e == nil {
			continue
		}
		ne, err := check(e)
		if err != nil {
			return err
		}
		list[i] = ne
	}
	return nil
}

// refuseFlatMembers refuses a name declared only inside a group of pl, given in pl's row while a
// group on its path is not given (owner decision Go-4).
func refuseFlatMembers(pl *place, values map[string]any) error {
	for _, f := range pl.foreign {
		if _, given := values[f.member.name]; !given {
			continue
		}
		if g := absentGroup(values, f.path); g != nil {
			return packErr(f.member.id, f.member.name, "%s is a member of group %s, which is not given; give the value "+
				"in the group's map[string]any, not in the row around it", f.member.name, g.name)
		}
	}
	return nil
}

// absentGroup is the first group on path whose value the row does not give, or nil. A group given as
// something other than a map (a round's list) ends the walk.
func absentGroup(values map[string]any, path []*node) *node {
	m := values
	for _, g := range path {
		v, ok := m[g.name]
		if !ok {
			return g
		}
		sub, isMap := v.(map[string]any)
		if !isMap {
			return nil
		}
		m = sub
	}
	return nil
}

// typedValues is a typed row (a *T of the place's row type) as the walker reads it: each present
// value by field name, normalized; a group's values as a map of its own; each name of a round as a
// typedRounds list with one entry for each element of the bound slice.
func typedValues(pl *place, row any) map[string]any {
	values := make(map[string]any, len(pl.members))
	for _, n := range pl.members {
		v, present := n.acc.get(row)
		if isRound(n) {
			typedRoundValues(n, v, present, values)
			continue
		}
		if !present {
			continue
		}
		if n.inner != nil {
			v = typedValues(n.inner, v)
		} else if n.kind == kindList || n.kind == kindDict {
			v = toWalk(n, reflect.ValueOf(v))
		}
		values[n.name] = v
	}
	return values
}

// typedRoundValues: a nil slice is no value and an empty one 0 rounds; both give every name an empty
// list, so pack writes no round and a times can check its count against the rounds the row holds.
func typedRoundValues(r *node, v any, present bool, values map[string]any) {
	var rows []any
	if present {
		rows = r.acc.roundRows(v)
	}
	per := make([]map[string]any, len(rows))
	for i, rp := range rows {
		if rp != nil {
			per[i] = typedValues(r.inner, rp)
		}
	}
	for _, n := range r.shape.names {
		list := make(typedRounds, len(rows))
		for i := range per {
			if per[i] != nil {
				list[i] = per[i][n.name]
			}
		}
		values[n.name] = list
	}
}

// fillRow stores unpacked values into a typed row of the place. A value is stored only into a member
// of the Go type unpack gives that field, so a name two when branches declare with different kinds
// fills only the member of the branch that was read. reached are the rounds unpack read, so a round
// read with 0 rounds gives an empty slice and one not read (a clear bit, a false when) a nil slice.
func fillRow(pl *place, row any, values map[string]any, reached map[reachKey]bool) {
	for _, n := range pl.members {
		if isRound(n) {
			fillRounds(n, row, values, reached)
			continue
		}
		v, ok := values[n.name]
		if !ok || !unpackedAs(n, v) {
			continue
		}
		if n.inner != nil {
			child := n.acc.newChild()
			fillRow(n.inner, child, v.(map[string]any), reached)
			v = child
		} else if n.kind == kindList || n.kind == kindDict {
			v = fromWalk(n, v, n.acc.valueType, reached).Interface()
		}
		n.acc.set(row, v)
	}
}

// fillRounds stores one element of the round's slice for each round unpack read.
func fillRounds(r *node, row any, values map[string]any, reached map[reachKey]bool) {
	count := 0
	for _, n := range r.shape.names {
		if list, ok := values[n.name].([]any); ok {
			count = max(count, len(list))
		}
	}
	if count == 0 && !reached[reachOf(values, r)] {
		return
	}
	rows := make([]any, count)
	for i := range rows {
		elem := make(map[string]any, len(r.shape.names))
		for _, n := range r.shape.names {
			if list, ok := values[n.name].([]any); ok && i < len(list) && list[i] != nil {
				elem[n.name] = list[i]
			}
		}
		child := r.acc.newChild()
		fillRow(r.inner, child, elem, reached)
		rows[i] = child
	}
	r.acc.setRounds(row, rows)
}

// unpackedAs reports whether v has the Go type unpack gives the field n.
func unpackedAs(n *node, v any) bool {
	switch n.kind {
	case kindInt:
		size, signed, ok := intTypeOf(v)
		return ok && size == n.size && signed == n.signed
	case kindFloat:
		if n.size == 4 {
			_, ok := v.(float32)
			return ok
		}
		_, ok := v.(float64)
		return ok
	case kindBytes, kindSized, kindBits, kindPacked:
		_, ok := v.([]byte)
		return ok
	case kindUtf8:
		_, ok := v.(string)
		return ok
	case kindList:
		_, ok := v.([]any)
		return ok
	case kindDict:
		_, ok := v.(map[string]any)
		return ok
	case kindSlot:
		_, ok := v.(uint8)
		return ok
	case kindBool:
		_, ok := v.(bool)
		return ok
	case kindGroup:
		if n.inner == nil {
			_, ok := v.(bool)
			return ok
		}
		_, ok := v.(map[string]any)
		return ok
	}
	return false
}

// intTypeOf is the size and signedness of a fixed-size Go integer.
func intTypeOf(v any) (int, bool, bool) {
	switch v.(type) {
	case uint8:
		return 1, false, true
	case uint16:
		return 2, false, true
	case uint32:
		return 4, false, true
	case uint64:
		return 8, false, true
	case int8:
		return 1, true, true
	case int16:
		return 2, true, true
	case int32:
		return 4, true, true
	case int64:
		return 8, true, true
	}
	return 0, false, false
}
