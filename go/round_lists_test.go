package packbin

import (
	"strings"
	"testing"
)

type refusalCase struct {
	name   string
	scheme func(t testing.TB) *Scheme
	row    map[string]any
	field  int
	member string
	reason string // a part of the reason, or ""
}

func runRefusals(t *testing.T, cases []refusalCase) {
	t.Helper()
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Act
			raw, err := Pack(c.scheme(t), c.row)

			// Assert
			e := asError(t, err, PackRefused)
			if raw != nil || e.Field != c.field || e.Name != c.member || !strings.Contains(e.Reason, c.reason) {
				t.Fatalf("raw %x err %v", raw, e)
			}
		})
	}
}

func runPacks(t *testing.T, cases []packCase) {
	t.Helper()
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Act
			wire := mustPack(t, c.scheme(t), c.row)

			// Assert
			if wire != c.hex {
				t.Fatalf("got %s, want %s", wire, c.hex)
			}
		})
	}
}

func optionalU8(t testing.TB) *Scheme {
	return mustScheme(t, 1, Repeat(0, U8(0, "w"), Flags(1, U8(1, "v"))))
}

// AC-2 (repeat-short-optional, U3): a non-empty list shorter than the rounds of a repeat, under a
// member a flag bit can leave absent, is refused naming the member. A group is one name of the round
// in Go, so its short list is named by the group (TypeScript names its member).
func TestAC2RepeatShortOptionalListIsRefused(t *testing.T) {
	split := func(t testing.TB) *Scheme {
		fb := FlagByte("m")
		return mustScheme(t, 1, Repeat(0, U8(0, "w"), fb, fb.Bit(U8(1, "v"))))
	}
	grouped := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, Repeat(0, U8(0, "w"), Flags(1, Group(1, "g", U8(1, "v")))))
	}
	runRefusals(t, []refusalCase{
		{"U3 row", optionalU8, gm("w", []any{1, 2}, "v", []any{5}), 1, "v", "v: 1 items, repeat count 2; give one entry per round"},
		{"three rounds two entries", optionalU8, gm("w", []any{1, 2, 3}, "v", []any{5, nil}), 1, "v", "2 items, repeat count 3"},
		{"bool", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Repeat(0, U8(0, "w"), Flags(1, Bool(1, "on"))))
		}, gm("w", []any{1, 2}, "on", []any{true}), 1, "on", "1 items, repeat count 2"},
		{"split bit", split, gm("w", []any{1, 2}, "v", []any{5}), 1, "v", "1 items, repeat count 2"},
		{"group under flags", grouped, gm("w", []any{1, 2}, "g", []any{gm("v", 5)}), 1, "g", "1 items, repeat count 2"},
		{"group member given flat (Go-4)", grouped, gm("w", []any{1, 2}, "v", []any{5}), 1, "v", "member of group g"},
		{"u2 slot", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Repeat(0, U8(0, "w"), Flags(1, U2(Slot(1, "p"), Slot(2, "q")))))
		}, gm("w", []any{1, 2}, "p", []any{1}, "q", []any{2, 3}), 1, "p", "1 items, repeat count 2"},
		{"when under flags", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Repeat(0, U8(0, "w"), Flags(1, When(1, Eq(0, 1), U8(1, "v")))))
		}, gm("w", []any{1, 1}, "v", []any{5}), 1, "v", "1 items, repeat count 2"},
		{"combined flags names the short member", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Repeat(0, Flags(0, U8(0, "a"), U8(1, "b"))))
		}, gm("a", []any{1}, "b", []any{5, 6}), 0, "a", "1 items, repeat count 2"},
		{"a group that holds flags is optional too", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Repeat(0, U8(0, "w"), Group(1, "g", Flags(1, U8(1, "v")))))
		}, gm("w", []any{1, 2}, "g", []any{gm("v", 5)}), 1, "g", "1 items, repeat count 2"},
		{"required member keeps its own error", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Repeat(0, U8(0, "a"), U8(1, "b")))
		}, gm("a", []any{1, 2}, "b", []any{3}), 1, "b", "missing b"},
		{"short required beside optional is missing", optionalU8, gm("w", []any{1}, "v", []any{5, 6}), 0, "w", "missing w"},
	})
}

// AC-2 (repeat-short-optional): the rows the rule does not touch keep their bytes.
func TestAC2RepeatShortOptionalAcceptedRows(t *testing.T) {
	runPacks(t, []packCase{
		{"full list with nil", optionalU8, gm("w", []any{1, 2}, "v", []any{5, nil}), "010101050200"},
		{"full list with a nil pointer", optionalU8, gm("w", []any{1, 2}, "v", []any{5, (*int)(nil)}), "010101050200"},
		{"both entries", optionalU8, gm("w", []any{1, 2}, "v", []any{5, 6}), "01010105020106"},
		{"no entry", optionalU8, gm("w", []any{1, 2}), "0101000200"},
		{"empty list", optionalU8, gm("w", []any{1, 2}, "v", []any{}), "0101000200"},
		{"lone value", optionalU8, gm("w", []any{1, 2}, "v", 5), "01010105020105"},
		{"bool full list", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Repeat(0, U8(0, "w"), Flags(1, Bool(1, "on"))))
		}, gm("w", []any{1, 2}, "on", []any{true, nil}), "0101010200"},
		{"times keeps a short list under flags", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, U8(0, "c"), Times(1, 0, Flags(1, U8(1, "v"))))
		}, gm("c", 2, "v", []any{5}), "0102010500"},
		{"a when outside flags keeps its short list", whenRepeat, gm("k", []any{1, 2}, "v", []any{9}), "01010902"},
	})
}

func timesOne(t testing.TB) *Scheme { return mustScheme(t, 1, U8(0, "a"), Times(1, 0, U8(1, "x"))) }

func timesTwo(t testing.TB) *Scheme {
	return mustScheme(t, 1, U8(0, "a"), Times(1, 0, U8(1, "x"), U8(2, "y")))
}

// AC-2 (times-longer-list, times-count-zero-with-values): a list longer than the count is refused
// naming the member, the items and the count; a count of 0 with values too.
func TestAC2TimesLongerListIsRefused(t *testing.T) {
	plain := func(t testing.TB) *Scheme { return mustScheme(t, 1, U8(0, "n"), Times(1, 0, U8(1, "pt"))) }
	combined := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, U8(0, "n"), Flags(1, Times(1, 0, U8(1, "pt")), U16(2, "heading")))
	}
	group := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, U8(0, "a"), Times(1, 0, Group(1, "g", U8(1, "p"))))
	}
	runRefusals(t, []refusalCase{
		{"longer list", timesOne, gm("a", 2, "x", []any{1, 2, 3}), 1, "x", "x: 3 items, times count 2"},
		{"count zero, one item", timesOne, gm("a", 0, "x", []any{1}), 1, "x", "x: 1 items, times count 0"},
		{"a second member", timesTwo, gm("a", 2, "x", []any{1, 2}, "y", []any{3, 4, 5}), 2, "y", "y: 3 items, times count 2"},
		{"a member under when", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, U8(0, "a"), Times(1, 0, U8(1, "k"), When(2, Eq(1, 1), U8(2, "v"))))
		}, gm("a", 1, "k", []any{1}, "v", []any{7, 8}), 2, "v", "v: 2 items, times count 1"},
		{"under flags", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, U8(0, "a"), Times(1, 0, Flags(1, U8(1, "p"), U8(2, "q"))))
		}, gm("a", 1, "p", []any{1}, "q", []any{2, 3}), 2, "q", "q: 2 items, times count 1"},
		{"a group", group, gm("a", 1, "g", []any{gm("p", 1), gm("p", 2)}), 1, "g", "g: 2 items, times count 1"},
		{"a group member given flat (Go-4)", group, gm("a", 1, "p", []any{1, 2}), 1, "p", "member of group g"},
		{"shorter list is missing", timesOne, gm("a", 2, "x", []any{1}), 1, "x", "missing x"},
		{"count 0 with values, outside flags", plain, gm("n", 0, "pt", []any{5}, "heading", 90), 1, "pt", "pt: 1 items, times count 0"},
		{"count 0 with values, inside flags", combined, gm("n", 0, "pt", []any{5}, "heading", 90), 1, "pt", "pt: 1 items, times count 0"},
		{"count 0 names the second member", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, U8(0, "n"), Times(1, 0, U8(1, "pt"), U8(2, "pu")))
		}, gm("n", 0, "pu", []any{6}), 2, "pu", "pu: 1 items, times count 0"},
	})
	runPacks(t, []packCase{
		{"count 0, empty list", timesOne, gm("a", 0, "x", []any{}), "0100"},
		{"count 0, absent", timesOne, gm("a", 0), "0100"},
		{"exact list", timesOne, gm("a", 2, "x", []any{1, 2}), "01020102"},
		{"lone scalar", timesOne, gm("a", 2, "x", 5), "01020505"},
		{"lone scalar, one round", timesOne, gm("a", 1, "x", 5), "010105"},
		{"two members", timesTwo, gm("a", 2, "x", []any{1, 2}, "y", []any{3, 4}), "010201030204"},
		{"short list under when", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, U8(0, "a"), Times(1, 0, U8(1, "k"), When(2, Eq(1, 1), U8(2, "v"))))
		}, gm("a", 2, "k", []any{1, 0}, "v", []any{7}), "0102010700"},
		{"count 0 without values, outside flags", plain, gm("n", 0, "heading", 90), "0100"},
		{"count 0 without values, inside flags", combined, gm("n", 0, "heading", 90), "0100025a00"},
		{"count 0 with an empty list, inside flags", combined, gm("n", 0, "pt", []any{}, "heading", 90), "0100025a00"},
		{"count 0 with a lone scalar", plain, gm("n", 0, "pt", 5), "0100"},
	})
	if again := mustPack(t, timesOne(t), mustUnpackMap(t, timesOne(t), "01020102")); again != "01020102" {
		t.Fatalf("AC-5 repack %s", again)
	}
}
