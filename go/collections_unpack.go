package packbin

import (
	"encoding/binary"
	"math"
)

// scalar reads an integer, float, fixed bytes or string field and returns its value.
func (r *reader) scalar(f *node) (any, error) {
	switch f.kind {
	case kindUtf8:
		return r.utf8(f.id, f.name)
	case kindFloat:
		b, err := r.take(f, f.size)
		if err != nil {
			return nil, err
		}
		if f.size == 4 {
			return math.Float32frombits(uint32(readUint(b, 4, f.bigEndian))), nil
		}
		return math.Float64frombits(readUint(b, 8, f.bigEndian)), nil
	case kindBytes:
		b, err := r.take(f, f.size)
		if err != nil {
			return nil, err
		}
		return append([]byte{}, b...), nil
	}
	b, err := r.take(f, f.size)
	if err != nil {
		return nil, err
	}
	return readInt(b, f.size, f.signed, f.bigEndian), nil
}

// utf8 reads a compact text field (text_decode.go). A field that is refused is reported with the shape
// of a short packet: the field, the bytes needed and left if the buffer ended inside it, and for any
// other refusal nothing more needed and the bytes left where the string starts.
func (r *reader) utf8(id int, name string) (string, error) {
	text, next, got := decodeText(r.buf, r.off)
	if got.kind != textOK {
		return "", shortErr(id, name, got.needed, got.left)
	}
	r.off = next
	return text, nil
}

// collection reads a list ([]any) or a dict (map[string]any): a u16 count, then the items, each a key
// and an element for a dict. An element that reads no byte is refused, so a count of 65535 cannot be
// walked for no input; a dict key must be greater than the one before it (compared as UTF-8 bytes), so a
// key given twice or out of order is refused.
func (r *reader) collection(f *node) (any, error) {
	if left := len(r.buf) - r.off; left < 2 {
		return nil, shortErr(NoField, f.name, 2, left)
	}
	count := int(binary.LittleEndian.Uint16(r.buf[r.off:]))
	r.off += 2
	// Every item reads at least a byte, so the bytes left bound what a count can claim.
	room := min(count, len(r.buf)-r.off)
	if f.kind == kindList {
		items := make([]any, 0, room)
		for range count {
			v, err := r.item(f)
			if err != nil {
				return nil, err
			}
			items = append(items, v)
		}
		return items, nil
	}
	entries := make(map[string]any, room)
	prev := ""
	for i := range count {
		key, err := r.utf8(NoField, f.name)
		if err != nil {
			return nil, err
		}
		v, err := r.item(f)
		if err != nil {
			return nil, err
		}
		if i > 0 && key <= prev {
			return nil, shortErr(NoField, f.name, 0, 0)
		}
		prev = key
		entries[key] = v
	}
	return entries, nil
}

// item reads one element of list or dict f.
func (r *reader) item(f *node) (any, error) {
	before := r.off
	v, err := r.element(f.elem)
	if err != nil {
		return nil, err
	}
	if r.off == before {
		return nil, r.unreadable(NoField, f.name)
	}
	return v, nil
}

func (r *reader) element(e *node) (any, error) {
	switch e.kind {
	case kindGroup:
		return r.row(e)
	case kindList, kindDict:
		return r.collection(e)
	}
	return r.scalar(e)
}
