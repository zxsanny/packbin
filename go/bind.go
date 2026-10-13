package packbin

import (
	"fmt"
	"reflect"
)

// accessor binds a value field to a member of a typed row T through a getter and a setter.
type accessor struct {
	rowType reflect.Type
	// cast returns the *T a row given to Pack stands for (a *T, or a T copied), or false.
	cast func(row any) (any, bool)
	// get reads the member of a *T, normalized; false is no value.
	get func(row any) (any, bool)
	// set stores an unpacked value into a *T.
	set    func(row any, v any)
	newRow func() any
}

// Bind binds a value field (an integer, float, fixed bytes or bool) to a member of the typed row T:
// get reads it for Pack, set stores it after Unpack. V is the member's type: an integer type that
// holds every value of the field (or a pointer to one), float32 or float64 (or a pointer), []byte,
// bool (or *bool). A nil pointer or nil slice is no value; a stored 0 is a value.
//
// Every value field of a scheme is bound to the same T, or none is: a scheme with bound fields packs
// a *T (or a T) and unpacks to a *T; it still packs and unpacks the map form by name.
func Bind[T, V any](f Field, get func(*T) V, set func(*T, V)) Field {
	n := nodeOf(f)
	if n == nil {
		return &node{kind: kindInvalid, id: NoField, err: "Bind: nil field"}
	}
	c := *n
	switch {
	case !isValueKind(n.kind):
		c.err = fmt.Sprintf("Bind takes an integer, float, fixed bytes or bool field, not %s", kindLabel(n))
	case n.acc != nil:
		c.err = "the field is already bound"
	case get == nil || set == nil:
		c.err = "Bind needs a getter and a setter"
	default:
		if reason := checkMemberType(n, reflect.TypeFor[V]()); reason != "" {
			c.err = reason
		}
	}
	c.acc = &accessor{
		rowType: reflect.TypeFor[T](),
		cast: func(row any) (any, bool) {
			switch r := row.(type) {
			case *T:
				return r, r != nil
			case T:
				return &r, true
			}
			return nil, false
		},
		get: func(row any) (any, bool) {
			return normalize(any(get(row.(*T))))
		},
		set: func(row any, v any) {
			set(row.(*T), convertTo[V](v))
		},
		newRow: func() any { return new(T) },
	}
	return &c
}

// checkMemberType returns why a member of type t cannot hold the field n, or "".
func checkMemberType(n *node, t reflect.Type) string {
	if n.kind == kindBytes {
		if t.Kind() == reflect.Slice && t.Elem().Kind() == reflect.Uint8 {
			return ""
		}
		return fmt.Sprintf("a %v member cannot hold %s; bind a []byte", t, kindLabel(n))
	}
	elem := t
	if elem.Kind() == reflect.Pointer {
		elem = elem.Elem()
	}
	ok := false
	switch n.kind {
	case kindInt:
		ok = holdsInt(elem, n.size*8, n.signed)
	case kindFloat:
		ok = elem.Kind() == reflect.Float64 || (elem.Kind() == reflect.Float32 && n.size == 4)
	case kindBool:
		ok = elem.Kind() == reflect.Bool
	}
	if ok {
		return ""
	}
	return fmt.Sprintf("a %v member cannot hold every %s value", t, kindLabel(n))
}

func holdsInt(t reflect.Type, bits int, signed bool) bool {
	switch t.Kind() {
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		if signed {
			return t.Bits() >= bits
		}
		return t.Bits() > bits
	case reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64:
		return !signed && t.Bits() >= bits
	}
	return false
}

// convertTo turns an unpacked value into the member type V. checkMemberType has made sure V holds
// it, so the conversion never narrows.
func convertTo[V any](v any) V {
	if x, ok := v.(V); ok {
		return x
	}
	var out V
	dst := reflect.ValueOf(&out).Elem()
	if dst.Kind() == reflect.Pointer {
		p := reflect.New(dst.Type().Elem())
		p.Elem().Set(reflect.ValueOf(v).Convert(p.Elem().Type()))
		dst.Set(p)
		return out
	}
	dst.Set(reflect.ValueOf(v).Convert(dst.Type()))
	return out
}
