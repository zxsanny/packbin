// Probe of AZ-4251: a `flags` that is a direct member of a `flags`. It builds scheme S of
// ../README.md, packs each shape's values and unpacks its own bytes. One line per shape: package,
// shape, build, pack, unpack (tab separated). It asserts nothing: it prints what happens.
//
// The scheme is unbound and the rows are map rows (map[string]any), read back with UnpackMap; a
// shape leaves a value out by leaving its key out. Ids: both Flags and x are 0, b is 1.
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

// shown is a row as text: keys in sorted order and every integer type as its number, so two rows
// that hold the same values print the same text whatever Go types hold them.
func shown(r row) string {
	keys := make([]string, 0, len(r))
	for key := range r {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	parts := make([]string, len(keys))
	for i, key := range keys {
		parts[i] = strconv.Quote(key) + ":" + scalar(r[key])
	}
	return "{" + strings.Join(parts, ",") + "}"
}

func scalar(value any) string {
	if value == nil {
		return "null"
	}
	v := reflect.ValueOf(value)
	switch v.Kind() {
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		return strconv.FormatInt(v.Int(), 10)
	case reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64:
		return strconv.FormatUint(v.Uint(), 10)
	}
	return fmt.Sprint(value)
}

// present is the row two rows are compared by: a member with no value (nil) is absent, and so is
// b = false, which leaves the bit clear as an absent b does (README §Bool).
func present(r row) string {
	kept := row{}
	for key, value := range r {
		if value == nil || (key == "b" && value == false) {
			continue
		}
		kept[key] = value
	}
	return shown(kept)
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

// build is S: flags(flags(u8 x), bool b).
func build() (*packbin.Scheme, error) {
	return packbin.NewScheme(1, packbin.Flags(0, packbin.Flags(0, packbin.U8(0, "x")), packbin.Bool(1, "b")))
}

func probe(shape string, values row) {
	b, p, u := "-", "-", "-"
	// The line is printed whatever happens. A panic of the package is caught where it is called and
	// becomes a cell. A panic that reaches here is the probe's own: the cells keep what is known, the
	// reason goes to stderr, the later shapes still run and the probe exits non-zero.
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
	case present(got) == present(values):
		u = "same"
	default:
		u = "differs: " + shown(got)
	}
}

func main() {
	probe("both", row{"x": 9, "b": true})
	probe("x-only", row{"x": 9})
	probe("b-only", row{"b": true})
	probe("none", row{})
	if failed {
		os.Exit(1)
	}
}
