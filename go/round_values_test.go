package packbin

import (
	"reflect"
	"testing"
)

// The TypeScript round-values rows: round values are addressed by round index. A group in a round
// takes one map a round (Go-4), where TypeScript takes its members as flat lists.

func flagsRepeat(t testing.TB) *Scheme {
	return mustScheme(t, 1, Repeat(0, Flags(0, Bool(0, "on"), U8(1, "n"))))
}

func flagsTimes(t testing.TB) *Scheme {
	return mustScheme(t, 1, U8(0, "a"), Times(1, 0, Flags(1, Bool(1, "on"), U8(2, "n"))))
}

func whenRepeat(t testing.TB) *Scheme {
	return mustScheme(t, 1, Repeat(0, U8(0, "k"), When(1, Eq(0, 1), U8(1, "v"))))
}

func whenTimes(t testing.TB) *Scheme {
	return mustScheme(t, 1, U8(0, "a"), Times(1, 0, U8(1, "k"), When(2, Eq(1, 1), U8(2, "v"))))
}

func markRepeat(t testing.TB) *Scheme {
	return mustScheme(t, 1, Repeat(0, Flags(0, Group(0, "mark", U8(0, "v")))))
}

type packCase struct {
	name   string
	scheme func(t testing.TB) *Scheme
	row    map[string]any
	hex    string
}

// AC-2: rows that pack to the TypeScript hex, and whose unpacked row packs to the same hex.
func TestAC2RoundValuesPack(t *testing.T) {
	cases := []packCase{
		{"repeat flags by index", flagsRepeat, gm("on", []any{true, false, true}, "n", []any{1, 2, 3}), "01030102020303"},
		{"times flags by index", flagsTimes, gm("a", 3, "on", []any{true, false, true}, "n", []any{1, 2, 3}), "0103030102020303"},
		{"repeat only where the when holds", whenRepeat, gm("k", []any{1, 2}, "v", []any{9}), "01010902"},
		{"times only where the when holds", whenTimes, gm("a", 2, "k", []any{1, 2}, "v", []any{9}), "0102010902"},
		{"scalars make one round", whenRepeat, gm("k", 1, "v", 9), "010109"},
		{"scalar beside a list", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Repeat(0, U8(0, "k"), U8(1, "v")))
		}, gm("k", []any{1, 2}, "v", 9), "0101090209"},
		{"absent entry in the middle", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Repeat(0, U8(0, "x"), Flags(1, U8(1, "n"))))
		}, gm("x", []any{1, 2}, "n", []any{5, nil}), "010101050200"},
		{"longest list sets the count", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Repeat(0, Flags(0, U8(0, "a"), U8(1, "b"))))
		}, gm("a", []any{1, nil}, "b", []any{5, 6}), "010301050206"},
		{"group under flags per round", markRepeat, gm("mark", []any{gm("v", 7), nil, gm("v", 9)}), "010107000109"},
		{"group read at the round's index", markRepeat, gm("mark", []any{gm("v", 7), nil}), "01010700"},
		{"times group at the round's index", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, U8(0, "a"), Times(1, 0, Flags(1, Group(1, "mark", U8(1, "v")))))
		}, gm("a", 2, "mark", []any{gm("v", 7), nil}), "0102010700"},
		{"empty group under flags per round", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Repeat(0, Flags(0, Group(0, "mark"), U8(0, "n"))))
		}, gm("mark", []any{true, false, true}, "n", []any{1, 2, 3}), "01030102020303"},
		{"anchored group by round index", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Repeat(0, U8(0, "k"), Group(1, "mark", U8(1, "v"))))
		}, gm("k", []any{1, 2}, "mark", []any{gm("v", 7), gm("v", 8)}), "0101070208"},
		{"u2 slots by round index", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Repeat(0, U8(0, "k"), U2(Slot(1, "p"), Slot(2, "q"))))
		}, gm("k", []any{1, 2}, "p", []any{1, 2}, "q", []any{3, 0}), "01010d0202"},
		{"count read inside a round", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Repeat(0, U8(0, "n"), Sized(1, "p", 0)))
		}, gm("n", []any{2, 1}, "p", []any{[]byte{0xaa, 0xbb}, []byte{0xcc}}), "0102aabb01cc"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Act
			wire, _, again := repack(t, c.scheme(t), c.row)

			// Assert
			if wire != c.hex || again != c.hex {
				t.Fatalf("wire %s again %s, want %s", wire, again, c.hex)
			}
		})
	}
}

// AC-2: rows read from the wire: one entry a round, nil where the round skipped the name.
func TestAC2RoundValuesUnpack(t *testing.T) {
	u8s := func(v ...any) []any {
		out := make([]any, len(v))
		for i, x := range v {
			if x != nil {
				out[i] = uint8(x.(int))
			}
		}
		return out
	}
	cases := []struct {
		name   string
		scheme func(t testing.TB) *Scheme
		wire   string
		want   map[string]any
	}{
		{"bool is true or absent", flagsRepeat, "01030102020303", gm("on", []any{true, nil, true}, "n", u8s(1, 2, 3))},
		{"times bool is true or absent", flagsTimes, "0103030102020303",
			gm("a", uint8(3), "on", []any{true, nil, true}, "n", u8s(1, 2, 3))},
		{"skipped round keeps its place", whenRepeat, "01020109", gm("k", u8s(2, 1), "v", u8s(nil, 9))},
		{"no round set the value", whenRepeat, "010202", gm("k", u8s(2, 2), "v", u8s(nil, nil))},
		{"times skipped round keeps its place", whenTimes, "0102020109", gm("a", uint8(2), "k", u8s(2, 1), "v", u8s(nil, 9))},
		{"group per round", markRepeat, "010107000109",
			gm("mark", []any{gm("v", uint8(7)), nil, gm("v", uint8(9))})},
		{"times when values per round", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, U8(0, "a"), Times(1, 0, U8(1, "b"), When(2, Eq(1, 1), U8(2, "c"))))
		}, "01030107000109", gm("a", uint8(3), "b", u8s(1, 0, 1), "c", u8s(7, nil, 9))},
		{"repeat with no round", whenRepeat, "01", gm()},
		{"times count zero", whenTimes, "0100", gm("a", uint8(0))},
		{"name written twice in one round", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Repeat(0, U8(0, "k"), When(1, Eq(0, 1), U8(1, "v")), When(2, Eq(0, 1), U8(2, "v"))))
		}, "0101090a02", gm("k", u8s(1, 2), "v", u8s(10, nil))},
		{"round that reads nothing ends the repeat", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Repeat(0, Bytes(0, "v", 0)), U8(1, "tail"))
		}, "0105", gm("v", []any{[]byte{}}, "tail", uint8(5))},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Arrange
			s := c.scheme(t)

			// Act
			row := mustUnpackMap(t, s, c.wire)
			again := mustPack(t, s, row)

			// Assert
			if !reflect.DeepEqual(row, c.want) {
				t.Fatalf("got %#v", row)
			}
			// A repeat round that read nothing, or a name read twice in a round, is not a canonical packet.
			canonical := c.name != "round that reads nothing ends the repeat" && c.name != "name written twice in one round"
			if canonical && again != c.wire {
				t.Fatalf("repack %s", again)
			}
		})
	}
}

// AC-2: the refusals of round-values.
func TestAC2RoundValuesRefusals(t *testing.T) {
	cases := []struct {
		name   string
		scheme func(t testing.TB) *Scheme
		row    map[string]any
		field  int
		member string
	}{
		{"times count from the field, not the lists", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, U8(0, "a"), Times(1, 0, U8(1, "x")))
		}, gm("a", 3, "x", []any{1}), 1, "x"},
		{"a given group with its member missing", markRepeat, gm("mark", []any{gm()}), 0, "v"},
		{"a group given a bool", markRepeat, gm("mark", []any{true}), 0, "mark"},
		{"Go-4: a member list given flat beside no group", markRepeat, gm("v", []any{7}), 0, "v"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Act
			raw, err := Pack(c.scheme(t), c.row)

			// Assert
			e := asError(t, err, PackRefused)
			if raw != nil || e.Field != c.field || e.Name != c.member {
				t.Fatalf("raw %x err %v", raw, e)
			}
		})
	}
}

// AZ-2188: a repeat member named like an earlier scalar is a duplicate, not a join.
func TestAC2RoundMemberNamedLikeAScalarIsRefused(t *testing.T) {
	// Act
	s, err := NewScheme(1, U8(0, "x"), Repeat(1, U8(1, "x")))

	// Assert
	e := asError(t, err, InvalidScheme)
	if s != nil || e.Field != 1 || e.Name != "x" {
		t.Fatalf("err %v", e)
	}
}

// A when in a round reads only the round's own value, not a same-named one outside it; the round's
// list of that name joins the value outside, as in TypeScript.
func TestAC2RoundWhenReadsTheRoundsOwnValue(t *testing.T) {
	// Arrange
	s := mustScheme(t, 1, U8(0, "k"), Repeat(1, U8(1, "j"), When(2, Eq(1, 1), U8(2, "k")), When(3, Eq(2, 7), U8(3, "w"))))

	// Act
	row := mustUnpackMap(t, s, "0107000a")

	// Assert
	want := gm("k", []any{uint8(7), nil, nil}, "j", []any{uint8(0), uint8(10)}, "w", []any{nil, nil})
	if !reflect.DeepEqual(row, want) {
		t.Fatalf("got %#v", row)
	}
}
