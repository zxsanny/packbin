// Probe of AZ-4242: a list or dict whose element is a row of required members (a Nested element, no
// flag byte per element). It builds each shape of ../README.md, packs the values given there and
// unpacks its own bytes. One line per shape: package, shape, build, pack, unpack (tab separated). It
// asserts nothing: it prints what happens.
//
// Forms. A plain shape name is the typed form: every member is bound with Bind to a struct, the scheme
// packs a *T and Unpack gives a *T back. A shape with the suffix -map is the map form of the same
// scheme (no Bind; a map[string]any row, read back with UnpackMap): pack reads it on another path
// (mapValues, not toWalk), so its outcome can differ. other-row and nested-other-row exist only in the
// typed form: a map row has no row type.
//
// Collection types. Bind takes any Go type at compile time (Bind[T, V any]); the package checks the
// member type V when the scheme is built, so a coll-* line of a type it does not take is a `refused:`
// build, not a compile error. The map form takes any slice for a list and any map with string keys for a
// dict, each item a map[string]any.
//
// `refused:` is an error the package returned; `threw: panic:` is a panic the probe recovered (the
// package says it never panics).
package main

import (
	"encoding/hex"
	"fmt"
	"os"
	"reflect"
	"sort"
	"strconv"
	"strings"

	packbin "github.com/zxsanny/packbin/go"
)

type row = map[string]any

// oneLine turns whitespace runs (a tab or a line break too) into one space, so a message stays in its
// field.
func oneLine(text string) string {
	return strings.Join(strings.Fields(text), " ")
}

// shown is a value as text: map keys and struct fields in sorted order, a pointer as what it points at,
// every integer type as its number, and a nil slice as an empty one, so two rows that hold the same
// values print the same text whatever Go types hold them.
func shown(value any) string {
	if value == nil {
		return "null"
	}
	v := reflect.ValueOf(value)
	switch v.Kind() {
	case reflect.Pointer, reflect.Interface:
		if v.IsNil() {
			return "null"
		}
		return shown(v.Elem().Interface())
	case reflect.Struct:
		names := make([]string, v.NumField())
		members := map[string]string{}
		for i := range names {
			names[i] = v.Type().Field(i).Name
			members[names[i]] = shown(v.Field(i).Interface())
		}
		sort.Strings(names)
		parts := make([]string, len(names))
		for i, name := range names {
			parts[i] = strconv.Quote(name) + ":" + members[name]
		}
		return "{" + strings.Join(parts, ",") + "}"
	case reflect.Map:
		keys := make([]string, 0, v.Len())
		members := map[string]string{}
		for _, key := range v.MapKeys() {
			name := fmt.Sprint(key.Interface())
			keys = append(keys, name)
			members[name] = shown(v.MapIndex(key).Interface())
		}
		sort.Strings(keys)
		parts := make([]string, len(keys))
		for i, name := range keys {
			parts[i] = strconv.Quote(name) + ":" + members[name]
		}
		return "{" + strings.Join(parts, ",") + "}"
	case reflect.Slice, reflect.Array:
		parts := make([]string, v.Len())
		for i := range parts {
			parts[i] = shown(v.Index(i).Interface())
		}
		return "[" + strings.Join(parts, ",") + "]"
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		return strconv.FormatInt(v.Int(), 10)
	case reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64:
		return strconv.FormatUint(v.Uint(), 10)
	case reflect.String:
		return strconv.Quote(v.String())
	}
	return fmt.Sprint(value)
}

// withoutEmptyRounds is a map row without the round lists ("v") that hold no entry, at any depth. Used
// on both sides of a map-form comparison only: UnpackMap gives a times that read no round no key.
func withoutEmptyRounds(value any) any {
	switch v := value.(type) {
	case map[string]any:
		kept := make(map[string]any, len(v))
		for name, member := range v {
			if list, isList := member.([]any); isList && len(list) == 0 && name == "v" {
				continue
			}
			kept[name] = withoutEmptyRounds(member)
		}
		return kept
	case []any:
		kept := make([]any, len(v))
		for i, item := range v {
			kept[i] = withoutEmptyRounds(item)
		}
		return kept
	}
	return value
}

// caught runs step; a panic comes back as its message.
func caught(step func()) (message string, panicked bool) {
	defer func() {
		if r := recover(); r != nil {
			message, panicked = oneLine(fmt.Sprint(r)), true
		}
	}()
	step()
	return "", false
}

// failed is set when the probe's own code panicked: the run failed, whatever its lines say.
var failed bool

// probe prints one line. values is a *T for the typed form or a map row for the map form; the typed
// form is read back with Unpack, the map form with UnpackMap.
func probe(shape string, build func() (*packbin.Scheme, error), values any) {
	b, p, u := "-", "-", "-"
	// A panic of the package is caught where it is called and becomes a cell. One that reaches here is
	// the probe's own: the cells keep what is known, the reason goes to stderr, and the probe exits
	// non-zero after its last line.
	defer func() {
		if r := recover(); r != nil {
			fmt.Fprintf(os.Stderr, "go %s: the probe panicked: %v\n", shape, r)
			failed = true
		}
		fmt.Println(strings.Join([]string{"go", shape, b, p, u}, "\t"))
	}()

	var scheme *packbin.Scheme
	var err error
	if message, panicked := caught(func() { scheme, err = build() }); panicked {
		b = "threw: panic: " + message
		return
	}
	if err != nil {
		b = "refused: " + oneLine(err.Error())
		return
	}
	b = "built"

	var packed []byte
	if message, panicked := caught(func() { packed, err = packbin.Pack(scheme, values) }); panicked {
		p = "threw: panic: " + message
		return
	}
	if err != nil {
		p = "refused: " + oneLine(err.Error())
		return
	}
	p = hex.EncodeToString(packed)

	mapForm := false
	if _, isMap := values.(row); isMap {
		mapForm = true
	}
	var got any
	if message, panicked := caught(func() {
		if mapForm {
			got, err = packbin.UnpackMap(packed, scheme)
		} else {
			got, err = packbin.Unpack(packed, scheme)
		}
	}); panicked {
		u = "threw: panic: " + message
		return
	}
	switch {
	case err != nil:
		u = "refused: " + oneLine(err.Error())
	case mapForm && shown(withoutEmptyRounds(got)) == shown(withoutEmptyRounds(values)):
		u = "same"
	case !mapForm && shown(got) == shown(values):
		u = "same"
	default:
		u = "differs: " + shown(got)
	}
}

// The element row of AZ-4199: four required members, ids 0 to 3.
type comment struct {
	ID       string
	Text     string
	AuthorID uint32
	Author   string
}

// commentOpt is comment whose text may be absent (nil): the typed null-member shape.
type commentOpt struct {
	ID       string
	Text     *string
	AuthorID uint32
	Author   string
}

// other is a row type that is not the element's: the other-row shapes bind a member to it.
type other struct{ Text string }

// otherComment is another row type with comment's members: the -whole shapes bind every member to it.
type otherComment comment

// holder is the typed row of a scheme with one list or dict member of type V.
type holder[V any] struct{ Items V }

// note is the typed row of nested-other-row: one nested row.
type note struct{ Note comment }

type modeRow struct {
	Mode  uint8
	Speed *uint8
}

type vRound struct{ V uint8 }

type countRow struct {
	C uint8
	V []vRound
}

type commentList []comment
type commentMap map[string]comment
type key string
type rowMap map[string]any

func utf8Of[R any](id int, name string, get func(*R) string, set func(*R, string)) packbin.Field {
	return packbin.Bind(packbin.Utf8(id, name), get, set)
}

// commentMembers are the members of comment, bound to comment; with textToOther the text is bound to
// other instead.
func commentMembers(textToOther bool) []packbin.Field {
	text := utf8Of(1, "text", func(r *comment) string { return r.Text }, func(r *comment, v string) { r.Text = v })
	if textToOther {
		text = utf8Of(1, "text", func(r *other) string { return r.Text }, func(r *other, v string) { r.Text = v })
	}
	return []packbin.Field{
		utf8Of(0, "id", func(r *comment) string { return r.ID }, func(r *comment, v string) { r.ID = v }),
		text,
		packbin.Bind(packbin.U32(2, "authorId"), func(r *comment) uint32 { return r.AuthorID },
			func(r *comment, v uint32) { r.AuthorID = v }),
		utf8Of(3, "author", func(r *comment) string { return r.Author }, func(r *comment, v string) { r.Author = v }),
	}
}

func otherMembers() []packbin.Field {
	return []packbin.Field{
		utf8Of(0, "id", func(r *otherComment) string { return r.ID }, func(r *otherComment, v string) { r.ID = v }),
		utf8Of(1, "text", func(r *otherComment) string { return r.Text }, func(r *otherComment, v string) { r.Text = v }),
		packbin.Bind(packbin.U32(2, "authorId"), func(r *otherComment) uint32 { return r.AuthorID },
			func(r *otherComment, v uint32) { r.AuthorID = v }),
		utf8Of(3, "author", func(r *otherComment) string { return r.Author }, func(r *otherComment, v string) { r.Author = v }),
	}
}

func commentOptMembers() []packbin.Field {
	return []packbin.Field{
		utf8Of(0, "id", func(r *commentOpt) string { return r.ID }, func(r *commentOpt, v string) { r.ID = v }),
		packbin.Bind(packbin.Utf8(1, "text"), func(r *commentOpt) *string { return r.Text },
			func(r *commentOpt, v *string) { r.Text = v }),
		packbin.Bind(packbin.U32(2, "authorId"), func(r *commentOpt) uint32 { return r.AuthorID },
			func(r *commentOpt, v uint32) { r.AuthorID = v }),
		utf8Of(3, "author", func(r *commentOpt) string { return r.Author }, func(r *commentOpt, v string) { r.Author = v }),
	}
}

func plainComment() []packbin.Field {
	return []packbin.Field{packbin.Utf8(0, "id"), packbin.Utf8(1, "text"), packbin.U32(2, "authorId"), packbin.Utf8(3, "author")}
}

// typed is a scheme of one list (or dict) of a Nested element, bound to holder[V].Items.
func typed[V any](collection func(string, packbin.Field) packbin.Field, members func() []packbin.Field) func() (*packbin.Scheme, error) {
	return func() (*packbin.Scheme, error) {
		return packbin.NewScheme(1, packbin.Bind(collection("items", packbin.Nested("item", members()...)),
			func(r *holder[V]) V { return r.Items }, func(r *holder[V], v V) { r.Items = v }))
	}
}

// unbound is the map-form scheme of one list (or dict) "items" of a Nested element.
func unbound(collection func(string, packbin.Field) packbin.Field, members func() []packbin.Field) func() (*packbin.Scheme, error) {
	return func() (*packbin.Scheme, error) {
		return packbin.NewScheme(1, collection("items", packbin.Nested("item", members()...)))
	}
}

func main() {
	c1 := comment{ID: "c1", Text: "hi", AuthorID: 7, Author: "ann"}
	c2 := comment{ID: "c2", Text: "ok", AuthorID: 258, Author: "bo"}
	c3 := comment{ID: "c3", Text: "yes", AuthorID: 1, Author: "cy"}
	m1 := row{"id": "c1", "text": "hi", "authorId": 7, "author": "ann"}
	m2 := row{"id": "c2", "text": "ok", "authorId": 258, "author": "bo"}
	m3 := row{"id": "c3", "text": "yes", "authorId": 1, "author": "cy"}
	members := func() []packbin.Field { return commentMembers(false) }
	list, dict := packbin.List, packbin.Dict

	probe("list-0", typed[[]comment](list, members), &holder[[]comment]{Items: []comment{}})
	probe("list-1", typed[[]comment](list, members), &holder[[]comment]{Items: []comment{c1}})
	probe("list-3", typed[[]comment](list, members), &holder[[]comment]{Items: []comment{c1, c2, c3}})
	probe("dict-2", typed[map[string]comment](dict, members),
		&holder[map[string]comment]{Items: map[string]comment{"b": c2, "a": c1}})
	probe("list-3-map", unbound(list, plainComment), row{"items": []any{m1, m2, m3}})
	probe("dict-2-map", unbound(dict, plainComment), row{"items": row{"b": m2, "a": m1}})

	// Other list member types (typed form): Bind checks V when the scheme is built.
	probe("coll-pointer-elements", typed[[]*comment](list, members), &holder[[]*comment]{Items: []*comment{&c1, &c2, &c3}})
	probe("coll-named-slice", typed[commentList](list, members), &holder[commentList]{Items: commentList{c1, c2, c3}})
	probe("coll-array", typed[[3]comment](list, members), &holder[[3]comment]{Items: [3]comment{c1, c2, c3}})
	probe("coll-pointer-to-slice", typed[*[]comment](list, members), &holder[*[]comment]{Items: &[]comment{c1, c2, c3}})
	probe("coll-interface-elements", typed[[]any](list, members), &holder[[]any]{Items: []any{c1, c2, c3}})
	probe("coll-interface-member", typed[any](list, members), &holder[any]{Items: []comment{c1, c2, c3}})
	// Other dict member types (typed form).
	probe("coll-dict-pointer-elements", typed[map[string]*comment](dict, members),
		&holder[map[string]*comment]{Items: map[string]*comment{"b": &c2, "a": &c1}})
	probe("coll-dict-named-map", typed[commentMap](dict, members), &holder[commentMap]{Items: commentMap{"b": c2, "a": c1}})
	probe("coll-dict-named-key", typed[map[key]comment](dict, members),
		&holder[map[key]comment]{Items: map[key]comment{"b": c2, "a": c1}})
	probe("coll-dict-int-key", typed[map[int]comment](dict, members), &holder[map[int]comment]{Items: map[int]comment{2: c2, 1: c1}})
	// Other collection types (map form): any slice, any map with string keys, each item a map[string]any.
	probe("coll-typed-slice-map", unbound(list, plainComment), row{"items": []row{m1, m2, m3}})
	probe("coll-array-map", unbound(list, plainComment), row{"items": [3]any{m1, m2, m3}})
	probe("coll-named-item-map", unbound(list, plainComment), row{"items": []any{rowMap(m1), rowMap(m2), rowMap(m3)}})
	probe("coll-struct-item-map", unbound(list, plainComment), row{"items": []any{c1, c2, c3}})
	probe("coll-dict-typed-map", unbound(dict, plainComment), row{"items": map[string]row{"b": m2, "a": m1}})
	probe("coll-dict-named-key-map", unbound(dict, plainComment), row{"items": map[key]any{"b": m2, "a": m1}})
	probe("coll-dict-int-key-map", unbound(dict, plainComment), row{"items": map[int]any{2: m2, 1: m1}})

	// when inside an element row: speed is written only for mode 1.
	seven := uint8(7)
	probe("when", typed[[]modeRow](list, func() []packbin.Field {
		return []packbin.Field{
			packbin.Bind(packbin.U8(0, "mode"), func(r *modeRow) uint8 { return r.Mode }, func(r *modeRow, v uint8) { r.Mode = v }),
			packbin.When(1, packbin.Eq(0, 1), packbin.Bind(packbin.U8(1, "speed"),
				func(r *modeRow) *uint8 { return r.Speed }, func(r *modeRow, v *uint8) { r.Speed = v })),
		}
	}), &holder[[]modeRow]{Items: []modeRow{{Mode: 1, Speed: &seven}, {Mode: 0}}})
	probe("when-map", unbound(list, func() []packbin.Field {
		return []packbin.Field{packbin.U8(0, "mode"), packbin.When(1, packbin.Eq(0, 1), packbin.U8(1, "speed"))}
	}), row{"items": []any{row{"mode": 1, "speed": 7}, row{"mode": 0}}})

	// times inside an element row: c rounds of v.
	probe("times", typed[[]countRow](list, func() []packbin.Field {
		return []packbin.Field{
			packbin.Bind(packbin.U8(0, "c"), func(r *countRow) uint8 { return r.C }, func(r *countRow, v uint8) { r.C = v }),
			packbin.Bind(packbin.Times(1, 0, packbin.Bind(packbin.U8(1, "v"),
				func(r *vRound) uint8 { return r.V }, func(r *vRound, v uint8) { r.V = v })),
				func(r *countRow) []vRound { return r.V }, func(r *countRow, v []vRound) { r.V = v }),
		}
	}), &holder[[]countRow]{Items: []countRow{{C: 2, V: []vRound{{5}, {6}}}, {C: 0, V: []vRound{}}}})
	probe("times-map", unbound(list, func() []packbin.Field {
		return []packbin.Field{packbin.U8(0, "c"), packbin.Times(1, 0, packbin.U8(1, "v"))}
	}), row{"items": []any{row{"c": 2, "v": []any{5, 6}}, row{"c": 0, "v": []any{}}}})

	// other-row: the element is a []comment, its text member is bound to other.
	probe("other-row", typed[[]comment](list, func() []packbin.Field { return commentMembers(true) }),
		&holder[[]comment]{Items: []comment{c1}})
	// nested-other-row: a nested row (Nested at the top level) bound to comment, its text bound to other.
	probe("nested-other-row", func() (*packbin.Scheme, error) {
		return packbin.NewScheme(1, packbin.Bind(packbin.Nested("note", commentMembers(true)...),
			func(r *note) comment { return r.Note }, func(r *note, v comment) { r.Note = v }))
	}, &note{Note: c1})
	// -whole: every member of the element row (nested row) is bound to otherComment, so the row is one
	// type and only its owner's type differs: another check (checkGroupBindings) than one stray member.
	probe("other-row-whole", typed[[]comment](list, otherMembers), &holder[[]comment]{Items: []comment{c1}})
	probe("nested-other-row-whole", func() (*packbin.Scheme, error) {
		return packbin.NewScheme(1, packbin.Bind(packbin.Nested("note", otherMembers()...),
			func(r *note) comment { return r.Note }, func(r *note, v comment) { r.Note = v }))
	}, &note{Note: c1})

	// null-member: a required member left out (a nil *string in the typed form, no key in the map form).
	probe("null-member", typed[[]commentOpt](list, commentOptMembers),
		&holder[[]commentOpt]{Items: []commentOpt{{ID: "c1", AuthorID: 7, Author: "ann"}}})
	probe("null-member-map", unbound(list, plainComment), row{"items": []any{row{"id": "c1", "authorId": 7, "author": "ann"}}})

	// null-item: a list that holds c1 and a nil element (the typed form needs pointer elements).
	probe("null-item", typed[[]*comment](list, members), &holder[[]*comment]{Items: []*comment{&c1, nil}})
	probe("null-item-map", unbound(list, plainComment), row{"items": []any{m1, nil}})

	if failed {
		os.Exit(1)
	}
}
