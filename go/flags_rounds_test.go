package packbin

import (
	"reflect"
	"testing"
)

// The flags-times-repeat-member schemes: a times or repeat as a flags member, a split bit's field, or
// in a group under flags (the group's values in a map of their own, Go-4).
func timesInFlags(t testing.TB) *Scheme {
	return mustScheme(t, 1, U8(0, "n"), Flags(1, Times(1, 0, U8(1, "pt")), U16(2, "heading")))
}

func timesInSplit(t testing.TB) *Scheme {
	fb := FlagByte("m")
	return mustScheme(t, 1, U8(0, "n"), fb, fb.Bit(Times(1, 0, U8(1, "pt"))), fb.Bit(U16(2, "heading")))
}

func timesInGroup(t testing.TB) *Scheme {
	return mustScheme(t, 1, U8(0, "n"), Flags(1, Group(1, "g", Times(1, 0, U8(1, "pt"))), U16(2, "heading")))
}

func repeatInFlags(t testing.TB) *Scheme {
	return mustScheme(t, 1, U8(0, "mode"), Flags(1, U16(1, "heading"), Repeat(2, U8(2, "pt"))))
}

type unpackCase struct {
	name   string
	scheme func(t testing.TB) *Scheme
	row    map[string]any // nil: only unpacked
	hex    string
	want   map[string]any
}

func runUnpackCases(t *testing.T, cases []unpackCase) {
	t.Helper()
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Arrange
			s := c.scheme(t)

			// Act
			back := mustUnpackMap(t, s, c.hex)

			// Assert
			if c.row != nil {
				if wire := mustPack(t, s, c.row); wire != c.hex {
					t.Fatalf("packs %s, want %s", wire, c.hex)
				}
			}
			if !reflect.DeepEqual(back, c.want) {
				t.Fatalf("unpacks %#v", back)
			}
		})
	}
}

func u8List(v ...uint8) []any {
	out := make([]any, len(v))
	for i, x := range v {
		out[i] = x
	}
	return out
}

// AC-2 (flags-times-repeat-member): a times or repeat as a flags member is written like any other
// value: its bit is set exactly when it writes a value.
func TestAC2RoundAsAFlagsMember(t *testing.T) {
	n := func(v uint8) any { return v }
	h := uint16(90)
	t2 := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, U8(0, "n"), Flags(1, Times(1, 0, U8(1, "pt"), U8(2, "pu")), U16(3, "heading")))
	}
	r2 := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, U8(0, "mode"), Flags(1, U16(1, "heading"), Repeat(2, U8(2, "pt"), U8(3, "pu"))))
	}
	var cases []unpackCase
	for _, sh := range []struct {
		kind   string
		scheme func(t testing.TB) *Scheme
	}{{"flags", timesInFlags}, {"split", timesInSplit}} {
		cases = append(cases,
			unpackCase{sh.kind + " times 0 rounds", sh.scheme, gm("n", 0, "heading", 90), "0100025a00", gm("n", n(0), "heading", h)},
			unpackCase{sh.kind + " times 1 round", sh.scheme, gm("n", 1, "pt", []any{5}, "heading", 90), "010103055a00",
				gm("n", n(1), "pt", u8List(5), "heading", h)},
			unpackCase{sh.kind + " times 2 rounds", sh.scheme, gm("n", 2, "pt", []any{5, 6}, "heading", 90), "01020305065a00",
				gm("n", n(2), "pt", u8List(5, 6), "heading", h)})
	}
	cases = append(cases,
		unpackCase{"group times 0 rounds", timesInGroup, gm("n", 0, "heading", 90), "0100025a00", gm("n", n(0), "heading", h)},
		unpackCase{"group times 1 round", timesInGroup, gm("n", 1, "g", gm("pt", []any{5}), "heading", 90), "010103055a00",
			gm("n", n(1), "g", gm("pt", u8List(5)), "heading", h)},
		unpackCase{"group times 2 rounds", timesInGroup, gm("n", 2, "g", gm("pt", []any{5, 6}), "heading", 90), "01020305065a00",
			gm("n", n(2), "g", gm("pt", u8List(5, 6)), "heading", h)},
		unpackCase{"times only", timesInFlags, gm("n", 2, "pt", []any{5, 6}), "0102010506", gm("n", n(2), "pt", u8List(5, 6))},
		unpackCase{"count only", timesInFlags, gm("n", 0), "010000", gm("n", n(0))},
		unpackCase{"two values, one round", t2, gm("n", 1, "pt", []any{5}, "pu", []any{6}, "heading", 90), "01010305065a00",
			gm("n", n(1), "pt", u8List(5), "pu", u8List(6), "heading", h)},
		unpackCase{"two values, two rounds", t2, gm("n", 2, "pt", []any{5, 6}, "pu", []any{7, 8}, "heading", 90),
			"010203050706085a00", gm("n", n(2), "pt", u8List(5, 6), "pu", u8List(7, 8), "heading", h)},
		unpackCase{"repeat 0 rounds", repeatInFlags, gm("mode", 1, "heading", 90), "0101015a00", gm("mode", n(1), "heading", h)},
		unpackCase{"repeat 1 round", repeatInFlags, gm("mode", 1, "pt", []any{5}, "heading", 90), "0101035a0005",
			gm("mode", n(1), "pt", u8List(5), "heading", h)},
		unpackCase{"repeat 2 rounds", repeatInFlags, gm("mode", 1, "pt", []any{5, 6}, "heading", 90), "0101035a000506",
			gm("mode", n(1), "pt", u8List(5, 6), "heading", h)},
		unpackCase{"repeat only", repeatInFlags, gm("mode", 1, "pt", []any{5, 6}), "0101020506", gm("mode", n(1), "pt", u8List(5, 6))},
		unpackCase{"repeat none", repeatInFlags, gm("mode", 1), "010100", gm("mode", n(1))},
		unpackCase{"repeat two values from the wire", r2, nil, "0101035a0005060708",
			gm("mode", n(1), "pt", u8List(5, 7), "pu", u8List(6, 8), "heading", h)},
		unpackCase{"count in the scope written", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, U8(0, "p"), Flags(1, Times(1, 0, U8(1, "pt")), U16(2, "heading")))
		}, gm("p", 1, "pt", []any{5}, "heading", 90), "010103055a00", gm("p", n(1), "pt", u8List(5), "heading", h)},
		unpackCase{"count member skipped, times bit clear", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Flags(0, U8(0, "n"), Times(1, 0, U8(1, "pt")), U16(2, "heading")))
		}, gm("heading", 90), "01045a00", gm("heading", h)},
	)
	runUnpackCases(t, cases)
	var refusals []refusalCase
	for _, sh := range []struct {
		kind   string
		scheme func(t testing.TB) *Scheme
		g      func(m map[string]any) map[string]any
	}{
		{"flags", timesInFlags, func(m map[string]any) map[string]any { return m }},
		{"split", timesInSplit, func(m map[string]any) map[string]any { return m }},
		{"group", timesInGroup, func(m map[string]any) map[string]any { return gm("g", m) }},
	} {
		with := func(count int, pt any) map[string]any {
			row := gm("n", count, "heading", 90)
			if pt != nil {
				for k, v := range sh.g(gm("pt", pt)) {
					row[k] = v
				}
			}
			return row
		}
		refusals = append(refusals,
			refusalCase{sh.kind + " list shorter than the count", sh.scheme, with(2, []any{5}), 1, "pt", "missing pt"},
			refusalCase{sh.kind + " body values missing", sh.scheme, with(1, nil), 1, "pt", "missing pt"},
			refusalCase{sh.kind + " count 0 with a list", sh.scheme, with(0, []any{5}), 1, "pt", "times count 0"},
			refusalCase{sh.kind + " list longer than the count", sh.scheme, with(1, []any{5, 6}), 1, "pt", "times count 1"})
	}
	refusals = append(refusals,
		refusalCase{"second body value missing", t2, gm("n", 1, "pt", []any{5}, "heading", 90), 2, "pu", "missing pu"},
		refusalCase{"repeat second body value missing", r2, gm("mode", 1, "pt", []any{5}, "heading", 90), 3, "pu", "missing pu"})
	runRefusals(t, refusals)
}

// AC-2 (flags-under-split-bit): flags in a group under a split bit, and flags directly in flags.
func TestAC2FlagsUnderASplitBit(t *testing.T) {
	splitBit := func(t testing.TB) *Scheme {
		fb := FlagByte("m")
		return mustScheme(t, 1, fb, fb.Bit(Group(0, "g", U8(0, "a"), Flags(1, U8(1, "c")))))
	}
	flagsInFlags := func(t testing.TB) *Scheme { return mustScheme(t, 1, Flags(0, Flags(0, U8(0, "c")))) }
	runUnpackCases(t, []unpackCase{
		{"flags in a group under a split bit", splitBit, gm("g", gm("a", 1, "c", 2)), "0101010102",
			gm("g", gm("a", uint8(1), "c", uint8(2)))},
		{"absent member stays absent", splitBit, gm("g", gm("a", 1)), "01010100", gm("g", gm("a", uint8(1)))},
		{"absent group", splitBit, gm(), "0100", gm()},
		{"flags in flags", flagsInFlags, gm("c", 2), "01010102", gm("c", uint8(2))},
		{"flags in flags absent", flagsInFlags, gm(), "0100", gm()},
		{"flags three deep", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Flags(0, Flags(0, Flags(0, U8(0, "c")))))
		}, gm("c", 9), "0101010109", gm("c", uint8(9))},
		{"a split bit holding flags", func(t testing.TB) *Scheme {
			fb := FlagByte("m")
			return mustScheme(t, 1, fb, fb.Bit(Flags(0, U8(0, "c"))))
		}, gm("c", 3), "01010103", gm("c", uint8(3))},
		{"two flags in one group under a split bit", func(t testing.TB) *Scheme {
			fb := FlagByte("m")
			return mustScheme(t, 1, fb, fb.Bit(Group(0, "g", Flags(0, U8(0, "c")), Flags(1, U8(1, "d")))))
		}, gm("g", gm("c", 1, "d", 2)), "010101010102", gm("g", gm("c", uint8(1), "d", uint8(2)))},
	})
	runRefusals(t, []refusalCase{
		{"a missing required member in a given group", splitBit, gm("g", gm("c", 2)), 0, "a", "missing a"},
		{"a member given flat (Go-4; TypeScript: missing a)", splitBit, gm("c", 2), 1, "c", "member of group g"},
	})
}

// A round in flags nested in flags, a split bit or a group under flags: the outer bit looks into the
// round as the inner one does.
func TestRoundInNestedFlags(t *testing.T) {
	inFlags := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, U8(0, "n"), Flags(1, Flags(1, Times(1, 0, U8(1, "pt")))))
	}
	inSplit := func(t testing.TB) *Scheme {
		fb := FlagByte("m")
		return mustScheme(t, 1, U8(0, "n"), fb, fb.Bit(Flags(1, Repeat(1, U8(1, "pt")))))
	}
	inGroup := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, U8(0, "n"), Flags(1, Group(1, "g", Flags(1, Times(1, 0, U8(1, "pt"))))))
	}
	runUnpackCases(t, []unpackCase{
		{"times in flags in flags", inFlags, gm("n", 1, "pt", []any{5}), "0101010105", gm("n", uint8(1), "pt", u8List(5))},
		{"count 0 in flags in flags", inFlags, gm("n", 0), "010000", gm("n", uint8(0))},
		{"repeat in flags in a split bit", inSplit, gm("n", 1, "pt", []any{5, 6}), "010101010506",
			gm("n", uint8(1), "pt", u8List(5, 6))},
		{"repeat with no round", inSplit, gm("n", 1), "010100", gm("n", uint8(1))},
		{"times in flags in a group", inGroup, gm("n", 1, "g", gm("pt", []any{5})), "0101010105",
			gm("n", uint8(1), "g", gm("pt", u8List(5)))},
	})
	runRefusals(t, []refusalCase{
		{"a count above 0 sets the group's bit, so its rounds are missing", inGroup, gm("n", 1), 1, "pt", "missing pt"},
	})
}
