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
	// childType is the struct type of a group's own row, and newChild makes a *childType; nil for a
	// field that is not a group with members.
	childType reflect.Type
	newChild  func() any
}

// Bind binds a value field (an integer, float, fixed bytes or bool) or a group to a member of the
// typed row T: get reads it for Pack, set stores it after Unpack. V is the member's type: an integer
// type that holds every value of the field (or a pointer to one), float32 or float64 (or a pointer),
// []byte, bool (or *bool). A nil pointer or nil slice is no value; a stored 0 is a value. For a group
// with members V is a struct G or a *G (nil is no value; a G is always given), and the group's
// members are bound to G; for an empty group V is bool or *bool, as for a Bool.
//
// Every value field and group of a scheme is bound to the same T, or none is (inside a group, to
// the group's G): a scheme with bound fields packs a *T (or a T) and unpacks to a *T; it still packs
// and unpacks the map form by name.
func Bind[T, V any](f Field, get func(*T) V, set func(*T, V)) Field {
	n := nodeOf(f)
	if n == nil {
		return &node{kind: kindInvalid, id: NoField, err: "Bind: nil field"}
	}
	c := *n
	switch {
	case !isValueKind(n.kind) && n.kind != kindGroup:
		c.err = fmt.Sprintf("Bind takes an integer, float, fixed bytes, bool or group field, not %s", kindLabel(n))
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
	if n.kind == kindGroup && len(n.fields) > 0 && c.err == "" {
		bindGroupRow(c.acc, reflect.TypeFor[V](), func(row any) V { return get(row.(*T)) },
			func(row any, v V) { set(row.(*T), v) })
	}
	return &c
}

// bindGroupRow makes the accessor of a group with members read and store its row as a *G, whatever
// V is (a *G, or a G copied).
func bindGroupRow[V any](acc *accessor, t reflect.Type, get func(row any) V, set func(row any, v V)) {
	byPointer := t.Kind() == reflect.Pointer
	acc.childType = t
	if byPointer {
		acc.childType = t.Elem()
	}
	acc.newChild = func() any { return reflect.New(acc.childType).Interface() }
	acc.get = func(row any) (any, bool) {
		v := get(row)
		if byPointer {
			p := reflect.ValueOf(&v).Elem()
			return v, !p.IsNil()
		}
		p := reflect.New(t)
		p.Elem().Set(reflect.ValueOf(&v).Elem())
		return p.Interface(), true
	}
	acc.set = func(row any, child any) {
		if byPointer {
			set(row, child.(V))
			return
		}
		set(row, *child.(*V))
	}
}

// checkMemberType returns why a member of type t cannot hold the field n, or "".
func checkMemberType(n *node, t reflect.Type) string {
	if n.kind == kindGroup && len(n.fields) > 0 {
		if t.Kind() == reflect.Struct || (t.Kind() == reflect.Pointer && t.Elem().Kind() == reflect.Struct) {
			return ""
		}
		return fmt.Sprintf("a %v member cannot hold group %s; bind a struct or a pointer to a struct", t, n.name)
	}
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
	case kindBool, kindGroup:
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
