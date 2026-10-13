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
}

// Pack writes row with scheme s: the type number, then the fields in order. row is a
// map[string]any keyed by field name, or, for a scheme whose fields are bound with Bind, a *T (or a
// T). A refused row returns nil bytes and an *Error of kind PackRefused naming the field id.
func Pack(s *Scheme, row any) ([]byte, error) {
	if s == nil {
		return nil, packErr(NoField, "", "the scheme is nil")
	}
	values, err := s.rowValues(row)
	if err != nil {
		return nil, err
	}
	p := packer{out: make([]byte, 1, 32)}
	p.out[0] = byte(s.typeNumber)
	if err := p.fields(s.fields, s.fields, values, map[string]any{}); err != nil {
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
		values := make(map[string]any, len(m))
		for k, v := range m {
			if nv, present := normalize(v); present {
				values[k] = nv
			}
		}
		return values, nil
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
	values := make(map[string]any, len(s.values))
	for _, n := range s.values {
		if v, present := n.acc.get(r); present {
			values[n.name] = v
		}
	}
	return values, nil
}

// written is what a when reads while packing: the value pack wrote in the scope, or nil.
func written(wrote map[string]any, ref string) any {
	return wrote[ref]
}

func (p *packer) fields(fields, all []*node, values, wrote map[string]any) error {
	for _, f := range fields {
		switch f.kind {
		case kindInt, kindFloat, kindBytes:
			v, ok := values[f.name]
			if !ok {
				return packErr(f.id, f.name, "missing %s", f.name)
			}
			if err := p.writeValue(f, v); err != nil {
				return err
			}
			wrote[f.name] = v
		case kindBool:
			// Reached only through a set flag bit: the bit is the value, nothing follows it.
			wrote[f.name] = true
		case kindFlagByte:
			var flags byte
			if !f.inOrder {
				flags = flagValueFor(all, f.tag, values, wrote)
			}
			if p.flagBytes == nil {
				p.flagBytes = map[*flagTag]*packedFlagByte{}
			}
			p.flagBytes[f.tag] = &packedFlagByte{at: len(p.out), flags: flags, inOrder: f.inOrder}
			p.out = append(p.out, flags)
		case kindFlagBit:
			if err := p.flagBit(f, all, values, wrote); err != nil {
				return err
			}
		case kindWhen:
			if sameValue(written(wrote, f.ref), f.eqValue) {
				if err := p.fields(f.fields, all, values, wrote); err != nil {
					return err
				}
			}
		case kindFlags:
			// Its flag byte is made here, so its bits are looked up among the fields made with it.
			if err := p.fields(f.flat, f.flat, values, wrote); err != nil {
				return err
			}
		}
	}
	return nil
}

func (p *packer) flagBit(f *node, all []*node, values, wrote map[string]any) error {
	b := p.flagBytes[f.tag]
	if b == nil {
		return nil
	}
	mask := byte(1) << f.bit
	if b.inOrder {
		if !bitOn(f.field, values, wrote) {
			return nil
		}
		b.flags |= mask
		p.out[b.at] = b.flags
	} else if b.flags&mask == 0 {
		// The bit was decided where the byte sits. A body whose condition is not written by then
		// would be dropped without a word, and its own unpack reads no bit for it.
		if held := droppedBody(f.field, values, wrote); held != nil {
			return packErr(held.id, held.name, "%s: a value is given, but the condition of its when is not "+
				"written before the flag byte, so its bit is clear; write that field before the flag byte", held.name)
		}
		return nil
	}
	return p.fields([]*node{f.field}, all, values, wrote)
}

func (p *packer) writeValue(f *node, v any) error {
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
