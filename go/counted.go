package packbin

import "fmt"

// Repeat writes its members once a round until the buffer ends; there is no count, so nothing may
// follow it. The anchor is the next id and is not written. In a map row each name the round holds
// takes one list, entry i for round i (a value that is not a list goes to every round); bound with
// Bind it takes a slice of a struct (or of a pointer to one), one element a round. Unpack gives each
// name one entry a round, nil where the round skipped it. The body is a scope of its own.
func Repeat(anchor int, members ...Field) Field {
	return &node{kind: kindRepeat, id: anchor, fields: nodesOf(members)}
}

// Times writes its members exactly count times, count being the value of the integer field countID
// written earlier in the same scope; the next field follows. The rows of the rounds are given as for
// Repeat. The anchor is the next id and is not written.
func Times(anchor, countID int, members ...Field) Field {
	return &node{kind: kindTimes, id: anchor, countID: countID, fields: nodesOf(members)}
}

// Sized is raw bytes whose length is the integer field countID, written earlier in the same scope;
// it has no length of its own. Its value is a []byte.
func Sized(id int, name string, countID int) Field {
	return &node{kind: kindSized, id: id, name: name, countID: countID}
}

// U2 packs its slots two bits each, four to a byte, low bits first; unused bits are 0.
func U2(slots ...Field) Field {
	n := &node{kind: kindU2, id: NoField, fields: nodesOf(slots)}
	if len(slots) == 0 {
		n.err = "u2 needs at least one slot"
		return n
	}
	for _, s := range n.fields {
		if s != nil && s.kind != kindSlot {
			n.err = fmt.Sprintf("u2 takes Slot fields, not %s", kindLabel(s))
			return n
		}
	}
	if first := n.fields[0]; first != nil {
		n.id, n.name = first.id, first.name
	}
	return n
}

// Slot is one 2-bit value (0..3) of U2; it stands only directly in U2. Unpack gives it as a uint8.
func Slot(id int, name string) Field { return &node{kind: kindSlot, id: id, name: name} }

// Bits is a list of 0 and 1, one bit an item, low bits first; the item count is the integer field
// countID, written earlier in the same scope. Its value is a slice of integers; unpack gives []uint8.
func Bits(id int, name string, countID int) Field {
	return &node{kind: kindBits, id: id, name: name, countID: countID}
}

// Packed is a list of small integers, width (1 or 2) bits an item, low bits first; the item count is
// the integer field countID plus bias (0 or -1). Its value is a slice of integers; unpack gives
// []uint8.
func Packed(width, id int, name string, countID, bias int) Field {
	n := &node{kind: kindPacked, id: id, name: name, countID: countID, width: width, bias: bias}
	switch {
	case width != 1 && width != 2:
		n.err = "packed width must be 1 or 2"
	case bias != 0 && bias != -1:
		n.err = "packed bias must be 0 or -1"
	}
	return n
}

// checkRoundNesting refuses a repeat or times inside a round: a round packs entry i of each list, so
// a round in it would read every inner round from the same entry. Wherever it sits in the round:
// directly, or under when, flags, flag bits and groups.
func checkRoundNesting(nodes []*node, inRound bool) error {
	for _, n := range nodes {
		var err error
		switch n.kind {
		case kindRepeat, kindTimes:
			if inRound {
				return schemeErr(n.id, "", "%s %d is inside a repeat or times round; a round cannot hold another repeat or times",
					kindLabel(n), n.id)
			}
			err = checkRoundNesting(n.fields, true)
		case kindWhen, kindFlags, kindGroup:
			err = checkRoundNesting(n.fields, inRound)
		case kindFlagBit:
			err = checkRoundNesting([]*node{n.field}, inRound)
		}
		if err != nil {
			return err
		}
	}
	return nil
}

// checkRoundBodies refuses a repeat or times whose body holds no member: a round of it writes no byte,
// so a large count would loop for no output. A member is any field but a when or group that holds
// none; a flag byte, a flags with no member and a zero-width Bytes are members.
func checkRoundBodies(nodes []*node) error {
	for _, n := range nodes {
		var err error
		switch n.kind {
		case kindRepeat, kindTimes:
			if !holdsMember(n.fields) {
				return schemeErr(n.id, "", "%s %d: the body holds no member; a round of it would charge no slot and write nothing",
					kindLabel(n), n.id)
			}
			err = checkRoundBodies(n.fields)
		case kindWhen, kindFlags, kindGroup:
			err = checkRoundBodies(n.fields)
		case kindFlagBit:
			err = checkRoundBodies([]*node{n.field})
		}
		if err != nil {
			return err
		}
	}
	return nil
}

func holdsMember(nodes []*node) bool {
	for _, n := range nodes {
		switch n.kind {
		case kindWhen, kindGroup, kindRepeat, kindTimes:
			if holdsMember(n.fields) {
				return true
			}
		case kindFlagBit:
			if holdsMember([]*node{n.field}) {
				return true
			}
		default:
			return true
		}
	}
	return false
}
