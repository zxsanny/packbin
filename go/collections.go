package packbin

import "fmt"

// Utf8 is a string in the compact text format (contract compact-text 1.0.0): a varint payload size, then
// a payload of prefix codes in four modes (Ukrainian, Russian, English, number) or, when that is not
// smaller, raw UTF-8. The text is at most 65535 UTF-8 bytes. Its value is a string; pack refuses bytes
// that are not valid UTF-8 and unpack refuses a packet that holds them or a payload that breaks the format.
func Utf8(id int, name string) Field { return &node{kind: kindUtf8, id: id, name: name} }

// Nested is a nested row under name: its members are numbered from 0 and have references and names
// of their own, so they may repeat a name of the row around it. A map row gives it a map[string]any
// under its name (and unpack gives one); a typed row binds a struct or pointer to struct with Bind. It
// takes no id of the row around it. Under Flags or a flag bit it is one bit, set when it is given; with
// no members it is a mark like Bool. Unlike Group, it is also the element of a List or Dict.
func Nested(name string, members ...Field) Field {
	return &node{kind: kindGroup, nested: true, id: NoField, name: name, fields: nodesOf(members)}
}

// List is a u16 item count (at most 65535), then the items. The element is one field, a scope of its
// own with ids from 0: a scalar (U8 to I64, F32, F64, Bytes, Utf8, in which case its name is only used
// in messages), another List or Dict, a Nested, or a Flags (an item is then a row like a Nested's). The
// map form takes a []any (or any slice) of items, a Nested or Flags item a map[string]any; a typed row
// binds a []E with Bind. A List has no id. Unpack gives a []any of items.
func List(name string, element Field) Field { return collection(kindList, name, element) }

// Dict is a u16 pair count (at most 65535), then the pairs: a key (a text field as for Utf8) and
// an element as for List. Keys are written in byte order, so a map packs to the same bytes whatever its
// iteration order. The map form takes a map[string]any (or any map with string keys); a typed row binds a
// map[string]E with Bind. A key is a key, never a member of the row. Unpack gives a map[string]any.
func Dict(name string, element Field) Field { return collection(kindDict, name, element) }

func collection(k kind, name string, element Field) Field {
	e := nodeOf(element)
	n := &node{kind: k, id: NoField, name: name, elem: e}
	switch {
	case e == nil:
		n.err = fmt.Sprintf("%s %s: the element is nil", kindLabel(n), name)
	case e.kind == kindRepeat:
		if k == kindList {
			n.err = "list element must be one field"
		} else {
			n.err = "repeat is not a dictionary element"
		}
	case e.kind == kindFlags:
		// A flags element is a flag byte and its bits, not one field: it is held as a nested row of its
		// own, so it packs from and unpacks to one map (or struct) an item.
		n.elem = &node{kind: kindGroup, nested: true, id: NoField, fields: []*node{e}}
	case e.name == "" && (e.kind == kindInt || e.kind == kindFloat || e.kind == kindBytes || e.kind == kindUtf8):
		c := *e
		c.name = name
		n.elem = &c
	}
	return n
}

// elementScope is the fields an element's scope holds: a nested row's members, else the element.
func elementScope(e *node) []*node {
	if e.kind == kindGroup && e.nested {
		return e.fields
	}
	return []*node{e}
}

// checkElements refuses an element a list or dict cannot hold, at any depth. It runs after the
// references are bound, so an element that names a field of a scope it cannot see (a when, a times, a
// sized) is refused for that first.
func checkElements(nodes []*node) error {
	for _, n := range nodes {
		var err error
		switch n.kind {
		case kindList, kindDict:
			if err = checkElementKind(n); err == nil {
				err = checkElements([]*node{n.elem})
			}
		case kindWhen, kindFlags, kindGroup, kindRepeat, kindTimes:
			err = checkElements(n.fields)
		case kindFlagBit:
			err = checkElements([]*node{n.field})
		}
		if err != nil {
			return err
		}
	}
	return nil
}

func checkElementKind(c *node) error {
	e := c.elem
	switch e.kind {
	case kindInt, kindFloat, kindBytes, kindUtf8, kindList, kindDict:
		return nil
	case kindGroup:
		if e.nested {
			return nil
		}
		return schemeErr(NoField, c.name, "%s %s: element is an anchored group (%s); use a group without an anchor (Nested)",
			kindLabel(c), c.name, e.name)
	}
	return schemeErr(NoField, c.name, "%s %s: a %s cannot be an element; use a scalar, Utf8, List, Dict, Nested or Flags",
		kindLabel(c), c.name, kindLabel(e))
}

// leafElement is the element a chain of lists and dicts ends in.
func leafElement(n *node) *node {
	for n.kind == kindList || n.kind == kindDict {
		n = n.elem
	}
	return n
}

// rowPlace is the place of the row a group, round, list or dict holds: the group's or round's own
// members, or the members of the nested row a list or dict ends in. Nil for a leaf that is not a row.
func rowPlace(n *node) *place {
	return leafElement(n).inner
}
