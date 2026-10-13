package packbin

import "reflect"

// Scheme is a built field list with its type number. It is immutable, so one Scheme can pack and
// unpack from any number of goroutines at once.
type Scheme struct {
	typeNumber int
	fields     []*node
	// values are the value fields in scheme order, at any depth.
	values []*node
	// row is the accessor of the first bound field; nil for a scheme that only packs maps.
	row *accessor
}

// NewScheme builds a scheme from its type number (0..255) and its fields, numbered by order from 0.
// Every check runs here; a scheme that is refused returns an *Error of kind InvalidScheme naming the
// field id, never a panic.
func NewScheme(typeNumber int, fields ...Field) (*Scheme, error) {
	if typeNumber < 0 || typeNumber > 255 {
		return nil, schemeErr(NoField, "", "type number %d: expected 0..255", typeNumber)
	}
	nodes := nodesOf(fields)
	if err := checkNodes(nodes); err != nil {
		return nil, err
	}
	if _, err := validateFieldIDs(nodes, 0); err != nil {
		return nil, err
	}
	flat, err := bindFlagBits(flatten(nodes))
	if err != nil {
		return nil, err
	}
	bound, err := bindReferences(flat, map[int]string{})
	if err != nil {
		return nil, err
	}
	values := valueNodes(bound, nil)
	row, err := checkBinding(values)
	if err != nil {
		return nil, err
	}
	return &Scheme{typeNumber: typeNumber, fields: bound, values: values, row: row}, nil
}

// TypeNumber is the first byte of every packet of this scheme.
func (s *Scheme) TypeNumber() int { return s.typeNumber }

// checkNodes refuses a nil field and reports a constructor's refusal, at any depth.
func checkNodes(nodes []*node) error {
	for _, n := range nodes {
		if n == nil {
			return schemeErr(NoField, "", "a field is nil")
		}
		if n.err != "" {
			at := n
			if n.kind == kindFlags && len(n.fields) > FlagBits && n.fields[FlagBits] != nil {
				at = n.fields[FlagBits] // the ninth member
			}
			return schemeErr(fieldID(at), fieldName(at), "%s", n.err)
		}
		if n.kind == kindFlagBit {
			if err := checkNodes([]*node{n.field}); err != nil {
				return err
			}
		}
		if err := checkNodes(n.fields); err != nil {
			return err
		}
	}
	return nil
}

// validateFieldIDs checks that every value id and anchor is the next id, from next on.
func validateFieldIDs(nodes []*node, next int) (int, error) {
	for _, n := range nodes {
		switch n.kind {
		case kindInt, kindFloat, kindBytes, kindBool:
			if n.id != next {
				return 0, schemeErr(n.id, n.name, "field id: expected %d, got %d", next, n.id)
			}
			next++
		case kindFlagBit:
			var err error
			if next, err = validateFieldIDs([]*node{n.field}, next); err != nil {
				return 0, err
			}
		case kindWhen, kindFlags:
			if n.id != next {
				return 0, schemeErr(n.id, "", "%s anchor: expected %d, got %d", kindLabel(n), next, n.id)
			}
			var err error
			if next, err = validateFieldIDs(n.fields, next); err != nil {
				return 0, err
			}
		}
	}
	return next, nil
}

// flatten turns each flags into its flag byte and one flag bit per member. A member that is a flags
// of its own stays one, so its bits keep their own byte.
func flatten(nodes []*node) []*node {
	out := make([]*node, 0, len(nodes))
	for _, n := range nodes {
		switch n.kind {
		case kindFlags:
			out = append(out, flagsFlat(n)...)
		case kindWhen:
			c := *n
			c.fields = flatten(n.fields)
			out = append(out, &c)
		default:
			out = append(out, n)
		}
	}
	return out
}

func flagsFlat(n *node) []*node {
	fb := &node{kind: kindFlagByte, id: n.id, tag: &flagTag{}, inOrder: true}
	out := []*node{fb}
	for bit, child := range n.fields {
		field := child
		if child.kind != kindFlags {
			field = flatten([]*node{child})[0]
		}
		out = append(out, &node{kind: kindFlagBit, id: NoField, tag: fb.tag, bit: bit, field: field})
	}
	return out
}

// flagRead is one read of a flag byte while a scheme is built: its own tag, and the bits taken so far.
type flagRead struct {
	tag   *flagTag
	name  string
	taken int
}

// bindFlagBits gives each read of a flag byte an identity of its own and numbers its bits by their
// place after it. A bit reads the flag byte of its own scope, read before it: the top level or a
// when body (which also sees the bytes read before it around it); flags members see the scope too.
func bindFlagBits(nodes []*node) ([]*node, error) {
	met := map[*flagTag]int{}
	return bindBitsAll(nodes, map[*flagTag]*flagRead{}, met)
}

func bindBitsAll(nodes []*node, seen map[*flagTag]*flagRead, met map[*flagTag]int) ([]*node, error) {
	out := make([]*node, len(nodes))
	for i, n := range nodes {
		b, err := bindBitsOne(n, seen, met)
		if err != nil {
			return nil, err
		}
		out[i] = b
	}
	return out, nil
}

func copySeen(seen map[*flagTag]*flagRead) map[*flagTag]*flagRead {
	c := make(map[*flagTag]*flagRead, len(seen))
	for k, v := range seen {
		c[k] = v
	}
	return c
}

func bindBitsOne(n *node, seen map[*flagTag]*flagRead, met map[*flagTag]int) (*node, error) {
	switch n.kind {
	case kindFlagByte:
		read := &flagRead{tag: &flagTag{name: n.name}, name: n.name}
		seen[n.tag] = read
		c := *n
		c.tag = read.tag
		return &c, nil
	case kindFlagBit:
		read := seen[n.tag]
		before := met[n.tag]
		met[n.tag] = before + 1
		if read == nil {
			return nil, schemeErr(fieldID(n), fieldName(n),
				"flag bit %d (%s): its flag byte is not read earlier in the same scope", before, fieldName(n))
		}
		if read.taken == FlagBits {
			return nil, schemeErr(fieldID(n), fieldName(n),
				"flag byte %q: ninth bit (%s); a flag byte holds %d bits", read.name, fieldName(n), FlagBits)
		}
		c := *n
		c.tag = read.tag
		c.bit = read.taken
		read.taken++
		field, err := bindBitsOne(n.field, copySeen(seen), met)
		if err != nil {
			return nil, err
		}
		c.field = field
		return &c, nil
	case kindFlags:
		c := *n
		c.fields = make([]*node, len(n.fields))
		for i, member := range n.fields {
			b, err := bindBitsOne(member, copySeen(seen), met)
			if err != nil {
				return nil, err
			}
			c.fields[i] = b
		}
		return &c, nil
	case kindWhen:
		c := *n
		fields, err := bindBitsAll(n.fields, copySeen(seen), met)
		if err != nil {
			return nil, err
		}
		c.fields = fields
		return &c, nil
	}
	return n, nil
}

// bindReferences resolves the id each eq names to the name of a field declared earlier in the same
// scope, so pack and unpack never look an id up. flags, flag bits and when share the scope around
// them. A flags gets its flag byte and bits here, made from its bound members.
func bindReferences(nodes []*node, scope map[int]string) ([]*node, error) {
	out := make([]*node, len(nodes))
	for i, n := range nodes {
		b, err := bindRef(n, scope)
		if err != nil {
			return nil, err
		}
		out[i] = b
	}
	return out, nil
}

func bindRef(n *node, scope map[int]string) (*node, error) {
	switch n.kind {
	case kindInt, kindFloat, kindBytes, kindBool:
		scope[n.id] = n.name
		return n, nil
	case kindWhen:
		ref, ok := scope[n.eqID]
		if !ok {
			return nil, schemeErr(n.id, "",
				"when %d: eq names field id %d, which is not declared earlier in the same scope", n.id, n.eqID)
		}
		c := *n
		c.ref = ref
		fields, err := bindReferences(n.fields, scope)
		if err != nil {
			return nil, err
		}
		c.fields = fields
		return &c, nil
	case kindFlags:
		c := *n
		fields, err := bindReferences(n.fields, scope)
		if err != nil {
			return nil, err
		}
		c.fields = fields
		c.flat = flagsFlat(&c)
		return &c, nil
	case kindFlagBit:
		c := *n
		field, err := bindRef(n.field, scope)
		if err != nil {
			return nil, err
		}
		c.field = field
		return &c, nil
	}
	return n, nil
}

// valueNodes collects the value fields at any depth, in scheme order.
func valueNodes(nodes []*node, out []*node) []*node {
	for _, n := range nodes {
		switch n.kind {
		case kindInt, kindFloat, kindBytes, kindBool:
			out = append(out, n)
		case kindFlagBit:
			out = valueNodes([]*node{n.field}, out)
		case kindWhen, kindFlags:
			out = valueNodes(n.fields, out)
		}
	}
	return out
}

// checkBinding returns the accessor of a typed scheme (every value field bound to one row type), nil
// for a map scheme (none bound), and refuses a mix.
func checkBinding(values []*node) (*accessor, error) {
	var first *accessor
	var unbound *node
	for _, n := range values {
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

// typeName names a Go value's type in a message without calling its methods.
func typeName(v any) string {
	if v == nil {
		return "nil"
	}
	return reflect.TypeOf(v).String()
}
