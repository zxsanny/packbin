// Probe of AZ-4206: a repeat that is not the last thing a packet reads. It builds each shape of
// ../README.md, packs the values given there and unpacks its own bytes. One line per shape:
// package, shape, build, pack, unpack (tab separated). It asserts nothing: it prints what happens.
//
// The schemes are unbound and the rows are map rows (map[string]any), read back with UnpackMap:
//   - the rounds of a Repeat are one list per name, entry i for round i ("v": []any{5, 6});
//   - a Nested row is a map under its name, and the item of a List or Dict of Nested rows is a map;
//   - a Nested numbers its members from 0 and takes no id of the row around it.
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

// oneLine turns whitespace runs (a tab or a line break too) into one space, so a message stays in
// its field.
func oneLine(text string) string {
	return strings.Join(strings.Fields(text), " ")
}

// shown is a value as text: map keys in sorted order and every integer type as its number, so two
// rows that hold the same values print the same text whatever Go types hold them.
func shown(value any) string {
	if value == nil {
		return "null"
	}
	v := reflect.ValueOf(value)
	switch v.Kind() {
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

// roundNames are the names the rounds of a repeat hold in the shapes of this probe.
var roundNames = map[string]bool{"v": true, "w": true}

// withoutEmptyRounds is value without the round lists that hold no entry, at any depth. It is used on
// both sides of the comparison only, never on what is packed or printed: for a repeat that read no
// round UnpackMap gives no key, where the row given holds an empty list, and the two are the same
// rounds.
func withoutEmptyRounds(value any) any {
	switch v := value.(type) {
	case map[string]any:
		kept := make(map[string]any, len(v))
		for name, member := range v {
			if list, isList := member.([]any); isList && len(list) == 0 && roundNames[name] {
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

// caught runs step; a panic comes back as its message. The package says it never panics.
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

func probe(shape string, build func() (*packbin.Scheme, error), values row) {
	b, p, u := "-", "-", "-"
	// The line is printed whatever happens. A panic of the package is caught where it is called and
	// becomes a cell. A panic that reaches here is the probe's own (comparing or printing what came
	// back): the cells keep what is known, the reason goes to stderr, the later shapes still run and
	// the probe exits non-zero after its last line.
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
		b = "refused: panic: " + message
		return
	}
	if err != nil {
		b = "refused: " + oneLine(err.Error())
		return
	}
	b = "built"

	var packed []byte
	if message, panicked := caught(func() { packed, err = packbin.Pack(scheme, values) }); panicked {
		p = "refused: panic: " + message
		return
	}
	if err != nil {
		p = "refused: " + oneLine(err.Error())
		return
	}
	p = hex.EncodeToString(packed)

	var got row
	if message, panicked := caught(func() { got, err = packbin.UnpackMap(packed, scheme) }); panicked {
		u = "threw: " + message
		return
	}
	switch {
	case err != nil:
		u = "refused: " + oneLine(err.Error())
	case shown(withoutEmptyRounds(got)) == shown(withoutEmptyRounds(values)):
		u = "same"
	default:
		u = "differs: " + shown(got)
	}
}

func main() {
	// control: the repeat is the last thing read.
	probe("control", func() (*packbin.Scheme, error) {
		return packbin.NewScheme(1, packbin.U8(0, "x"), packbin.Repeat(1, packbin.U8(1, "v")))
	}, row{"x": 9, "v": []any{5, 6}})

	// a: a field after a repeat, top level.
	probe("a", func() (*packbin.Scheme, error) {
		return packbin.NewScheme(1, packbin.Repeat(0, packbin.U8(0, "v")), packbin.U8(1, "x"))
	}, row{"v": []any{5, 6}, "x": 9})

	// b: a repeat inside a list element row (a Nested), two items.
	probe("b", func() (*packbin.Scheme, error) {
		return packbin.NewScheme(1, packbin.List("items",
			packbin.Nested("item", packbin.U8(0, "mode"), packbin.Repeat(1, packbin.U8(1, "v")))))
	}, row{"items": []any{row{"mode": 1, "v": []any{5}}, row{"mode": 2, "v": []any{}}}})

	// c: a repeat inside a dict element row (a Nested), two entries.
	probe("c", func() (*packbin.Scheme, error) {
		return packbin.NewScheme(1, packbin.Dict("d",
			packbin.Nested("item", packbin.U8(0, "mode"), packbin.Repeat(1, packbin.U8(1, "v")))))
	}, row{"d": row{"a": row{"mode": 1, "v": []any{5}}, "b": row{"mode": 2, "v": []any{}}}})

	// d: a repeat inside a nested row, then a field. The field is id 0: the Nested takes no id.
	probe("d", func() (*packbin.Scheme, error) {
		return packbin.NewScheme(1, packbin.Nested("m", packbin.Repeat(0, packbin.U8(0, "v"))), packbin.U8(0, "x"))
	}, row{"m": row{"v": []any{5, 6}}, "x": 9})

	// e-when: a repeat under a when that is taken, then a field.
	probe("e-when", func() (*packbin.Scheme, error) {
		return packbin.NewScheme(1, packbin.U8(0, "k"),
			packbin.When(1, packbin.Eq(0, 1), packbin.Repeat(1, packbin.U8(1, "v"))), packbin.U8(2, "x"))
	}, row{"k": 1, "v": []any{5, 6}, "x": 9})

	// e-flags: a repeat under flags, then a field.
	probe("e-flags", func() (*packbin.Scheme, error) {
		return packbin.NewScheme(1, packbin.Flags(0, packbin.Repeat(0, packbin.U8(0, "v"))), packbin.U8(1, "x"))
	}, row{"v": []any{5, 6}, "x": 9})

	// f: a repeat after a repeat, one round each.
	probe("f", func() (*packbin.Scheme, error) {
		return packbin.NewScheme(1, packbin.Repeat(0, packbin.U8(0, "v")), packbin.Repeat(1, packbin.U8(1, "w")))
	}, row{"v": []any{5}, "w": []any{6}})

	if failed {
		os.Exit(1)
	}
}
