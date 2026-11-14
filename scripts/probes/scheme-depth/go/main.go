// Probe of AZ-4291: how deep may a scheme be nested. Usage: depthprobe <when|group> <depth>.
// Prints one tab-separated line: package, shape-with-depth, build, pack, unpack. It asserts nothing.
//
// Form used: unbound schemes and map rows (map[string]any), read back with UnpackMap, as in
// scripts/probes/repeat-followed-by-field/go. The group shape is the Nested row (a group without an anchor,
// whose member is a map under "m"); a typed row would need a struct per level. The scheme and the values are
// built in loops, innermost first, so the probe never recurses; the comparison of the result is a loop too.
//
// A package error value is "refused"; a panic that the program can recover is "threw: panic". Go's stack
// overflow ("goroutine stack exceeds ...") is fatal and cannot be recovered: the run.sh line says `crashed`.
// No debug.SetMaxStack and no bigger goroutine: the default behaviour is the finding.
package main

import (
	"encoding/hex"
	"fmt"
	"os"
	"strconv"
	"strings"

	packbin "github.com/zxsanny/packbin/go"
)

type row = map[string]any

func oneLine(text string) string {
	return strings.Join(strings.Fields(text), " ")
}

func cut(text string) string {
	if len(text) > 120 {
		return text[:120]
	}
	return text
}

func shownHex(b []byte) string {
	all := hex.EncodeToString(b)
	if len(all) > 80 {
		return all[:40] + "...(" + strconv.Itoa(len(b)) + " bytes)"
	}
	return all
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

func whenScheme(depth int) (*packbin.Scheme, error) {
	inner := packbin.U8(1, "b")
	for i := 0; i < depth; i++ {
		inner = packbin.When(1, packbin.Eq(0, 1), inner)
	}
	return packbin.NewScheme(1, packbin.U8(0, "a"), inner)
}

func groupScheme(depth int) (*packbin.Scheme, error) {
	inner := packbin.U8(0, "b")
	for i := 0; i < depth; i++ {
		inner = packbin.Nested("m", inner)
	}
	return packbin.NewScheme(1, inner)
}

func groupValues(depth int) row {
	inner := row{"b": 7}
	for i := 0; i < depth; i++ {
		inner = row{"m": inner}
	}
	return inner
}

func compareGroups(got row, depth int) string {
	var current any = got
	for i := 0; i < depth; i++ {
		m, ok := current.(map[string]any)
		if !ok || len(m) != 1 || m["m"] == nil {
			return "level " + strconv.Itoa(i) + " is " + cut(fmt.Sprint(current))
		}
		current = m["m"]
	}
	m, ok := current.(map[string]any)
	if !ok || len(m) != 1 || fmt.Sprint(m["b"]) != "7" {
		return "innermost is " + cut(fmt.Sprint(current))
	}
	return ""
}

func compareWhen(got row) string {
	if len(got) == 2 && fmt.Sprint(got["a"]) == "1" && fmt.Sprint(got["b"]) == "7" {
		return ""
	}
	return fmt.Sprint(got)
}

func main() {
	shape := os.Args[1]
	depth, err := strconv.Atoi(os.Args[2])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	b, p, u := "-", "-", "-"
	defer func() { fmt.Println(strings.Join([]string{"go", shape + "-" + os.Args[2], b, p, u}, "\t")) }()

	var scheme *packbin.Scheme
	var values row
	if message, panicked := caught(func() {
		if shape == "when" {
			scheme, err = whenScheme(depth)
			values = row{"a": 1, "b": 7}
		} else {
			scheme, err = groupScheme(depth)
			values = groupValues(depth)
		}
	}); panicked {
		b = "threw: panic: " + cut(message)
		return
	}
	if err != nil {
		b = "refused: " + cut(oneLine(err.Error()))
		return
	}
	b = "built"

	var packed []byte
	if message, panicked := caught(func() { packed, err = packbin.Pack(scheme, values) }); panicked {
		p = "threw: panic: " + cut(message)
		return
	}
	if err != nil {
		p = "refused: " + cut(oneLine(err.Error()))
		return
	}
	p = shownHex(packed)

	var got row
	if message, panicked := caught(func() { got, err = packbin.UnpackMap(packed, scheme) }); panicked {
		u = "threw: panic: " + cut(message)
		return
	}
	if err != nil {
		u = "refused: " + cut(oneLine(err.Error()))
		return
	}
	diff := ""
	if shape == "when" {
		diff = compareWhen(got)
	} else {
		diff = compareGroups(got, depth)
	}
	if diff == "" {
		u = "same"
	} else {
		u = "differs: " + cut(oneLine(diff))
	}
}
