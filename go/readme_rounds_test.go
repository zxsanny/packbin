package packbin

import (
	"reflect"
	"testing"
)

// repack packs row, unpacks the wire as a map and packs that map again.
func repack(t testing.TB, s *Scheme, row any) (string, map[string]any, string) {
	t.Helper()
	wire := mustPack(t, s, row)
	back := mustUnpackMap(t, s, wire)
	return wire, back, mustPack(t, s, back)
}

// AC-1: the README data-type examples for repeat, sized, two-bit slots, bits, packed and times, in the
// map form: each packs to the README hex with 0 mismatched bytes, the hex unpacks, and the unpacked row
// packs to the same hex.
func TestAC1ReadmeRoundExamples(t *testing.T) {
	route := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, U8(0, "n"), Times(1, 0, I32(1, "lat"), I32(2, "lon")), U8(3, "tail"))
	}
	cases := []struct {
		name   string
		scheme func(t testing.TB) *Scheme
		row    map[string]any
		hex    string
	}{
		{"repeat two points", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Repeat(0, I32(0, "lat"), I32(1, "lon")))
		}, gm("lat", []any{10, 30}, "lon", []int32{20, 40}), "010a000000140000001e00000028000000"},
		{"repeat when", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Repeat(0, U8(0, "k"), When(1, Eq(0, 1), U8(1, "v"))))
		}, gm("k", []any{1, 2}, "v", []any{9}), "01010902"},
		{"sized uav", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, U16(0, "n"), Sized(1, "payload", 0))
		}, gm("n", 3, "payload", []byte("uav")), "010300756176"},
		{"u2 four slots", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, U2(Slot(0, "a"), Slot(1, "b"), Slot(2, "c"), Slot(3, "d")))
		}, gm("a", 0, "b", 1, "c", 2, "d", 3), "01e4"},
		{"u2 one slot", func(t testing.TB) *Scheme { return mustScheme(t, 1, U2(Slot(0, "a"))) }, gm("a", 1), "0101"},
		{"bits eight", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, U8(0, "n"), Bits(1, "segs", 0))
		}, gm("n", 8, "segs", []int{1, 1, 1, 1, 1, 1, 1, 1}), "0108ff"},
		{"bits nine", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, U8(0, "n"), Bits(1, "segs", 0))
		}, gm("n", 9, "segs", []int{1, 1, 1, 1, 1, 1, 1, 1, 1}), "0109ff01"},
		{"packed width 2", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, U8(0, "n"), Packed(2, 1, "kinds", 0, 0))
		}, gm("n", 4, "kinds", []int{0, 1, 2, 3}), "0104e4"},
		{"packed width 1 bias -1", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, U8(0, "n"), Packed(1, 1, "legs", 0, -1))
		}, gm("n", 9, "legs", []int{1, 1, 1, 1, 1, 1, 1, 1}), "0109ff"},
		{"packed count 1 bias -1 writes nothing", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, U8(0, "n"), Packed(1, 1, "legs", 0, -1))
		}, gm("n", 1, "legs", []int{}), "0101"},
		{"times then tail", route, gm("n", 2, "lat", []any{10, 30}, "lon", []any{20, 40}, "tail", 7),
			"01020a000000140000001e0000002800000007"},
		{"times lone scalar, count 0", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, U8(0, "a"), Times(1, 0, U8(1, "x")))
		}, gm("a", 0, "x", 5), "0100"},
		{"times flags short bool list", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, U8(0, "c"), Times(1, 0, Flags(1, Bool(1, "on"))))
		}, gm("c", 2, "on", []any{true}), "01020100"},
		{"times flags short u8 list", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, U8(0, "c"), Times(1, 0, Flags(1, U8(1, "v"))))
		}, gm("c", 2, "v", []any{5}), "0102010500"},
		{"repeat scalar to every round", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Repeat(0, U8(0, "x"), U8(1, "y")))
		}, gm("x", 1, "y", []any{4, 5}), "0101040105"},
		{"repeat flags scalar sets every bit", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Repeat(0, Flags(0, U8(0, "a")), U8(1, "b")))
		}, gm("a", 5, "b", []any{1, 2}), "01010501010502"},
		{"times scalar to every round", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, U8(0, "n"), Times(1, 0, U8(1, "x"), U8(2, "y")))
		}, gm("n", 2, "x", 1, "y", []any{4, 5}), "0102010401 05"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Arrange
			s := c.scheme(t)

			// Act
			raw, err := Pack(s, c.row)
			back, backErr := UnpackMap(mustHex(t, c.hex), s)

			// Assert
			if err != nil || backErr != nil {
				t.Fatalf("pack %v unpack %v", err, backErr)
			}
			if bad := mismatchedBytes(raw, mustHex(t, c.hex)); bad != 0 {
				t.Fatalf("got %x, %d mismatched bytes", raw, bad)
			}
			if again := mustPack(t, s, back); again != hexOf(mustHex(t, c.hex)) {
				t.Fatalf("repack of %v: %s", back, again)
			}
		})
	}
}

// AC-1: the README Flags rows of when, times and repeat as flags members.
func TestAC1ReadmeFlagsRoundMembers(t *testing.T) {
	when := mustScheme(t, 1, U8(0, "mode"), Flags(1, When(1, Eq(0, 1), U8(1, "speed")), U16(2, "heading")))
	times := mustScheme(t, 1, U8(0, "n"), Flags(1, Times(1, 0, U8(1, "pt")), U16(2, "heading")))
	repeat := mustScheme(t, 1, U8(0, "mode"), Flags(1, U16(1, "heading"), Repeat(2, U8(2, "pt"))))
	cases := []struct {
		s   *Scheme
		row map[string]any
		hex string
	}{
		{when, gm("mode", 1, "speed", 7, "heading", 90), "010103075a00"},
		{when, gm("mode", 0, "speed", 7, "heading", 90), "0100025a00"},
		{times, gm("n", 0, "pt", []any{}, "heading", 90), "0100025a00"},
		{times, gm("n", 1, "pt", []any{5}, "heading", 90), "010103055a00"},
		{times, gm("n", 2, "pt", []any{5, 6}, "heading", 90), "01020305065a00"},
		{repeat, gm("mode", 1, "heading", 90), "0101015a00"},
		{repeat, gm("mode", 1, "heading", 90, "pt", []any{5}), "0101035a0005"},
		{repeat, gm("mode", 1, "heading", 90, "pt", []any{5, 6}), "0101035a000506"},
	}
	for _, c := range cases {
		// Act
		wire := mustPack(t, c.s, c.row)

		// Assert
		if wire != c.hex {
			t.Errorf("%v: got %s, want %s", c.row, wire, c.hex)
		}
	}
}

// The route fixture of schema.md (borrowed-count): header, flags with a bool, a count, packed kinds,
// times pairs and a when on the bool holding packed(1) bias -1, unpacked and packed again.
func TestAC1RouteFixture(t *testing.T) {
	// Arrange
	const routeHex = "3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101"
	route := mustScheme(t, 0x34,
		U16(0, "sid"), U16(1, "name"),
		Flags(2, U16(2, "unit"), Bool(3, "straight"), U16(4, "routeId")),
		U8(5, "count"),
		Packed(2, 6, "kinds", 5, 0),
		Times(7, 5, I32(7, "lat"), I32(8, "lon")),
		When(9, Eq(3, true), Packed(1, 9, "mask", 5, -1)),
	)

	// Act
	back := mustUnpackMap(t, route, routeHex)
	again := mustPack(t, route, back)
	back["straight"] = false
	cleared := mustPack(t, route, back)
	_, shortErr := UnpackMap(mustHex(t, routeHex)[:24], route)

	// Assert
	want := gm("sid", uint16(16), "name", uint16(21), "straight", true, "routeId", uint16(45), "count", uint8(2),
		"kinds", []byte{1, 3}, "lat", []any{int32(500000000), int32(500010000)},
		"lon", []any{int32(300000000), int32(300010000)}, "mask", []byte{1})
	if again != routeHex {
		t.Fatalf("repack %s", again)
	}
	if got := mustUnpackMap(t, route, routeHex); !reflect.DeepEqual(got, want) {
		t.Fatalf("unpacked %v", got)
	}
	if cleared != "3410001500042d00020d0065cd1d00a3e111108ccd1d10cae111" {
		t.Fatalf("straight false: %s", cleared)
	}
	e := asError(t, shortErr, ShortPacket)
	if e.Name != "lon" || e.Needed != 4 || e.Left != 2 {
		t.Fatalf("short: %+v", e)
	}
}
