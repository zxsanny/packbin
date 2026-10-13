package packbin

import (
	"math"
	"testing"
)

func single(t testing.TB, kind string) *Scheme {
	ctor := map[string]func(int, string) Field{
		"u8": U8, "u16": U16, "u32": U32, "u64": U64, "i8": I8, "i16": I16, "i32": I32, "i64": I64,
		"f32": F32, "f64": F64,
	}[kind]
	return mustScheme(t, 1, ctor(0, "a"))
}

// Ported from typescript/tests/int-range.test.ts: a value out of its field's range is refused,
// naming the field.
func TestIntegerOutOfRangeIsRefused(t *testing.T) {
	rows := []struct {
		kind  string
		value any
	}{
		{"u8", 300}, {"u8", -1}, {"i8", 200}, {"i8", -129}, {"u16", 65536}, {"i16", -32769}, {"i16", 32768},
		{"u32", int64(1) << 32}, {"u32", -1}, {"i32", int64(3_000_000_000)}, {"i32", int64(-2147483649)},
		{"i64", uint64(1) << 63}, {"u64", int64(-1)}, {"u64", math.MinInt64},
		// A float is not an integer in Go, whole or not (TypeScript's 1e300 and the infinities).
		{"u8", 1e300}, {"u8", math.Inf(1)}, {"u8", math.Inf(-1)}, {"u8", 1.7}, {"u8", math.NaN()},
		{"u8", true}, {"u8", "5"}, {"i64", 1.5}, {"u64", "5"},
	}
	for _, r := range rows {
		// Act
		raw, err := Pack(single(t, r.kind), map[string]any{"a": r.value})

		// Assert
		e := asError(t, err, PackRefused)
		if raw != nil || e.Field != 0 || e.Name != "a" {
			t.Fatalf("%s %v: raw %x err %v", r.kind, r.value, raw, e)
		}
	}
}

func TestIntegerRangeEdgesPack(t *testing.T) {
	rows := []struct {
		kind  string
		value any
		wire  string
	}{
		{"u8", 0, "0100"}, {"u8", 255, "01ff"}, {"i8", -128, "0180"}, {"i8", 127, "017f"},
		{"u16", 65535, "01ffff"}, {"i16", -32768, "010080"}, {"u32", uint32(4294967295), "01ffffffff"},
		{"i32", int32(-2147483648), "0100000080"}, {"u64", uint64(math.MaxUint64), "01ffffffffffffffff"},
		{"i64", int64(math.MinInt64), "010000000000000080"}, {"i64", int64(math.MaxInt64), "01ffffffffffffff7f"},
		{"u8", uint64(5), "0105"}, {"u64", 1<<53 - 1, "01ffffffffffff1f00"}, {"i64", -(1<<53 - 1), "01010000000000e0ff"},
		// TypeScript refuses these as numbers past 2^53 and takes them as bigints; a Go integer is exact.
		{"u64", 1 << 60, "010000000000000010"}, {"u64", 1<<53 + 1, "010100000000002000"},
	}
	for _, r := range rows {
		// Act
		wire := mustPack(t, single(t, r.kind), map[string]any{"a": r.value})

		// Assert
		if wire != r.wire {
			t.Fatalf("%s %v: %s, want %s", r.kind, r.value, wire, r.wire)
		}
	}
}

func TestBigEndianFieldsAreCheckedAndKeepTheirOrder(t *testing.T) {
	// Arrange
	u16be := mustScheme(t, 1, Be(U16(0, "a")))
	i32be := mustScheme(t, 1, Be(I32(0, "a")))

	// Act
	wire := mustPack(t, u16be, map[string]any{"a": 0x1234})
	_, tooBig := Pack(u16be, map[string]any{"a": 65536})
	_, signed := Pack(i32be, map[string]any{"a": int64(1) << 31})
	back := mustUnpackMap(t, i32be, "01fffffffe")

	// Assert
	if wire != "011234" {
		t.Fatalf("got %s", wire)
	}
	asError(t, tooBig, PackRefused)
	asError(t, signed, PackRefused)
	if back["a"] != int32(-2) {
		t.Fatalf("got %v", back)
	}
}

func TestEveryContainerPositionIsChecked(t *testing.T) {
	// Arrange
	inWhen := mustScheme(t, 1, U8(0, "k"), When(1, Eq(0, 1), U8(1, "a")))
	inFlags := mustScheme(t, 1, Flags(0, U8(0, "a")))

	// Act
	_, whenErr := Pack(inWhen, map[string]any{"k": 1, "a": 256})
	_, flagsErr := Pack(inFlags, map[string]any{"a": -1})

	// Assert
	if e := asError(t, whenErr, PackRefused); e.Field != 1 {
		t.Fatalf("got %v", e)
	}
	if e := asError(t, flagsErr, PackRefused); e.Field != 0 {
		t.Fatalf("got %v", e)
	}
}

func TestFloatRange(t *testing.T) {
	// Arrange
	f32 := single(t, "f32")
	f64 := single(t, "f64")

	// Act and assert: a finite value too large for f32 is refused; the specials are written as given.
	for _, v := range []float64{1e39, -1e39, f32Overflow} {
		_, err := Pack(f32, map[string]any{"a": v})
		asError(t, err, PackRefused)
	}
	for _, r := range []struct {
		scheme *Scheme
		value  any
		wire   string
	}{
		{f32, math.Inf(1), "010000807f"}, {f32, math.Inf(-1), "01000080ff"}, {f32, math.NaN(), "010000c07f"},
		{f32, 3.4028234663852886e38, "01ffff7f7f"}, {f32, float32(1.5), "010000c03f"}, {f32, 2, "0100000040"},
		{f64, 1.5, "01000000000000f83f"}, {f64, 1e300, "019c7500883ce4377e"},
	} {
		if wire := mustPack(t, r.scheme, map[string]any{"a": r.value}); wire != r.wire {
			t.Fatalf("%v: %s, want %s", r.value, wire, r.wire)
		}
	}
	for _, v := range []any{"1.5", true, []byte{1}} {
		_, err := Pack(f64, map[string]any{"a": v})
		asError(t, err, PackRefused)
	}
}

func TestUnpackedRowsPackAgain(t *testing.T) {
	// Arrange
	ints := mustScheme(t, 1, U64(0, "big"), I64(1, "neg"), U32(2, "mid"))
	floats := mustScheme(t, 1, F32(0, "s"), F64(1, "d"))

	for _, c := range []struct {
		scheme *Scheme
		row    map[string]any
	}{
		{ints, map[string]any{"big": uint64(1) << 60, "neg": -5, "mid": uint32(4294967295)}},
		{floats, map[string]any{"s": 1.5, "d": math.NaN()}},
	} {
		// Act
		first := mustPack(t, c.scheme, c.row)
		back := mustUnpackMap(t, c.scheme, first)
		again := mustPack(t, c.scheme, back)

		// Assert
		if again != first {
			t.Fatalf("%s repacks as %s", first, again)
		}
	}
	if back := mustUnpackMap(t, ints, mustPack(t, ints, map[string]any{"big": 1, "neg": -5, "mid": 7})); back["big"] != uint64(1) || back["neg"] != int64(-5) {
		t.Fatalf("got %#v", back)
	}
}

type namedLevel uint8

func TestNamedIntegerTypesAndPointersInMaps(t *testing.T) {
	// Arrange
	s := single(t, "u8")
	level := namedLevel(200)

	// Act
	byValue := mustPack(t, s, map[string]any{"a": level})
	byPointer := mustPack(t, s, map[string]any{"a": &level})

	// Assert
	if byValue != "01c8" || byPointer != "01c8" {
		t.Fatalf("value %s pointer %s", byValue, byPointer)
	}
}
