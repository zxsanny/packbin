package packbin

import (
	"testing"
)

type namedBytes []byte
type namedFlag bool
type namedFloat float32

// Every builtin pointer a map row or a getter can give reads through; nil is no value.
func TestNormalizeReadsPointersAndNamedTypes(t *testing.T) {
	// Arrange
	u8, u16, u32, u64, u := uint8(1), uint16(2), uint32(3), uint64(4), uint(5)
	i8, i16, i32, i64, i := int8(-1), int16(-2), int32(-3), int64(-4), -5
	f32, f64, b := float32(1.5), 2.5, true
	var nilU16 *uint16
	var nilMap map[string]int
	var nilFunc func()
	var nilSlice []int
	present := []struct {
		in   any
		want any
	}{
		{&u8, u8}, {&u16, u16}, {&u32, u32}, {&u64, u64}, {&u, u}, {&i8, i8}, {&i16, i16}, {&i32, i32},
		{&i64, i64}, {&i, i}, {&f32, f32}, {&f64, f64}, {&b, b},
		{namedLevel(7), uint64(7)}, {namedFlag(true), true}, {namedFloat(1.5), float32(1.5)},
		{int16Named(-3), int64(-3)}, {float64Named(2), float64(2)},
	}
	absent := []any{nil, nilU16, nilMap, nilFunc, nilSlice, namedBytes(nil), []byte(nil), (*namedLevel)(nil)}

	for _, c := range present {
		// Act
		got, ok := normalize(c.in)

		// Assert
		if !ok || got != c.want {
			t.Fatalf("%T: %#v %v, want %#v", c.in, got, ok, c.want)
		}
	}
	for _, in := range absent {
		if got, ok := normalize(in); ok {
			t.Fatalf("%T: %#v is a value", in, got)
		}
	}
	if got, ok := normalize(namedBytes{1, 2}); !ok || string(got.([]byte)) != "\x01\x02" {
		t.Fatalf("named bytes: %#v", got)
	}
}

type int16Named int16
type float64Named float64

func TestErrorTextPerKind(t *testing.T) {
	cases := map[string]*Error{
		"packbin: short packet: needed 1, left 0":            {Kind: ShortPacket, Field: NoField, Needed: 1},
		"packbin: short packet at m: needed 1, left 0":       {Kind: ShortPacket, Field: NoField, Name: "m", Needed: 1},
		"packbin: short packet at field 4: needed 1, left 0": {Kind: ShortPacket, Field: 4, Needed: 1},
		"packbin: 2 trailing bytes":                          {Kind: TrailingBytes, Field: NoField, Left: 2},
		"packbin: unknown type number 9":                     {Kind: UnknownType, Field: NoField, Actual: 9},
		"packbin: bad value at field 1 (n): negative count":  {Kind: BadValue, Field: 1, Name: "n", Reason: "negative count"},
		"packbin: invalid scheme: duplicate type number 1":   {Kind: InvalidScheme, Field: NoField, Reason: "duplicate type number 1"},
		"packbin: pack refused at field 0 (a): missing a":    {Kind: PackRefused, Field: 0, Name: "a", Reason: "missing a"},
		"packbin: kind(99) at field 0: x":                    {Kind: Kind(99), Field: 0, Reason: "x"},
	}
	for want, e := range cases {
		// Act
		got := e.Error()

		// Assert
		if got != want {
			t.Fatalf("got %q, want %q", got, want)
		}
	}
}
