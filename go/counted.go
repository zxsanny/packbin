package packbin

import "fmt"

// Repeat writes its members once a round until the buffer ends; there is no count, so it must be the
// last thing the packet reads. NewScheme refuses a scheme in which a field that can write a byte
// stands after it (in its own place or after the When, Flags, flag bit, Group or Nested that holds
// it), and one that has it inside a List or Dict element; use Times there. The anchor is the next id
// and is not written. In a map row each name the round holds takes one list, entry i for round i (a
// value that is not a list goes to every round); bound with Bind it takes a slice of a struct (or of
// a pointer to one), one element a round. Unpack gives each name one entry a round, nil where the
// round skipped it. The body is a scope of its own.
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
		case kindList, kindDict:
			// An element starts outside any round.
			err = checkRoundNesting([]*node{n.elem}, false)
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
		case kindList, kindDict:
			err = checkRoundBodies([]*node{n.elem})
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

// checkRepeatLast refuses a repeat that is not the last thing its packet reads (contract repeat-last):
// a repeat has no count, so unpack reads rounds until the buffer ends and would read whatever is
// written after it as more rounds. Refused: a repeat that a field which can write a byte follows, in
// its own place or after the when, flags, flag bit, group or nested row that holds it, up to the top
// level; and a repeat inside a list or dict element, which the next element follows. open is the
// first repeat met in the places walked so far; the repeat open after nodes is returned. A round body
// and an element are places of their own, with none open; a repeat inside a round is refused by
// checkRoundNesting, so a round body is walked only for the elements it holds. writers keeps the first
// writer under each container, found once: asking again at every level made a chain of nested when or
// group containers quadratic in the depth (F79).
func checkRepeatLast(nodes []*node, open *node, inElement bool, writers writerMemo) (*node, error) {
	for _, n := range nodes {
		if open != nil {
			if w := firstWriter(n, writers); w != nil {
				return nil, schemeErr(open.id, "", "repeat %d: %s follows it; a repeat reads to the end of the packet, so nothing can follow it; use times",
					open.id, writerLabel(w))
			}
		}
		var err error
		switch n.kind {
		case kindRepeat:
			if inElement {
				return nil, schemeErr(n.id, "", "repeat %d is inside a list or dict element; a repeat reads to the end of the packet, so another element cannot follow it; use times",
					n.id)
			}
			if open == nil {
				open = n
			}
			_, err = checkRepeatLast(n.fields, nil, false, writers)
		case kindTimes:
			_, err = checkRepeatLast(n.fields, nil, false, writers)
		case kindWhen, kindFlags, kindGroup:
			open, err = checkRepeatLast(n.fields, open, inElement, writers)
		case kindFlagBit:
			open, err = checkRepeatLast([]*node{n.field}, open, inElement, writers)
		case kindList, kindDict:
			_, err = checkRepeatLast([]*node{n.elem}, nil, true, writers)
		}
		if err != nil {
			return nil, err
		}
	}
	return open, nil
}

// writerMemo is the first writer under each when, group, flag bit, repeat and times already looked at
// (nil is an answer too).
type writerMemo map[*node]*node

// firstWriter is the first field at or under n that can write a byte for some row, nil when none can.
// A bool is a bit of a flag byte written earlier and a zero-width Bytes has no byte. A when, a group
// and a flag bit write what they hold, so the field found is the one inside them; a repeat or times
// whose body can write a byte is found itself. Everything else writes: a flag byte and a flags, a
// list and a dict (their count) too.
func firstWriter(n *node, memo writerMemo) *node {
	switch n.kind {
	case kindBool:
		return nil
	case kindBytes:
		if n.size == 0 {
			return nil
		}
		return n
	case kindFlagBit, kindWhen, kindGroup, kindRepeat, kindTimes:
		if w, ok := memo[n]; ok {
			return w
		}
		w := heldWriter(n, memo)
		memo[n] = w
		return w
	}
	return n
}

func heldWriter(n *node, memo writerMemo) *node {
	switch n.kind {
	case kindFlagBit:
		return firstWriter(n.field, memo)
	case kindRepeat, kindTimes:
		if firstWriterIn(n.fields, memo) == nil {
			return nil
		}
		return n
	}
	return firstWriterIn(n.fields, memo)
}

func firstWriterIn(nodes []*node, memo writerMemo) *node {
	for _, n := range nodes {
		if w := firstWriter(n, memo); w != nil {
			return w
		}
	}
	return nil
}

// writerLabel names the field that follows a repeat in the words of the other scheme errors: a value
// field by its id and name (a u2 by its first slot), a repeat, times or flags by its kind and anchor
// (the flag byte of a flags is the flags), a split flag byte and a list or dict by name.
func writerLabel(n *node) string {
	switch n.kind {
	case kindRepeat, kindTimes, kindList, kindDict:
		return ownerLabel(n)
	case kindFlags:
		return fmt.Sprintf("flags %d", n.id)
	case kindFlagByte:
		if n.inOrder {
			return fmt.Sprintf("flags %d", n.id)
		}
		return fmt.Sprintf("flag byte %q", n.name)
	}
	return fmt.Sprintf("field id %d (%s)", n.id, n.name)
}
