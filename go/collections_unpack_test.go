package packbin

import (
	"math/rand"
	"testing"
)

func unpackRefused(t *testing.T, s *Scheme, wire string) *Error {
	t.Helper()
	row, err := Unpack(mustHex(t, wire), s)
	if row != nil {
		t.Fatalf("a row came back: %v", row)
	}
	return asError(t, err, ShortPacket)
}

// AC-2 (hostile, list-group-elements): packets a list or dict cannot read are errors with no row, and
// naming the list or dict.
func TestUnpackOfCollectionsRefusesWhatItCannotRead(t *testing.T) {
	xs := mustScheme(t, 1, List("xs", U8(0, "x")))
	zero := mustScheme(t, 1, List("xs", Bytes(0, "e", 0)))
	zeroInList := mustScheme(t, 1, List("outer", List("inner", Bytes(0, "e", 0))))
	zeroDict := mustScheme(t, 1, Dict("d", Bytes(0, "e", 0)))
	dict := mustScheme(t, 1, Dict("m", U8(0, "v")))
	cases := []struct {
		name         string
		scheme       *Scheme
		wire         string
		member       string
		needed, left int
	}{
		{"a list count of 65535 with no items", xs, "01ffff", "x", 1, 0},
		{"a list count of 3 with 2 items", xs, "0103000102", "x", 1, 0},
		{"no list count", xs, "01", "xs", 2, 0},
		{"half a list count", xs, "0101", "xs", 2, 1},
		{"a zero-width element", zero, "010500", "xs", 0, 0},
		{"a zero-width element of an inner list", zeroInList, "0101000500", "inner", 0, 0},
		{"a zero-width dict value", zeroDict, "010100021061", "d", 0, 0},
		{"a dict key given twice", dict, "0102000210610102106102", "m", 0, 0},
		{"a dict key that is not UTF-8", dict, "010100" + "0210ff" + "00", "m", 0, 4},
		{"a dict key cut short", dict, "010100031061", "m", 3, 2},
		{"a dict count of 65535 with no pairs", dict, "01ffff", "m", 1, 0},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Act
			e := unpackRefused(t, c.scheme, c.wire)

			// Assert
			if e.Name != c.member || e.Needed != c.needed || e.Left != c.left {
				t.Fatalf("got %+v", e)
			}
		})
	}
}

func TestUnpackOfCollectionsKeepsWhatItCanRead(t *testing.T) {
	zero := mustScheme(t, 1, List("xs", Bytes(0, "e", 0)))
	dict := mustScheme(t, 1, Dict("m", U8(0, "v")))
	if got := mustUnpackMap(t, zero, "010000"); len(got["xs"].([]any)) != 0 {
		t.Fatalf("got %#v", got)
	}
	if _, err := Unpack(mustHex(t, "0100000000"), dict); err == nil {
		t.Fatalf("trailing bytes were read")
	} else {
		asError(t, err, TrailingBytes)
	}
	if got := mustUnpackMap(t, dict, "010000"); len(got["m"].(map[string]any)) != 0 {
		t.Fatalf("got %#v", got)
	}
}

// No packet makes unpack panic, and no row packs into a panic: random bytes against schemes holding
// every kind, and random rows of odd values.
func TestCollectionsNeverPanic(t *testing.T) {
	schemes := []*Scheme{
		userScheme(t), nestedRingScheme(t), pairNested(t), dictPairNested(t), listFlagsScheme(t),
		mustScheme(t, 7, U8(0, "n"), List("xs", Nested("g", U8(0, "k"), Times(1, 0, Utf8(1, "s")), Dict("m", List("l", Be(U16(0, "v"))))))),
		mustScheme(t, 8, Repeat(0, Utf8(0, "s"), List("l", Utf8(0, "e")))),
	}
	rng := rand.New(rand.NewSource(1))
	for _, s := range schemes {
		for range 20000 {
			buf := make([]byte, rng.Intn(40))
			rng.Read(buf)
			if len(buf) > 0 {
				buf[0] = byte(s.TypeNumber())
			}
			if len(buf) > 2 && rng.Intn(2) == 0 {
				buf[1], buf[2] = byte(rng.Intn(3)), 0
			}
			if row, err := UnpackMap(buf, s); err == nil {
				if _, again := Pack(s, row); again != nil {
					t.Fatalf("a row that unpacked does not pack: %x %v", buf, again)
				}
			}
		}
	}
	odd := []any{nil, 5, "x", []any{nil}, []any{[]any{}}, map[string]any{"a": nil}, map[string]any{}, []map[string]any{nil},
		[]string{"a"}, map[string]any{"k": []any{map[string]any{}}}, (*int)(nil), [2]int{1, 2}, struct{}{}}
	for _, s := range schemes {
		for _, a := range odd {
			for _, b := range odd {
				_, _ = Pack(s, map[string]any{"username": a, "roles": b, "access": b, "access2": a, "pts": a, "m": b,
					"n": 1, "xs": a, "l": b, "s": a, "k": 2})
			}
		}
	}
}
