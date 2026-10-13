package packbin

import (
	"fmt"
	"reflect"
)

// A list or dict member of a typed row is a []E or a map[string]E (E the element: a scalar type, a
// struct or pointer to struct for a nested row or flags element, or another slice or map). These turn
// one into the []any or map[string]any the walker packs, and an unpacked one back.

// checkCollectionType returns why a member of type t cannot hold the list or dict n, or "".
func checkCollectionType(n *node, t reflect.Type) string {
	switch {
	case n.kind == kindList && t.Kind() == reflect.Slice:
	case n.kind == kindDict && t.Kind() == reflect.Map && t.Key().Kind() == reflect.String:
	default:
		want := "a slice"
		if n.kind == kindDict {
			want = "a map with string keys"
		}
		return fmt.Sprintf("a %v member cannot hold %s %s; bind %s", t, kindLabel(n), n.name, want)
	}
	return checkElementType(n.elem, t.Elem())
}

func checkElementType(e *node, t reflect.Type) string {
	switch e.kind {
	case kindGroup:
		if isStructOrPointer(t) {
			return ""
		}
		return fmt.Sprintf("a %v item cannot hold a nested row; bind a struct or a pointer to a struct", t)
	case kindList, kindDict:
		return checkCollectionType(e, t)
	}
	return checkMemberType(e, t)
}

// leafType is the struct type of the nested row a chain of lists and dicts in a member of type t ends
// in; nil when it ends in a scalar.
func leafType(n *node, t reflect.Type) reflect.Type {
	for n.kind == kindList || n.kind == kindDict {
		t = t.Elem()
		n = n.elem
	}
	if n.kind != kindGroup {
		return nil
	}
	if t.Kind() == reflect.Pointer {
		return t.Elem()
	}
	return t
}

// toWalk turns a typed item into what the walker packs: a nested row into its values by name, a list
// or dict into a []any or map[string]any of such items, a scalar into its normalized value. A nil
// slice, map or pointer is no value (nil).
func toWalk(e *node, rv reflect.Value) any {
	switch e.kind {
	case kindList:
		if rv.Kind() != reflect.Slice || rv.IsNil() {
			return nil
		}
		out := make([]any, rv.Len())
		for i := range out {
			out[i] = toWalk(e.elem, rv.Index(i))
		}
		return out
	case kindDict:
		if rv.Kind() != reflect.Map || rv.IsNil() {
			return nil
		}
		out := make(map[string]any, rv.Len())
		for it := rv.MapRange(); it.Next(); {
			out[it.Key().String()] = toWalk(e.elem, it.Value())
		}
		return out
	case kindGroup:
		if rv.Kind() == reflect.Pointer {
			if rv.IsNil() {
				return nil
			}
			return walkedRow(typedValues(e.inner, rv.Interface()))
		}
		p := reflect.New(rv.Type())
		p.Elem().Set(rv)
		return walkedRow(typedValues(e.inner, p.Interface()))
	}
	v, _ := normalize(rv.Interface())
	return v
}

// fromWalk builds the value of type t that holds what unpack read for e.
func fromWalk(e *node, v any, t reflect.Type, reached map[reachKey]bool) reflect.Value {
	switch e.kind {
	case kindList:
		items := v.([]any)
		out := reflect.MakeSlice(t, len(items), len(items))
		for i, it := range items {
			out.Index(i).Set(fromWalk(e.elem, it, t.Elem(), reached))
		}
		return out
	case kindDict:
		entries := v.(map[string]any)
		out := reflect.MakeMapWithSize(t, len(entries))
		for k, it := range entries {
			out.SetMapIndex(reflect.ValueOf(k).Convert(t.Key()), fromWalk(e.elem, it, t.Elem(), reached))
		}
		return out
	case kindGroup:
		byPointer := t.Kind() == reflect.Pointer
		childType := t
		if byPointer {
			childType = t.Elem()
		}
		child := reflect.New(childType)
		fillRow(e.inner, child.Interface(), v.(map[string]any), reached)
		if byPointer {
			return child
		}
		return child.Elem()
	}
	return convertReflect(v, t)
}

// convertReflect converts an unpacked value to type t: a named type, or a pointer to one.
func convertReflect(v any, t reflect.Type) reflect.Value {
	rv := reflect.ValueOf(v)
	if t.Kind() == reflect.Pointer {
		p := reflect.New(t.Elem())
		p.Elem().Set(rv.Convert(t.Elem()))
		return p
	}
	return rv.Convert(t)
}
