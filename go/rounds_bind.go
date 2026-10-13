package packbin

import "reflect"

func isStructOrPointer(t reflect.Type) bool {
	return t.Kind() == reflect.Struct || (t.Kind() == reflect.Pointer && t.Elem().Kind() == reflect.Struct)
}

// bindRoundRows makes the accessor of a repeat or times read and store its rounds as a slice V of a
// struct E or of a *E: one element a round, each read and made as a *E. A nil slice is no value; an
// empty slice is 0 rounds.
func bindRoundRows[V any](acc *accessor, t reflect.Type, get func(row any) V, set func(row any, v V)) {
	elem := t.Elem()
	byPointer := elem.Kind() == reflect.Pointer
	acc.childType = elem
	if byPointer {
		acc.childType = elem.Elem()
	}
	acc.newChild = func() any { return reflect.New(acc.childType).Interface() }
	acc.get = func(row any) (any, bool) {
		v := get(row)
		rv := reflect.ValueOf(&v).Elem()
		return v, !rv.IsNil()
	}
	acc.roundRows = func(v any) []any {
		rv := reflect.ValueOf(v)
		rows := make([]any, rv.Len())
		for i := range rows {
			e := rv.Index(i)
			switch {
			case !byPointer:
				p := reflect.New(acc.childType)
				p.Elem().Set(e)
				rows[i] = p.Interface()
			case !e.IsNil():
				rows[i] = e.Interface()
			}
		}
		return rows
	}
	acc.setRounds = func(row any, rows []any) {
		out := reflect.MakeSlice(t, len(rows), len(rows))
		for i, r := range rows {
			p := reflect.ValueOf(r)
			if byPointer {
				out.Index(i).Set(p)
			} else {
				out.Index(i).Set(p.Elem())
			}
		}
		var v V
		reflect.ValueOf(&v).Elem().Set(out)
		set(row, v)
	}
}
