package main

import (
	"errors"
	"fmt"

	packbin "github.com/zxsanny/packbin/go"
)

func must(s *packbin.Scheme, err error) *packbin.Scheme {
	if err != nil {
		panic(err)
	}
	return s
}

func describeErr(err error) string {
	var e *packbin.Error
	if errors.As(err, &e) {
		return fmt.Sprintf("%T kind=%v needed=%d left=%d msg=%q", err, e.Kind, e.Needed, e.Left, err.Error())
	}
	return fmt.Sprintf("%T %q", err, err.Error())
}

func try(label string, s *packbin.Scheme, row map[string]any) {
	pk, err := packbin.Pack(s, row)
	if err != nil {
		fmt.Printf("%s: PACK ERR %s\n", label, describeErr(err))
		return
	}
	fmt.Printf("%s: PACK OK %x\n", label, pk)
	got, err := packbin.UnpackMap(pk, s)
	if err != nil {
		fmt.Printf("   UNPACK ERR %s\n", describeErr(err))
		return
	}
	fmt.Printf("   UNPACK OK %q\n", got)
}

func main() {
	ds := must(packbin.NewScheme(1, packbin.Dict("d", packbin.U8(0, "v"))))
	ss := must(packbin.NewScheme(1, packbin.Utf8(0, "s")))
	hi, lo, fffd, ff := "\xed\xa0\x80", "\xed\xb0\x80", "\xef\xbf\xbd", "\xff"
	d := func(kv ...any) map[string]any {
		m := map[string]any{}
		for i := 0; i < len(kv); i += 2 {
			m[kv[i].(string)] = uint8(kv[i+1].(int))
		}
		return map[string]any{"d": m}
	}
	try("A ED A0 80 + ED B0 80 keys", ds, d(hi, 1, lo, 2))
	try("B real U+FFFD + ED A0 80 keys", ds, d(fffd, 1, hi, 2))
	try("C ED A0 80 one key", ds, d(hi, 1))
	try("C' 0xFF one key", ds, d(ff, 1))
	try("C'' ED B0 80 one key", ds, d(lo, 1))
	try("D text ED A0 80", ss, map[string]any{"s": hi})
	try("D' text ED B0 80", ss, map[string]any{"s": lo})
	try("D'' text 0xFF", ss, map[string]any{"s": ff})
	try("ctl real U+FFFD one key", ds, d(fffd, 1))
	try("ctl real U+FFFD text", ss, map[string]any{"s": fffd})

	// Hand-made packets (not written by Go pack): the same bytes TypeScript used to write, and a raw invalid key.
	for _, c := range []struct{ label, hex string }{} {
		_ = c
	}
	raw := func(label string, b []byte) {
		got, err := packbin.UnpackMap(b, ds)
		if err != nil {
			fmt.Printf("hand-made %s: UNPACK ERR %s\n", label, describeErr(err))
			return
		}
		fmt.Printf("hand-made %s: UNPACK OK %q\n", label, got)
	}
	raw("TS case C 0101000410efbfbd01", []byte{1, 1, 0, 4, 0x10, 0xef, 0xbf, 0xbd, 1})
	raw("TS case A (repeated key)", []byte{1, 2, 0, 4, 0x10, 0xef, 0xbf, 0xbd, 1, 4, 0x10, 0xef, 0xbf, 0xbd, 2})
	raw("raw ED A0 80 key", []byte{1, 1, 0, 4, 0x10, 0xed, 0xa0, 0x80, 1})
}
