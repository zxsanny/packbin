package packbin

import (
	"math"
	"reflect"
)

// packedFlagByte is a flag byte pack has written: where it sits, the bits set so far, and whether its
// bits are decided one by one as their members are reached (a combined Flags).
type packedFlagByte struct {
	at      int
	flags   byte
	inOrder bool
}

type packer struct {
	out       []byte
	flagBytes map[*flagTag]*packedFlagByte
	// scope is the row of the scope being packed: the top-level row, or the row of one round. A count
	// the row gives for a field that was not written is read from it.
	scope map[string]any
	// lim are the limits of the scheme; slots is what every round of this call has charged so far
	// against lim.MaxSlots, as unpack charges them.
	lim   Limits
	slots int
	// lastText is the last string written, found in out at lastAt for lastLen bytes (count and payload).
	lastText string
	lastAt   int
	lastLen  int
}

// room refuses, naming the member, a write of n bytes that would make the packet longer than
// MaxBytes; nothing of it is written then. Called before every write, so the packet never grows past
// the budget.
func (p *packer) room(id int, name string, n int) error {
	if need := len(p.out) + n; need > p.lim.MaxBytes {
		return packErr(id, name, "%s: the packet would be %d bytes, above the limit of %d bytes", name, need, p.lim.MaxBytes)
	}
	return nil
}

// scopeRoot is where a split flag byte looks for its bits: the fields of its scope and their values.
type scopeRoot struct {
	fields []*node
	values map[string]any
}

// Pack writes row with scheme s: the type number, then the fields in order. row is a
// map[string]any keyed by field name, or, for a scheme whose fields are bound with Bind, a *T (or a
// T). A refused row returns nil bytes and an *Error of kind PackRefused naming the field id.
func Pack(s *Scheme, row any) ([]byte, error) {
	if s.unusable() {
		return nil, packErr(NoField, "", "%s", s.notMade())
	}
	values, err := s.rowValues(row)
	if err != nil {
		return nil, err
	}
	p := packer{out: make([]byte, 1, 32), scope: values, lim: s.limits}
	p.out[0] = byte(s.typeNumber)
	if err := p.fields(s.fields, scopeRoot{s.fields, values}, values, map[string]any{}); err != nil {
		return nil, err
	}
	return p.out, nil
}

// firstField is the id and name an error about the whole row names: the scheme's first field.
func (s *Scheme) firstField() (int, string) {
	if len(s.fields) == 0 {
		return NoField, ""
	}
	return fieldID(s.fields[0]), fieldName(s.fields[0])
}

// rowValues is the row as the walker reads it: each present value by field name, normalized.
func (s *Scheme) rowValues(row any) (map[string]any, error) {
	id, name := s.firstField()
	if row == nil {
		return nil, packErr(id, name, "the row is nil")
	}
	if m, ok := row.(map[string]any); ok {
		if m == nil {
			return nil, packErr(id, name, "the row is a nil map")
		}
		return mapValues(s.top, m)
	}
	if s.row == nil {
		return nil, packErr(id, name, "a %s row needs fields bound with Bind; this scheme packs a map[string]any",
			typeName(row))
	}
	r, ok := s.row.cast(row)
	if !ok {
		if rv := reflect.ValueOf(row); rv.Kind() == reflect.Pointer && rv.IsNil() {
			return nil, packErr(id, name, "the row is a nil %s", typeName(row))
		}
		return nil, packErr(id, name, "the row is a %s; this scheme is bound to %v", typeName(row), s.row.rowType)
	}
	return typedValues(s.top, r), nil
}

// written is what a when reads while packing: the value pack wrote in the scope, or nil.
func written(wrote map[string]any, ref string) any {
	return wrote[ref]
}

// fields packs fields from values, the row of their place. wrote is what the scope has written so
// far, by name (a group's members share the scope around it).
func (p *packer) fields(fields []*node, root scopeRoot, values, wrote map[string]any) error {
	for _, f := range fields {
		switch f.kind {
		case kindInt, kindFloat, kindBytes, kindUtf8:
			v, ok := values[f.name]
			if !ok {
				return packErr(f.id, f.name, "missing %s", f.name)
			}
			if err := p.writeValue(f, v); err != nil {
				return err
			}
			wrote[f.name] = v
		case kindList, kindDict:
			if err := p.collection(f, values[f.name]); err != nil {
				return err
			}
		case kindBool:
			// Reached only through a set flag bit: the bit is the value, nothing follows it.
			wrote[f.name] = true
		case kindFlagByte:
			var flags byte
			if !f.inOrder {
				var err error
				if flags, err = flagValueFor(root, f.tag, wrote); err != nil {
					return err
				}
			}
			if p.flagBytes == nil {
				p.flagBytes = map[*flagTag]*packedFlagByte{}
			}
			if err := p.room(NoField, flagByteName(f, fields), 1); err != nil {
				return err
			}
			p.flagBytes[f.tag] = &packedFlagByte{at: len(p.out), flags: flags, inOrder: f.inOrder}
			p.out = append(p.out, flags)
		case kindFlagBit:
			if err := p.flagBit(f, root, values, wrote); err != nil {
				return err
			}
		case kindWhen:
			if sameValue(written(wrote, f.ref), f.eqValue) {
				if err := p.fields(f.fields, root, values, wrote); err != nil {
					return err
				}
			}
		case kindFlags:
			// Its flag byte is made here, so its bits are looked up among the fields made with it.
			if err := p.fields(f.flat, scopeRoot{f.flat, values}, values, wrote); err != nil {
				return err
			}
		case kindGroup:
			// A mark is reached only through a set flag bit: the bit is the value. A group with members
			// writes them from its own values; a group that is not given has none, so each required
			// member is missing.
			if len(f.fields) > 0 && f.nested {
				if err := p.nestedRow(f, groupValues(values, f)); err != nil {
					return err
				}
			} else if len(f.fields) > 0 {
				if err := p.fields(f.fields, root, groupValues(values, f), wrote); err != nil {
					return err
				}
			}
		default:
			if err := p.counted(f, values, wrote); err != nil {
				return err
			}
		}
	}
	return nil
}

// flagByteName is the name a refusal of the flag byte f carries: its own (a split byte), else the first
// member its bits guard among fields (a combined Flags byte has no name of its own).
func flagByteName(f *node, fields []*node) string {
	if f.name != "" {
		return f.name
	}
	for _, n := range fields {
		if n.kind == kindFlagBit && n.tag == f.tag {
			if name := declaredName(n); name != "" {
				return name
			}
		}
	}
	return "flags"
}

// declaredName is the first name n declares, looking into a flag bit, when, repeat, times, flags and
// group that has no name of its own.
func declaredName(n *node) string {
	if n.kind == kindFlagBit {
		return declaredName(n.field)
	}
	if n.name != "" {
		return n.name
	}
	for _, child := range n.fields {
		if name := declaredName(child); name != "" {
			return name
		}
	}
	return ""
}

func (p *packer) flagBit(f *node, root scopeRoot, values, wrote map[string]any) error {
	b := p.flagBytes[f.tag]
	if b == nil {
		return nil
	}
	mask := byte(1) << f.bit
	if b.inOrder {
		on, err := bitOn(f.field, values, wrote)
		if err != nil {
			return err
		}
		if !on {
			// A times whose count was not written (skipped, or under a clear bit) writes no round, so
			// the values given for it would be dropped without a word.
			held, err := droppedBody(f.field, values, wrote)
			if err != nil {
				return err
			}
			if held != nil {
				return packErr(held.id, held.name, "%s: a value is given, but the count of its times is not written, "+
					"so its bit is clear; write the count before the times", held.name)
			}
			return p.refuseUnwrittenCount(f.field, values, wrote)
		}
		b.flags |= mask
		p.out[b.at] = b.flags
	} else if b.flags&mask == 0 {
		// The bit was decided where the byte sits. A body whose condition or count is not written by
		// then would be dropped without a word, and its own unpack reads no bit for it.
		held, err := droppedBody(f.field, values, wrote)
		if err != nil {
			return err
		}
		if held != nil {
			return packErr(held.id, held.name, "%s: a value is given, but the condition or count of its when or times "+
				"is not written before the flag byte, so its bit is clear; write that field before the flag byte", held.name)
		}
		return p.refuseUnwrittenCount(f.field, values, wrote)
	}
	return p.fields([]*node{f.field}, root, values, wrote)
}

func (p *packer) writeValue(f *node, v any) error {
	if f.kind != kindUtf8 {
		if err := p.room(f.id, f.name, f.size); err != nil {
			return err
		}
	}
	switch f.kind {
	case kindInt:
		n, ok := asInt(v)
		if !ok {
			return packErr(f.id, f.name, "expected an integer for %s, got %s", kindLabel(f), typeName(v))
		}
		if !n.fits(f.size, f.signed) {
			if n.neg {
				return packErr(f.id, f.name, "-%d does not fit in %s", n.mag, kindLabel(f))
			}
			return packErr(f.id, f.name, "%d does not fit in %s", n.mag, kindLabel(f))
		}
		p.out = appendUint(p.out, n.bits(), f.size, f.bigEndian)
	case kindFloat:
		x, ok := asFloat(v)
		if !ok {
			return packErr(f.id, f.name, "expected a number for %s, got %s", kindLabel(f), typeName(v))
		}
		if f.size == 4 {
			if overflowsF32(x) {
				return packErr(f.id, f.name, "%g does not fit in f32", x)
			}
			p.out = appendUint(p.out, uint64(math.Float32bits(float32(x))), 4, f.bigEndian)
		} else {
			p.out = appendUint(p.out, math.Float64bits(x), 8, f.bigEndian)
		}
	case kindUtf8:
		s, ok := v.(string)
		if !ok {
			return packErr(f.id, f.name, "expected a string for utf8, got %s", typeName(v))
		}
		return p.writeString(f.id, f.name, s)
	case kindBytes:
		raw, ok := v.([]byte)
		if !ok {
			return packErr(f.id, f.name, "expected []byte for %s, got %s", kindLabel(f), typeName(v))
		}
		if len(raw) != f.size {
			return packErr(f.id, f.name, "expected %d bytes, got %d", f.size, len(raw))
		}
		p.out = append(p.out, raw...)
	}
	return nil
}

func appendUint(out []byte, x uint64, size int, bigEndian bool) []byte {
	if bigEndian {
		for i := size - 1; i >= 0; i-- {
			out = append(out, byte(x>>(8*i)))
		}
		return out
	}
	for i := 0; i < size; i++ {
		out = append(out, byte(x>>(8*i)))
	}
	return out
}
