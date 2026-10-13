package packbin

import (
	"errors"
	"math"
	"testing"
)

type wideRow struct {
	A uint8
	B int
	C int64
}

func wideScheme(t testing.TB) *Scheme {
	return mustScheme(t, 1,
		Bind(U8(0, "a"), func(r *wideRow) uint8 { return r.A }, func(r *wideRow, v uint8) { r.A = v }),
		Bind(U16(1, "b"), func(r *wideRow) int { return r.B }, func(r *wideRow, v int) { r.B = v }),
		Bind(I8(2, "c"), func(r *wideRow) int64 { return r.C }, func(r *wideRow, v int64) { r.C = v }),
	)
}

// AC-5: a nil row, a nil map, a wrong Go type in a map and an out-of-range integer give a pack error
// naming the field id, nil bytes and no panic.
func TestAC5InvalidGoValues(t *testing.T) {
	var nilMap map[string]any
	var nilTyped *Position
	cases := []struct {
		name   string
		scheme *Scheme
		row    any
		id     int
	}{
		{"nil row", positionMapScheme(t), nil, 0},
		{"nil row typed scheme", positionTypedScheme(t), nil, 0},
		{"nil map", positionMapScheme(t), nilMap, 0},
		{"nil typed pointer", positionTypedScheme(t), nilTyped, 0},
		{"typed row for a map scheme", positionMapScheme(t), goldenRow(), 0},
		{"another row type", positionTypedScheme(t), &wideRow{}, 0},
		{"wrong type string", positionMapScheme(t), map[string]any{"sid": "1", "lat": 1, "lon": 1, "profile": 1}, 0},
		{"wrong type float for integer", positionMapScheme(t), map[string]any{"sid": 1, "lat": 1.5, "lon": 1, "profile": 1}, 1},
		{"wrong type bool for integer", positionMapScheme(t), map[string]any{"sid": 1, "lat": 1, "lon": true, "profile": 1}, 2},
		{"wrong type string for float", mustScheme(t, 1, F64(0, "x")), map[string]any{"x": "1.5"}, 0},
		{"wrong type for bytes", mustScheme(t, 1, Bytes(0, "b", 3)), map[string]any{"b": "abc"}, 0},
		{"bytes of another length", mustScheme(t, 1, Bytes(0, "b", 3)), map[string]any{"b": []byte("ab")}, 0},
		{"third field out of range", positionMapScheme(t), map[string]any{"sid": 1, "lat": 1, "lon": int64(math.MaxInt32) + 1, "profile": 1}, 2},
		{"flags member out of range", positionMapScheme(t), map[string]any{"sid": 1, "lat": 1, "lon": 1, "profile": 1, "speed": 256}, 5},
		{"missing value", positionMapScheme(t), map[string]any{"sid": 1, "lat": 1, "profile": 1}, 2},
		{"typed getter out of range", wideScheme(t), &wideRow{B: 70000}, 1},
		{"typed getter negative for unsigned", wideScheme(t), &wideRow{B: -1}, 1},
		{"typed getter out of i8", wideScheme(t), &wideRow{C: -129}, 2},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Act
			raw, err := Pack(c.scheme, c.row)

			// Assert
			e := asError(t, err, PackRefused)
			if raw != nil {
				t.Fatalf("bytes %x", raw)
			}
			if e.Field != c.id {
				t.Fatalf("field %d, want %d: %v", e.Field, c.id, e)
			}
			if !errors.Is(err, ErrPackRefused) {
				t.Fatalf("errors.Is: %v", err)
			}
		})
	}
}

func TestAC5RefusalTextNamesFieldAndValue(t *testing.T) {
	// Arrange
	s := mustScheme(t, 1, U8(0, "n"))

	cases := map[any]string{
		300:        "packbin: pack refused at field 0 (n): 300 does not fit in u8",
		-1:         "packbin: pack refused at field 0 (n): -1 does not fit in u8",
		"5":        "packbin: pack refused at field 0 (n): expected an integer for u8, got string",
		float64(5): "packbin: pack refused at field 0 (n): expected an integer for u8, got float64",
	}
	for v, want := range cases {
		// Act
		_, err := Pack(s, map[string]any{"n": v})

		// Assert
		if err == nil || err.Error() != want {
			t.Fatalf("%v: %v", v, err)
		}
	}
}

func TestPackNilSchemeIsRefused(t *testing.T) {
	// Act
	raw, err := Pack(nil, map[string]any{})

	// Assert
	if raw != nil || !errors.Is(err, ErrPackRefused) {
		t.Fatalf("raw %x err %v", raw, err)
	}
}

func TestTypedWiderMemberRoundTrips(t *testing.T) {
	// Arrange
	s := wideScheme(t)
	row := &wideRow{A: 255, B: 65535, C: -128}

	// Act
	wire := mustPack(t, s, row)
	back, err := Unpack(mustHex(t, wire), s)

	// Assert
	if wire != "01ffffff80" || err != nil || *back.(*wideRow) != *row {
		t.Fatalf("wire %s back %+v err %v", wire, back, err)
	}
}
