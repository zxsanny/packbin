package packbin

import "reflect"

// Scheme is a built field list with its type number. It is immutable, so one Scheme can pack and
// unpack from any number of goroutines at once.
type Scheme struct {
	typeNumber int
	fields     []*node
	// top is the row of the top level: its value fields and groups, outside a group.
	top *place
	// row is the accessor of the first bound field; nil for a scheme that only packs maps.
	row *accessor
	// limits are the round, slot and output limits one Pack or Unpack call keeps.
	limits Limits
	// parity is the count of parity bytes pack appends and unpack checks (ecc.go); 0 is no protection.
	parity int
}

// NewScheme builds a scheme from its type number (0..255) and its fields, numbered by order from 0.
// Every check runs here; a scheme that is refused returns an *Error of kind InvalidScheme naming the
// field id, never a panic.
func NewScheme(typeNumber int, fields ...Field) (*Scheme, error) {
	if typeNumber < 0 || typeNumber > 255 {
		return nil, schemeErr(NoField, "", "type number %d: expected 0..255", typeNumber)
	}
	nodes := nodesOf(fields)
	if err := checkNodes(nodes, false); err != nil {
		return nil, err
	}
	if _, err := validateFieldIDs(nodes, 0); err != nil {
		return nil, err
	}
	flat, err := bindFlagBits(flatten(nodes))
	if err != nil {
		return nil, err
	}
	if err := checkPresenceMarks(flat, false); err != nil {
		return nil, err
	}
	if err := checkMemberNames(flat); err != nil {
		return nil, err
	}
	if err := checkRoundNesting(flat, false); err != nil {
		return nil, err
	}
	if err := checkRoundBodies(flat); err != nil {
		return nil, err
	}
	bound, err := bindReferences(flat, refScope{}, nil)
	if err != nil {
		return nil, err
	}
	if err := checkElements(bound); err != nil {
		return nil, err
	}
	top := buildPlace(bound)
	row, err := checkBinding(top)
	if err != nil {
		return nil, err
	}
	return &Scheme{typeNumber: typeNumber, fields: bound, top: top, row: row, limits: DefaultLimits()}, nil
}

// unusable is true for a nil scheme and for a zero-value Scheme that NewScheme did not make: neither
// has a field list to walk.
func (s *Scheme) unusable() bool {
	return s == nil || s.top == nil
}

// notMade names which of the two unusable schemes it is, for the message of the *Error.
func (s *Scheme) notMade() string {
	if s == nil {
		return "the scheme is nil"
	}
	return "the scheme was not made by NewScheme"
}

// TypeNumber is the first byte of every packet of this scheme.
// A nil scheme (an ignored NewScheme error) has type number 0.
func (s *Scheme) TypeNumber() int {
	if s == nil {
		return 0
	}
	return s.typeNumber
}

// checkNodes refuses a nil field and a Slot outside U2, and reports a constructor's refusal, at any
// depth.
func checkNodes(nodes []*node, inU2 bool) error {
	for _, n := range nodes {
		if n == nil {
			return schemeErr(NoField, "", "a field is nil")
		}
		if n.kind == kindSlot && !inU2 {
			return schemeErr(n.id, n.name, "slot %s: allowed only directly inside U2", n.name)
		}
		if n.err != "" {
			at := n
			if n.kind == kindFlags && len(n.fields) > FlagBits && n.fields[FlagBits] != nil {
				at = n.fields[FlagBits] // the ninth member
			}
			return schemeErr(fieldID(at), fieldName(at), "%s", n.err)
		}
		if n.kind == kindFlagBit {
			if err := checkNodes([]*node{n.field}, false); err != nil {
				return err
			}
		}
		if n.elem != nil {
			if err := checkNodes([]*node{n.elem}, false); err != nil {
				return err
			}
		}
		if err := checkNodes(n.fields, n.kind == kindU2); err != nil {
			return err
		}
	}
	return nil
}

// validateFieldIDs checks that every value id and anchor is the next id, from next on.
func validateFieldIDs(nodes []*node, next int) (int, error) {
	for _, n := range nodes {
		switch n.kind {
		case kindInt, kindFloat, kindBytes, kindBool, kindSized, kindBits, kindPacked, kindSlot, kindUtf8:
			if n.id != next {
				return 0, schemeErr(n.id, n.name, "field id: expected %d, got %d", next, n.id)
			}
			next++
		case kindList, kindDict:
			// An element numbers its fields from 0 in a scope of its own, and the list takes no id.
			if _, err := validateFieldIDs([]*node{n.elem}, 0); err != nil {
				return 0, err
			}
		case kindU2:
			var err error
			if next, err = validateFieldIDs(n.fields, next); err != nil {
				return 0, err
			}
		case kindFlagBit:
			var err error
			if next, err = validateFieldIDs([]*node{n.field}, next); err != nil {
				return 0, err
			}
		case kindGroup:
			if n.nested {
				// A nested row numbers its members from 0 and takes no id of the row around it.
				if _, err := validateFieldIDs(n.fields, 0); err != nil {
					return 0, err
				}
				continue
			}
			if n.id != next {
				return 0, schemeErr(n.id, "", "%s anchor: expected %d, got %d", kindLabel(n), next, n.id)
			}
			var err error
			if next, err = validateFieldIDs(n.fields, next); err != nil {
				return 0, err
			}
		case kindWhen, kindFlags, kindRepeat, kindTimes:
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
		case kindWhen, kindGroup, kindRepeat, kindTimes:
			c := *n
			c.fields = flatten(n.fields)
			out = append(out, &c)
		case kindList, kindDict:
			c := *n
			c.elem = flatten([]*node{n.elem})[0]
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
// A group is transparent: a byte read in it is seen after it, and it sees the bytes read before it.
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
	case kindList, kindDict:
		// An element is a scope of its own: it sees no flag byte of the row around it.
		c := *n
		elem, err := bindBitsOne(n.elem, map[*flagTag]*flagRead{}, met)
		if err != nil {
			return nil, err
		}
		c.elem = elem
		return &c, nil
	case kindWhen, kindGroup, kindRepeat, kindTimes:
		// A when body sees the bytes read before it; a round is a scope of its own; a group is
		// transparent.
		inner := seen
		switch n.kind {
		case kindWhen:
			inner = copySeen(seen)
		case kindRepeat, kindTimes:
			inner = map[*flagTag]*flagRead{}
		}
		c := *n
		fields, err := bindBitsAll(n.fields, inner, met)
		if err != nil {
			return nil, err
		}
		c.fields = fields
		return &c, nil
	}
	return n, nil
}

// typeName names a Go value's type in a message without calling its methods.
func typeName(v any) string {
	if v == nil {
		return "nil"
	}
	return reflect.TypeOf(v).String()
}
