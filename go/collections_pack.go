package packbin

import (
	"reflect"
	"slices"
	"unicode/utf8"
)

// maxCollection is the most items a list or dict can hold: a u16.
const maxCollection = 65535

// walkedRow is a nested row that a typed row already turned into the values the walker reads.
type walkedRow map[string]any

// writeString writes the compact text field of s: a count, then the payload (text_encode.go). A text
// that comes again and again (a lone string under Times or Repeat) is copied from where it was last
// written, not parsed again.
func (p *packer) writeString(id int, name, s string) error {
	if len(s) > maxTextBytes {
		return packErr(id, name, "%s: utf-8 length %d, above %d", name, len(s), maxTextBytes)
	}
	if !utf8.ValidString(s) {
		return packErr(id, name, "%s: the string is not valid UTF-8", name)
	}
	if s == "" {
		if err := p.room(id, name, 1); err != nil {
			return err
		}
		p.out = append(p.out, 0)
		return nil
	}
	if p.lastLen > 0 && s == p.lastText {
		if err := p.room(id, name, p.lastLen); err != nil {
			return err
		}
		p.out = append(p.out, p.out[p.lastAt:p.lastAt+p.lastLen]...)
		return nil
	}
	var scratch [65 * 8]int32
	plan, costs := planText(s, scratch[:])
	if err := p.room(id, name, plan.size()); err != nil {
		return err
	}
	p.lastText, p.lastAt, p.lastLen = s, len(p.out), plan.size()
	p.out = appendTextField(p.out, s, plan, costs)
	return nil
}

// collection packs a list or dict f from v, its value: a u16 count, then the items (a dict's in key
// byte order, each after its key).
func (p *packer) collection(f *node, v any) error {
	if f.kind == kindList {
		items, ok := roundList(v) // a []byte is a byte run, never a list
		if !ok {
			return packErr(NoField, f.name, "%s: expected a list, got %s", f.name, describe(v))
		}
		if err := p.count(f, len(items)); err != nil {
			return err
		}
		for _, it := range items {
			if err := p.item(f, it); err != nil {
				return err
			}
		}
		return nil
	}
	entries, ok := dictEntries(v)
	if !ok {
		return packErr(NoField, f.name, "%s: expected a dictionary, got %s", f.name, describe(v))
	}
	if err := p.count(f, len(entries)); err != nil {
		return err
	}
	keys := make([]string, 0, len(entries))
	for k := range entries {
		keys = append(keys, k)
	}
	slices.Sort(keys)
	for _, k := range keys {
		if err := p.writeString(NoField, f.name, k); err != nil {
			return err
		}
		if err := p.item(f, entries[k]); err != nil {
			return err
		}
	}
	return nil
}

func (p *packer) count(f *node, n int) error {
	if n > maxCollection {
		return packErr(NoField, f.name, "%s: length %d, above %d", f.name, n, maxCollection)
	}
	if err := p.room(NoField, f.name, 2); err != nil {
		return err
	}
	p.out = append(p.out, byte(n), byte(n>>8))
	return nil
}

// item packs one element of list or dict f.
func (p *packer) item(f *node, item any) error {
	e := f.elem
	v, ok := normalize(item)
	if !ok {
		return packErr(e.id, f.name, "%s: an item has no value", f.name)
	}
	switch e.kind {
	case kindGroup:
		sub, err := p.itemRow(f, e, v)
		if err != nil {
			return err
		}
		return p.nestedRow(e, sub)
	case kindList, kindDict:
		return p.collection(e, v)
	}
	return p.writeValue(e, v)
}

// itemRow is the values of a nested row element: a map the row gave (read as a group's map is) or one
// a typed row made.
func (p *packer) itemRow(f, e *node, v any) (map[string]any, error) {
	switch m := v.(type) {
	case walkedRow:
		return m, nil
	case map[string]any:
		return mapValues(e.inner, m)
	}
	return nil, packErr(NoField, f.name, "%s: expected a map[string]any for each item, got %s", f.name, typeName(v))
}

// nestedRow packs the members of a nested row from sub, in a scope of its own.
func (p *packer) nestedRow(g *node, sub map[string]any) error {
	saved := p.scope
	p.scope = sub
	err := p.fields(g.fields, scopeRoot{g.fields, sub}, sub, map[string]any{})
	p.scope = saved
	return err
}

// dictEntries is a dict value as a map keyed by string: a map[string]any, or any map with string keys.
func dictEntries(v any) (map[string]any, bool) {
	if m, ok := v.(map[string]any); ok {
		return m, m != nil
	}
	rv := reflect.ValueOf(v)
	if v == nil || rv.Kind() != reflect.Map || rv.Type().Key().Kind() != reflect.String || rv.IsNil() {
		return nil, false
	}
	out := make(map[string]any, rv.Len())
	for it := rv.MapRange(); it.Next(); {
		out[it.Key().String()] = it.Value().Interface()
	}
	return out, true
}
