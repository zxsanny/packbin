package packbin

import (
	"bytes"
	"reflect"
	"testing"
)

// AC-1: the golden row as a typed struct and as a map packs fixtures/golden.hex and unpacks back.
func TestAC1GoldenTyped(t *testing.T) {
	// Arrange
	s := positionTypedScheme(t)
	golden := mustHex(t, goldenHex(t))

	// Act
	raw, err := Pack(s, goldenRow())
	if err != nil {
		t.Fatal(err)
	}
	row, err := Unpack(golden, s)

	// Assert
	if err != nil {
		t.Fatal(err)
	}
	if got := mismatchedBytes(raw, golden); got != 0 {
		t.Fatalf("mismatched bytes %d: %x", got, raw)
	}
	if hexOf(raw) != expectedHex || len(raw) != 13 {
		t.Fatalf("got %x", raw)
	}
	p := row.(*Position)
	if !reflect.DeepEqual(p, goldenRow()) {
		t.Fatalf("got %+v", p)
	}
	if p.Heading != nil || p.Speed != nil || p.Altitude != nil {
		t.Fatalf("motion fields set: %+v", p)
	}
	byValue, err := Pack(s, *goldenRow())
	if err != nil || !bytes.Equal(byValue, raw) {
		t.Fatalf("a T row: %x, %v", byValue, err)
	}
}

func TestAC1GoldenMap(t *testing.T) {
	// Arrange
	golden := goldenHex(t)
	for _, s := range []*Scheme{positionMapScheme(t), positionTypedScheme(t)} {
		// Act
		wire := mustPack(t, s, goldenMap())
		back := mustUnpackMap(t, s, golden)

		// Assert
		if wire != golden {
			t.Fatalf("got %s", wire)
		}
		want := map[string]any{"sid": uint16(1), "lat": int32(500_000_000), "lon": int32(300_000_000), "profile": uint8(1)}
		if !reflect.DeepEqual(back, want) {
			t.Fatalf("got %#v", back)
		}
		if again := mustPack(t, s, back); again != golden {
			t.Fatalf("repack %s", again)
		}
	}
}

func TestAC1MapAndTypedUnpackAgree(t *testing.T) {
	// Arrange
	typed := positionTypedScheme(t)
	heading := uint16(90)
	row := goldenRow()
	row.Heading = &heading

	// Act
	wire := mustPack(t, typed, row)
	asMap := mustPack(t, positionMapScheme(t), map[string]any{
		"sid": 1, "lat": 500_000_000, "lon": 300_000_000, "profile": 1, "heading": 90,
	})
	back, err := Unpack(mustHex(t, wire), typed)

	// Assert
	if err != nil {
		t.Fatal(err)
	}
	if wire != "4001000065cd1d00a3e11101015a00" || asMap != wire {
		t.Fatalf("typed %s map %s", wire, asMap)
	}
	if got := back.(*Position); got.Heading == nil || *got.Heading != 90 || got.Speed != nil {
		t.Fatalf("got %+v", got)
	}
}

// AC-2: the README data-type examples give the README hex both ways.
func TestAC2ReadmeScalarExamples(t *testing.T) {
	cases := []struct {
		name   string
		fields []Field
		row    map[string]any
		wire   string
		back   map[string]any
	}{
		{"integers", []Field{U16(0, "n"), I16(1, "d")}, map[string]any{"n": 1, "d": -2}, "010100feff",
			map[string]any{"n": uint16(1), "d": int16(-2)}},
		{"floats", []Field{F32(0, "x")}, map[string]any{"x": 1.5}, "010000c03f",
			map[string]any{"x": float32(1.5)}},
		{"f64", []Field{F64(0, "x")}, map[string]any{"x": 1.5}, "01000000000000f83f",
			map[string]any{"x": 1.5}},
		{"fixed bytes", []Field{Bytes(0, "b", 3)}, map[string]any{"b": []byte("abc")}, "01616263",
			map[string]any{"b": []byte("abc")}},
		{"big-endian", []Field{Be(U16(0, "n"))}, map[string]any{"n": 1}, "010001",
			map[string]any{"n": uint16(1)}},
		{"flags", []Field{Flags(0, U16(0, "heading"), U8(1, "speed"))}, map[string]any{"heading": 90}, "01015a00",
			map[string]any{"heading": uint16(90)}},
		{"flags zero", []Field{Flags(0, U16(0, "heading"), U8(1, "speed"))}, map[string]any{"heading": 0}, "01010000",
			map[string]any{"heading": uint16(0)}},
		{"flags speed", []Field{Flags(0, U16(0, "heading"), U8(1, "speed"))}, map[string]any{"speed": 10}, "01020a",
			map[string]any{"speed": uint8(10)}},
		{"bool", []Field{Flags(0, Bool(0, "on"), U8(1, "n"))}, map[string]any{"on": true, "n": 7}, "010307",
			map[string]any{"on": true, "n": uint8(7)}},
		{"when", []Field{U8(0, "profile"), When(1, Eq(0, 0), U8(1, "shape"))}, map[string]any{"profile": 0, "shape": 9},
			"010009", map[string]any{"profile": uint8(0), "shape": uint8(9)}},
		{"when miss", []Field{U8(0, "profile"), When(1, Eq(0, 0), U8(1, "shape"))}, map[string]any{"profile": 1},
			"0101", map[string]any{"profile": uint8(1)}},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Arrange
			s := mustScheme(t, 1, c.fields...)

			// Act
			raw, err := Pack(s, c.row)
			if err != nil {
				t.Fatal(err)
			}
			back := mustUnpackMap(t, s, c.wire)

			// Assert
			if got := mismatchedBytes(raw, mustHex(t, c.wire)); got != 0 {
				t.Fatalf("pack %x, want %s", raw, c.wire)
			}
			if !reflect.DeepEqual(back, c.back) {
				t.Fatalf("unpack %#v, want %#v", back, c.back)
			}
			if again := mustPack(t, s, back); again != c.wire {
				t.Fatalf("repack %s", again)
			}
		})
	}
}

type readmeRow struct {
	N     uint16
	D     int16
	X     float32
	B     []byte
	On    bool
	Speed *uint8
}

// AC-2 in the typed form: the same README examples from a bound struct.
func TestAC2ReadmeTyped(t *testing.T) {
	// Arrange
	n := Bind(U16(0, "n"), func(r *readmeRow) uint16 { return r.N }, func(r *readmeRow, v uint16) { r.N = v })
	d := Bind(I16(1, "d"), func(r *readmeRow) int16 { return r.D }, func(r *readmeRow, v int16) { r.D = v })
	x := Bind(F32(0, "x"), func(r *readmeRow) float32 { return r.X }, func(r *readmeRow, v float32) { r.X = v })
	b := Bind(Bytes(0, "b", 3), func(r *readmeRow) []byte { return r.B }, func(r *readmeRow, v []byte) { r.B = v })
	on := Bind(Bool(0, "on"), func(r *readmeRow) bool { return r.On }, func(r *readmeRow, v bool) { r.On = v })
	speed := Bind(U8(1, "n"), func(r *readmeRow) *uint8 { return r.Speed }, func(r *readmeRow, v *uint8) { r.Speed = v })
	seven := uint8(7)
	cases := []struct {
		scheme *Scheme
		row    readmeRow
		wire   string
	}{
		{mustScheme(t, 1, n, d), readmeRow{N: 1, D: -2}, "010100feff"},
		{mustScheme(t, 1, x), readmeRow{X: 1.5}, "010000c03f"},
		{mustScheme(t, 1, b), readmeRow{B: []byte("abc")}, "01616263"},
		{mustScheme(t, 1, Be(n)), readmeRow{N: 1}, "010001"},
		{mustScheme(t, 1, Flags(0, on, speed)), readmeRow{On: true, Speed: &seven}, "010307"},
	}
	for _, c := range cases {
		// Act
		wire := mustPack(t, c.scheme, &c.row)
		back, err := Unpack(mustHex(t, c.wire), c.scheme)

		// Assert
		if err != nil {
			t.Fatal(err)
		}
		if wire != c.wire {
			t.Fatalf("pack %s, want %s", wire, c.wire)
		}
		if !reflect.DeepEqual(back, &c.row) {
			t.Fatalf("unpack %+v, want %+v", back, c.row)
		}
	}
}
