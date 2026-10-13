package packbin

import "fmt"

// FlagBits is the number of bits one flag byte holds.
const FlagBits = 8

type kind uint8

const (
	kindInvalid kind = iota
	kindInt
	kindFloat
	kindBytes
	kindBool
	kindFlags
	kindFlagByte
	kindFlagBit
	kindWhen
)

// flagTag is the identity of one flag byte (a handle, or one read of it once a scheme is built).
type flagTag struct{ name string }

// node is one field. Constructors make it; a scheme works on copies, so a Field can be shared by any
// number of schemes and goroutines.
type node struct {
	kind      kind
	id        int // value id; the anchor of flags and when; NoField for a flag byte or bit
	name      string
	size      int // bytes of an integer, a float or fixed bytes
	signed    bool
	bigEndian bool
	fields    []*node  // flags and when members
	flat      []*node  // flags: its flag byte and bits, made when the scheme is built
	tag       *flagTag // flag byte: this read; flag bit: the byte it belongs to
	inOrder   bool     // flag byte made by flags: its bits are decided as their members are reached
	bit       int      // flag bit: its number in the byte
	field     *node    // flag bit: the member it guards
	eqID      int      // when: the id eq names
	eqValue   any      // when: the value eq compares with
	ref       string   // when: the name eq resolves to, set when the scheme is built
	acc       *accessor
	err       string // a constructor's refusal, reported by NewScheme
}

// Field is one field of a scheme, made by the constructors of this package.
type Field interface {
	fieldNode() *node
}

func (n *node) fieldNode() *node { return n }

func nodeOf(f Field) *node {
	if f == nil {
		return nil
	}
	return f.fieldNode()
}

func nodesOf(fields []Field) []*node {
	out := make([]*node, len(fields))
	for i, f := range fields {
		out[i] = nodeOf(f)
	}
	return out
}

func intField(id int, name string, size int, signed bool) Field {
	return &node{kind: kindInt, id: id, name: name, size: size, signed: signed}
}

// U8 is an unsigned 8-bit integer.
func U8(id int, name string) Field { return intField(id, name, 1, false) }

// U16 is an unsigned 16-bit integer, little-endian.
func U16(id int, name string) Field { return intField(id, name, 2, false) }

// U32 is an unsigned 32-bit integer, little-endian.
func U32(id int, name string) Field { return intField(id, name, 4, false) }

// U64 is an unsigned 64-bit integer, little-endian.
func U64(id int, name string) Field { return intField(id, name, 8, false) }

// I8 is a signed 8-bit integer.
func I8(id int, name string) Field { return intField(id, name, 1, true) }

// I16 is a signed 16-bit integer, little-endian.
func I16(id int, name string) Field { return intField(id, name, 2, true) }

// I32 is a signed 32-bit integer, little-endian.
func I32(id int, name string) Field { return intField(id, name, 4, true) }

// I64 is a signed 64-bit integer, little-endian.
func I64(id int, name string) Field { return intField(id, name, 8, true) }

// F32 is an IEEE 754 single, little-endian.
func F32(id int, name string) Field { return &node{kind: kindFloat, id: id, name: name, size: 4} }

// F64 is an IEEE 754 double, little-endian.
func F64(id int, name string) Field { return &node{kind: kindFloat, id: id, name: name, size: 8} }

// Bytes is exactly size raw bytes, with no length.
func Bytes(id int, name string, size int) Field {
	n := &node{kind: kindBytes, id: id, name: name, size: size}
	if size < 0 {
		n.err = fmt.Sprintf("bytes size %d: expected 0 or more", size)
	}
	return n
}

// Bool is a flag bit with no payload: set only for true. It stands only directly under Flags or a
// flag byte's Bit.
func Bool(id int, name string) Field { return &node{kind: kindBool, id: id, name: name} }

// Be makes an integer or float field big-endian; any other field is returned as it is.
func Be(f Field) Field {
	n := nodeOf(f)
	if n == nil {
		return &node{kind: kindInvalid, id: NoField, err: "Be: nil field"}
	}
	switch n.kind {
	case kindInt, kindFloat:
		c := *n
		c.bigEndian = true
		return &c
	case kindFlagBit:
		c := *n
		c.field = nodeOf(Be(n.field))
		return &c
	}
	return n
}

// Flags is one byte in front of its members: bit i is member i, a set bit writes that member, a
// clear bit skips it. At most FlagBits members. The anchor is the next id and is not written.
func Flags(anchor int, members ...Field) Field {
	n := &node{kind: kindFlags, id: anchor, fields: nodesOf(members)}
	if len(members) > FlagBits {
		n.err = fmt.Sprintf("flags: ninth bit (%s); a flag byte holds %d bits", fieldName(n.fields[FlagBits]), FlagBits)
	}
	return n
}

// FlagByteHandle is a split-form flag byte: used as a Field it is the place the byte is read, and
// Bit puts a member under its next bit. A handle can be read more than once and shared by schemes.
type FlagByteHandle struct{ n *node }

// FlagByte makes a split-form flag byte handle.
func FlagByte(name string) *FlagByteHandle {
	return &FlagByteHandle{n: &node{kind: kindFlagByte, id: NoField, name: name, tag: &flagTag{name: name}}}
}

func (h *FlagByteHandle) fieldNode() *node {
	if h == nil {
		return nil
	}
	return h.n
}

// Bit puts f under the next bit of the flag byte read before it in the same scope. The scheme
// numbers the bits when it is built.
func (h *FlagByteHandle) Bit(f Field) Field {
	n := &node{kind: kindFlagBit, id: NoField, field: nodeOf(f)}
	switch {
	case h == nil || h.n == nil:
		n.err = "Bit on a nil flag byte"
	case n.field == nil:
		n.err = "flag bit: nil field"
	default:
		n.tag = h.n.tag
	}
	return n
}

// Cond is the condition of When, made by Eq.
type Cond struct {
	id    int
	value any
}

// Eq is true when the field id, read earlier in the same scope, equals value.
func Eq(id int, value any) Cond { return Cond{id: id, value: value} }

// When writes its members only when cond holds on what was written (packing) or read (unpacking)
// earlier in the same scope. The anchor is the next id and is not written.
func When(anchor int, cond Cond, members ...Field) Field {
	v, ok := normalize(cond.value)
	if !ok {
		v = nil
	}
	return &node{kind: kindWhen, id: anchor, eqID: cond.id, eqValue: v, fields: nodesOf(members)}
}

// fieldName is the name a field declares; a flag bit is named by its member.
func fieldName(n *node) string {
	if n == nil {
		return ""
	}
	if n.kind == kindFlagBit {
		return fieldName(n.field)
	}
	return n.name
}

// fieldID is the id an error names for n: its value id or anchor; a flag bit's member's.
func fieldID(n *node) int {
	if n == nil {
		return NoField
	}
	if n.kind == kindFlagBit {
		return fieldID(n.field)
	}
	return n.id
}

func isValueKind(k kind) bool {
	return k == kindInt || k == kindFloat || k == kindBytes || k == kindBool
}

func kindLabel(n *node) string {
	switch n.kind {
	case kindInt:
		if n.signed {
			return fmt.Sprintf("i%d", n.size*8)
		}
		return fmt.Sprintf("u%d", n.size*8)
	case kindFloat:
		return fmt.Sprintf("f%d", n.size*8)
	case kindBytes:
		return fmt.Sprintf("bytes(%d)", n.size)
	case kindBool:
		return "bool"
	case kindFlags:
		return "flags"
	case kindFlagByte:
		return "flag byte"
	case kindFlagBit:
		return "flag bit"
	case kindWhen:
		return "when"
	}
	return "field"
}
