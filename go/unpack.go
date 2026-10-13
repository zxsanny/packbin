package packbin

import (
	"encoding/binary"
	"math"
)

// Unpack reads buf with the scheme its first byte names, out of schemes. The row is a *T for a scheme
// whose fields are bound with Bind, else a map[string]any. A buffer that cannot be read returns a nil
// row and an *Error (ShortPacket, TrailingBytes, UnknownType or BadValue); it never panics.
func Unpack(buf []byte, schemes ...*Scheme) (any, error) {
	s, values, err := dispatch(buf, schemes)
	if err != nil {
		return nil, err
	}
	if s.row == nil {
		return values, nil
	}
	row := s.row.newRow()
	for _, n := range s.values {
		if v, ok := values[n.name]; ok {
			n.acc.set(row, v)
		}
	}
	return row, nil
}

// UnpackMap is Unpack with the row as a map keyed by field name, for every scheme. A value has the
// Go type of its field: uint8 to uint64, int8 to int64, float32, float64, []byte, and true for a set
// bool. A field that was not read (a clear bit, a when that did not match) has no key.
func UnpackMap(buf []byte, schemes ...*Scheme) (map[string]any, error) {
	_, values, err := dispatch(buf, schemes)
	if err != nil {
		return nil, err
	}
	return values, nil
}

func dispatch(buf []byte, schemes []*Scheme) (*Scheme, map[string]any, error) {
	if len(schemes) == 0 {
		return nil, nil, schemeErr(NoField, "", "unpack needs at least one scheme")
	}
	var seen [256]bool
	for _, s := range schemes {
		if s == nil {
			return nil, nil, schemeErr(NoField, "", "a scheme is nil")
		}
		if seen[s.typeNumber] {
			return nil, nil, schemeErr(NoField, "", "duplicate type number %d", s.typeNumber)
		}
		seen[s.typeNumber] = true
	}
	if len(buf) < 1 {
		return nil, nil, shortErr(NoField, "", 1, 0)
	}
	var match *Scheme
	for _, s := range schemes {
		if s.typeNumber == int(buf[0]) {
			match = s
			break
		}
	}
	if match == nil {
		return nil, nil, &Error{Kind: UnknownType, Field: NoField, Actual: int(buf[0])}
	}
	r := reader{buf: buf, off: 1}
	values := make(map[string]any, len(match.values))
	if err := r.fields(match.fields, values); err != nil {
		return nil, nil, err
	}
	if r.off < len(buf) {
		return nil, nil, &Error{Kind: TrailingBytes, Field: NoField, Left: len(buf) - r.off}
	}
	return match, values, nil
}

type reader struct {
	buf       []byte
	off       int
	flagBytes map[*flagTag]byte
}

func (r *reader) take(f *node, size int) ([]byte, error) {
	left := len(r.buf) - r.off
	if left < size {
		return nil, shortErr(f.id, f.name, size, left)
	}
	b := r.buf[r.off : r.off+size]
	r.off += size
	return b, nil
}

func (r *reader) fields(fields []*node, values map[string]any) error {
	for _, f := range fields {
		switch f.kind {
		case kindInt:
			b, err := r.take(f, f.size)
			if err != nil {
				return err
			}
			values[f.name] = readInt(b, f.size, f.signed, f.bigEndian)
		case kindFloat:
			b, err := r.take(f, f.size)
			if err != nil {
				return err
			}
			if f.size == 4 {
				values[f.name] = math.Float32frombits(uint32(readUint(b, 4, f.bigEndian)))
			} else {
				values[f.name] = math.Float64frombits(readUint(b, 8, f.bigEndian))
			}
		case kindBytes:
			b, err := r.take(f, f.size)
			if err != nil {
				return err
			}
			values[f.name] = append([]byte{}, b...)
		case kindBool:
			// Reached only through a set flag bit.
			values[f.name] = true
		case kindFlagByte:
			b, err := r.take(f, 1)
			if err != nil {
				return err
			}
			if r.flagBytes == nil {
				r.flagBytes = map[*flagTag]byte{}
			}
			r.flagBytes[f.tag] = b[0]
		case kindFlagBit:
			if r.flagBytes[f.tag]&(1<<f.bit) == 0 {
				continue
			}
			if err := r.fields([]*node{f.field}, values); err != nil {
				return err
			}
		case kindWhen:
			if sameValue(values[f.ref], f.eqValue) {
				if err := r.fields(f.fields, values); err != nil {
					return err
				}
			}
		case kindFlags:
			if err := r.fields(f.flat, values); err != nil {
				return err
			}
		}
	}
	return nil
}

func readUint(b []byte, size int, bigEndian bool) uint64 {
	switch size {
	case 1:
		return uint64(b[0])
	case 2:
		if bigEndian {
			return uint64(binary.BigEndian.Uint16(b))
		}
		return uint64(binary.LittleEndian.Uint16(b))
	case 4:
		if bigEndian {
			return uint64(binary.BigEndian.Uint32(b))
		}
		return uint64(binary.LittleEndian.Uint32(b))
	}
	if bigEndian {
		return binary.BigEndian.Uint64(b)
	}
	return binary.LittleEndian.Uint64(b)
}

// readInt is the integer in b as the Go type of its field.
func readInt(b []byte, size int, signed, bigEndian bool) any {
	x := readUint(b, size, bigEndian)
	switch size {
	case 1:
		if signed {
			return int8(x)
		}
		return uint8(x)
	case 2:
		if signed {
			return int16(x)
		}
		return uint16(x)
	case 4:
		if signed {
			return int32(x)
		}
		return uint32(x)
	}
	if signed {
		return int64(x)
	}
	return x
}
