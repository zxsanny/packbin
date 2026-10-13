package packbin

import "slices"

// declared is a value field of a scope and the groups from the scope's row to it.
type declared struct {
	n    *node
	path []string
}

// refScope maps an id to the value field that declared it in one scope.
type refScope map[int]declared

// bindReferences resolves the id each eq or count names to the name of a field declared earlier in
// the same scope, so pack and unpack never look an id up, and checks the field. The top level and
// each repeat or times body are scopes; flags, flag bits, when, u2 and group share the scope around
// them. A flags gets its flag byte and bits here, made from its bound members. path is the groups
// from the scope's row to nodes.
func bindReferences(nodes []*node, scope refScope, path []string) ([]*node, error) {
	out := make([]*node, len(nodes))
	for i, n := range nodes {
		b, err := bindRef(n, scope, path)
		if err != nil {
			return nil, err
		}
		out[i] = b
	}
	return out, nil
}

func bindRef(n *node, scope refScope, path []string) (*node, error) {
	switch n.kind {
	case kindInt, kindFloat, kindBytes, kindBool, kindSlot:
		scope[n.id] = declared{n, path}
		return n, nil
	case kindSized, kindBits, kindPacked:
		c := *n
		if err := bindCount(&c, scope); err != nil {
			return nil, err
		}
		scope[n.id] = declared{&c, path}
		return &c, nil
	case kindTimes, kindRepeat:
		c := *n
		if n.kind == kindTimes {
			if err := bindCount(&c, scope); err != nil {
				return nil, err
			}
		}
		fields, err := bindReferences(n.fields, refScope{}, nil)
		if err != nil {
			return nil, err
		}
		c.fields = fields
		// Made here, so every copy a flags makes of the round shares its row and shape.
		c.inner = buildPlace(c.fields)
		c.shape = makeRoundShape(&c)
		return &c, nil
	case kindWhen:
		src, ok := scope[n.eqID]
		if !ok {
			return nil, schemeErr(n.id, "",
				"when %d: eq names field id %d, which is not declared earlier in the same scope", n.id, n.eqID)
		}
		if err := checkEq(n, src.n); err != nil {
			return nil, err
		}
		c := *n
		c.ref = src.n.name
		fields, err := bindReferences(n.fields, scope, path)
		if err != nil {
			return nil, err
		}
		c.fields = fields
		return &c, nil
	case kindFlags, kindGroup, kindU2:
		c := *n
		inner := path
		if n.kind == kindGroup {
			inner = append(slices.Clip(path), n.name)
		}
		fields, err := bindReferences(n.fields, scope, inner)
		if err != nil {
			return nil, err
		}
		c.fields = fields
		if n.kind == kindFlags {
			c.flat = flagsFlat(&c)
		}
		return &c, nil
	case kindFlagBit:
		c := *n
		field, err := bindRef(n.field, scope, path)
		if err != nil {
			return nil, err
		}
		c.field = field
		return &c, nil
	}
	return n, nil
}

// bindCount resolves the count of a sized, bits, packed or times: an integer field or a u2 slot
// declared earlier in the same scope.
func bindCount(c *node, scope refScope) error {
	src, ok := scope[c.countID]
	if !ok {
		return schemeErr(c.id, c.name, "%s %d: count names field id %d, which is not declared earlier in the same scope",
			kindLabel(c), c.id, c.countID)
	}
	if src.n.kind != kindInt && src.n.kind != kindSlot {
		return schemeErr(c.id, c.name, "%s %d: count names field id %d (%s), which is not an integer",
			kindLabel(c), c.id, c.countID, src.n.name)
	}
	c.ref = src.n.name
	c.refPath = src.path
	return nil
}
