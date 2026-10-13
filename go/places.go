package packbin

// place is one row of a scheme: the top level, or a group. Its members are the value fields and the
// groups at any depth in it (under flags, flag bits and when) outside a group of its own, in scheme
// order. A group's own members are its inner place.
type place struct {
	members []*node
	// marks are the bools and empty groups whose name no other kind of field of the place declares:
	// a map row gives each of them a bool.
	marks []*node
	// rows are the groups with members whose name no other kind of field of the place declares: a
	// map row gives each of them a map[string]any.
	rows []*node
	// nested: a group with members stands in this place.
	nested bool
}

// buildPlace collects the place of nodes, as pack and unpack walk them (a flags by its flag bits).
// It sets the inner place of each group; the groups are this scheme's own copies.
func buildPlace(nodes []*node) *place {
	pl := &place{}
	pl.collect(nodes)
	classes := map[string]int{}
	for _, n := range pl.members {
		classes[n.name] |= memberClass(n)
	}
	for _, n := range pl.members {
		if classes[n.name] != memberClass(n) {
			continue // a name a when branch declares as another kind: its value is checked where it is written
		}
		switch {
		case isMark(n):
			pl.marks = append(pl.marks, n)
		case n.kind == kindGroup:
			pl.rows = append(pl.rows, n)
		}
	}
	return pl
}

func (pl *place) collect(nodes []*node) {
	for _, n := range nodes {
		switch n.kind {
		case kindInt, kindFloat, kindBytes, kindBool:
			pl.members = append(pl.members, n)
		case kindGroup:
			if len(n.fields) > 0 {
				n.inner = buildPlace(n.fields)
				pl.nested = true
			}
			pl.members = append(pl.members, n)
		case kindFlagBit:
			pl.collect([]*node{n.field})
		case kindWhen:
			pl.collect(n.fields)
		case kindFlags:
			pl.collect(n.flat)
		}
	}
}

const (
	classValue = 1 << iota
	classMark
	classRow
)

func memberClass(n *node) int {
	switch {
	case isMark(n):
		return classMark
	case n.kind == kindGroup:
		return classRow
	}
	return classValue
}

// checkBinding returns the accessor of a typed scheme (every member of the top level bound to one row
// type, and every member of a bound group to the type of that group), nil for a map scheme (none
// bound), and refuses a mix.
func checkBinding(top *place) (*accessor, error) {
	first, err := placeBinding(top)
	if err != nil {
		return nil, err
	}
	return first, checkGroupBindings(top)
}

// placeBinding: the members of one place are bound to one row type, or none is.
func placeBinding(pl *place) (*accessor, error) {
	var first *accessor
	var unbound *node
	for _, n := range pl.members {
		if n.acc == nil {
			if unbound == nil {
				unbound = n
			}
			continue
		}
		if first == nil {
			first = n.acc
			continue
		}
		if n.acc.rowType != first.rowType {
			return nil, schemeErr(n.id, n.name, "bound to row type %v, but an earlier field is bound to %v",
				n.acc.rowType, first.rowType)
		}
	}
	if first != nil && unbound != nil {
		return nil, schemeErr(unbound.id, unbound.name,
			"not bound to row type %v; bind every value field of a scheme, or none", first.rowType)
	}
	return first, nil
}

// checkGroupBindings: a bound group's members are bound to the group's row type; an unbound group's
// members are not bound.
func checkGroupBindings(pl *place) error {
	for _, g := range pl.members {
		if g.inner == nil {
			continue
		}
		inner, err := placeBinding(g.inner)
		if err != nil {
			return err
		}
		switch {
		case g.acc == nil && inner != nil:
			at := firstBound(g.inner)
			return schemeErr(at.id, at.name, "bound to row type %v, but its group %s is not bound", inner.rowType, g.name)
		case g.acc != nil && inner == nil && len(g.inner.members) > 0:
			at := g.inner.members[0]
			return schemeErr(at.id, at.name, "not bound to row type %v (the row of group %s); bind every value field "+
				"of a scheme, or none", g.acc.childType, g.name)
		case g.acc != nil && inner != nil && inner.rowType != g.acc.childType:
			at := firstBound(g.inner)
			return schemeErr(at.id, at.name, "bound to row type %v, but its group %s is bound to %v",
				inner.rowType, g.name, g.acc.childType)
		}
		if err := checkGroupBindings(g.inner); err != nil {
			return err
		}
	}
	return nil
}

func firstBound(pl *place) *node {
	for _, n := range pl.members {
		if n.acc != nil {
			return n
		}
	}
	return pl.members[0]
}

// typedValues is a typed row (a *T of the place's row type) as the walker reads it: each present
// value by field name, normalized; a group's values as a map of its own.
func typedValues(pl *place, row any) map[string]any {
	values := make(map[string]any, len(pl.members))
	for _, n := range pl.members {
		v, present := n.acc.get(row)
		if !present {
			continue
		}
		if n.inner != nil {
			v = typedValues(n.inner, v)
		}
		values[n.name] = v
	}
	return values
}

// mapValues is a map row as the walker reads it: each present value normalized, a group's value a
// map of its own read the same way. A value of a group's member is read from the group's map only,
// never from the row around it. A bool or empty group given anything but a bool is refused (owner
// decision Go-1: TypeScript leaves the bit clear), and so is a group given anything but a map.
func mapValues(pl *place, m map[string]any) (map[string]any, error) {
	values := make(map[string]any, len(m))
	for k, v := range m {
		if nv, present := normalize(v); present {
			values[k] = nv
		}
	}
	for _, n := range pl.marks {
		if v, ok := values[n.name]; ok {
			if _, isBool := v.(bool); !isBool {
				return nil, packErr(n.id, n.name, "expected a bool for %s %s, got %s", kindLabel(n), n.name, typeName(v))
			}
		}
	}
	for _, g := range pl.rows {
		v, ok := values[g.name]
		if !ok {
			continue
		}
		sub, isMap := v.(map[string]any)
		if !isMap {
			return nil, packErr(g.id, g.name, "expected a map[string]any for group %s, got %s", g.name, typeName(v))
		}
		nested, err := mapValues(g.inner, sub)
		if err != nil {
			return nil, err
		}
		values[g.name] = nested
	}
	return values, nil
}

// fillRow stores unpacked values into a typed row of the place. A value is stored only into a member
// of the Go type unpack gives that field, so a name two when branches declare with different kinds
// fills only the member of the branch that was read.
func fillRow(pl *place, row any, values map[string]any) {
	for _, n := range pl.members {
		v, ok := values[n.name]
		if !ok || !unpackedAs(n, v) {
			continue
		}
		if n.inner != nil {
			child := n.acc.newChild()
			fillRow(n.inner, child, v.(map[string]any))
			v = child
		}
		n.acc.set(row, v)
	}
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
	case kindBytes:
		_, ok := v.([]byte)
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
