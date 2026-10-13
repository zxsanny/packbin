package packbin

import (
	"reflect"
	"testing"
)

const (
	userHex   = "0107007a7873616e6e7902000400757365720a0064697370617463686572030007006368616e6e656c010004007265616403006d6170040004007265616407006770735f6669780300736574040065646974050073746f7265020004007265616405007772697465"
	nestedHex = "01020003006d61700100010002006f7007006770735f666978050073746f72650200010002006f70040072656164010002006f7005007772697465"
)

func userScheme(t testing.TB) *Scheme {
	return mustScheme(t, 1, Utf8(0, "username"), List("roles", Utf8(0, "role")),
		Dict("access", List("actions", Utf8(0, "action"))))
}

func nestedRingScheme(t testing.TB) *Scheme {
	return mustScheme(t, 1, Dict("access", List("rows", Dict("row", Utf8(0, "op")))))
}

func pairNested(t testing.TB) *Scheme {
	return mustScheme(t, 1, List("pts", Nested("p", U8(0, "a"), U8(1, "b"))))
}

func dictPairNested(t testing.TB) *Scheme {
	return mustScheme(t, 1, Dict("m", Nested("p", U8(0, "a"), U8(1, "b"))))
}

func listFlagsScheme(t testing.TB) *Scheme {
	return mustScheme(t, 1, List("pts", Flags(0, U8(0, "a"), U16(1, "b"))))
}

// AC-1: the README UTF-8, list and dictionary examples pack to the README hex and unpack back; the
// unpacked row packs to the same hex.
func TestAC1ReadmeCollectionExamples(t *testing.T) {
	cases := []struct {
		name   string
		scheme func(t testing.TB) *Scheme
		row    map[string]any
		hex    string
		back   map[string]any
	}{
		{"utf8 zxsanny", func(t testing.TB) *Scheme { return mustScheme(t, 1, Utf8(0, "name")) },
			gm("name", "zxsanny"), "0107007a7873616e6e79", gm("name", "zxsanny")},
		{"utf8 empty", func(t testing.TB) *Scheme { return mustScheme(t, 1, Utf8(0, "name")) },
			gm("name", ""), "010000", gm("name", "")},
		{"list of u16", func(t testing.TB) *Scheme { return mustScheme(t, 1, List("xs", U16(0, "x"))) },
			gm("xs", []any{1, 2}), "01020001000200", gm("xs", []any{uint16(1), uint16(2)})},
		{"list empty", func(t testing.TB) *Scheme { return mustScheme(t, 1, List("xs", U16(0, "x"))) },
			gm("xs", []int{}), "010000", gm("xs", []any{})},
		{"dict of u8, keys in byte order", func(t testing.TB) *Scheme { return mustScheme(t, 1, Dict("m", U8(0, "v"))) },
			gm("m", map[string]any{"b": 1, "a": 2}), "0102000100610201006201",
			gm("m", map[string]any{"a": uint8(2), "b": uint8(1)})},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Arrange
			s := c.scheme(t)

			// Act
			wire, back, again := repack(t, s, c.row)

			// Assert
			if wire != c.hex || again != c.hex || mismatchedBytes(mustHex(t, wire), mustHex(t, c.hex)) != 0 {
				t.Fatalf("wire %s again %s, want %s", wire, again, c.hex)
			}
			if !reflect.DeepEqual(back, c.back) {
				t.Fatalf("back %#v, want %#v", back, c.back)
			}
		})
	}
}

// AC-4: the language-pair.sh ring payloads of the collection kinds pack and unpack to the same hex.
func TestAC4RingPayloadsRoundTrip(t *testing.T) {
	cases := []struct {
		name   string
		scheme func(t testing.TB) *Scheme
		row    map[string]any
		hex    string
	}{
		{"user", userScheme, gm("username", "zxsanny", "roles", []string{"user", "dispatcher"}, "access", map[string][]string{
			"channel": {"read"}, "map": {"read", "gps_fix", "set", "edit"}, "store": {"read", "write"},
		}), userHex},
		{"nested", nestedRingScheme, gm("access", map[string]any{
			"map":   []any{map[string]any{"op": "gps_fix"}},
			"store": []map[string]string{{"op": "read"}, {"op": "write"}},
		}), nestedHex},
		{"listgroup", pairNested, gm("pts", []any{gm("a", 1, "b", 2), gm("a", 3, "b", 4)}), "01020001020304"},
		{"dictgroup", dictPairNested, gm("m", map[string]any{"y": gm("a", 3, "b", 4), "x": gm("a", 1, "b", 2)}),
			"01020001007801020100790304"},
		{"listflags", listFlagsScheme, gm("pts", []any{gm("a", 1), gm(), gm("b", 2)}), "010300010100020200"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Arrange
			s := c.scheme(t)

			// Act
			packed := mustPack(t, s, c.row)
			again := mustPack(t, s, mustUnpackMap(t, s, c.hex))

			// Assert
			if packed != c.hex || again != c.hex {
				t.Fatalf("packed %s, repacked %s, want %s", packed, again, c.hex)
			}
		})
	}
}

// AC-4: a collection packet whose last element is cut short is refused with no row, naming the field.
func TestAC4ShortRingPayloadsAreRefused(t *testing.T) {
	cases := []struct {
		name   string
		scheme func(t testing.TB) *Scheme
		hex    string
		field  int
		member string
		needed int
		left   int
	}{
		{"listgroup", pairNested, "010200010203", 1, "b", 1, 0},
		{"dictgroup", dictPairNested, "010200010078010201007903", 1, "b", 1, 0},
		{"listflags", listFlagsScheme, "0103000101000202", 1, "b", 2, 1},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Arrange
			s := c.scheme(t)

			// Act
			row, err := Unpack(mustHex(t, c.hex), s)
			asMap, mapErr := UnpackMap(mustHex(t, c.hex), s)

			// Assert
			e := asError(t, err, ShortPacket)
			if row != nil || asMap != nil || mapErr == nil {
				t.Fatalf("a row came back: %v %v", row, asMap)
			}
			if e.Field != c.field || e.Name != c.member || e.Needed != c.needed || e.Left != c.left {
				t.Fatalf("got %+v", e)
			}
		})
	}
}
