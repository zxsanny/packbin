package packbin

import "testing"

// fuzzSchemes are the schemes FuzzUnpack reads every input with: the ring kinds of
// .github/workflows/language-pair.sh, the golden position, and one scheme for each kind of field a
// hostile packet can aim at (rounds with and without low limits, counted fields, groups, flags, list
// and dict elements). Each has its own type number, so one call can dispatch among all of them.
func fuzzSchemes(t testing.TB) []*Scheme {
	fb := FlagByte("m")
	low := func(s *Scheme) *Scheme {
		return limited(t, s, func(l *Limits) { l.MaxRounds, l.MaxSlots = 3, 8 })
	}
	wide := make([]Field, 0, 40)
	for i := range 40 {
		wide = append(wide, U8(i+1, "w"+string(rune('a'+i/26))+string(rune('a'+i%26))))
	}
	return []*Scheme{
		// 1 user: a string, a list of strings, a dict of lists of strings
		mustScheme(t, 1, Utf8(0, "username"), List("roles", Utf8(0, "role")), Dict("access", List("ops", Utf8(0, "op")))),
		// 2 nested: a dict of lists of dicts
		mustScheme(t, 2, Dict("access", List("rows", Dict("row", Utf8(0, "v"))))),
		// 3 boolflag
		mustScheme(t, 3, Flags(0, Bool(0, "on"))),
		// 4 bitwhen: a split flag byte inside a when
		mustScheme(t, 4, U8(0, "k"), fb, When(1, Eq(0, 1), fb.Bit(U8(1, "v")))),
		// 5 roundflags and 6 roundwhen
		mustScheme(t, 5, Repeat(0, Flags(0, Bool(0, "on"), U8(1, "n")))),
		mustScheme(t, 6, Repeat(0, U8(0, "k"), When(1, Eq(0, 1), U8(1, "v")))),
		// 7 listgroup, 8 dictgroup, 9 listflags
		mustScheme(t, 7, List("pts", Nested("p", U8(0, "a"), U8(1, "b")))),
		mustScheme(t, 8, Dict("m", Nested("p", U8(0, "a"), U8(1, "b")))),
		mustScheme(t, 9, List("pts", Flags(0, U8(0, "a"), U16(1, "b")))),
		// 10 a times of a number and a string, 11 the same with low limits
		mustScheme(t, 10, U8(0, "n"), Times(1, 0, U8(1, "v"), Utf8(2, "s"))),
		low(mustScheme(t, 11, U8(0, "n"), Times(1, 0, U8(1, "v"), Utf8(2, "s")))),
		// 12 counted fields
		mustScheme(t, 12, U8(0, "n"), Sized(1, "raw", 0), U8(2, "c"), Bits(3, "b", 2), U8(4, "d"),
			Packed(2, 5, "p", 4, -1), U2(Slot(6, "s0"), Slot(7, "s1"))),
		// 13 a repeat of a number and a list, 14 a repeat with low limits
		mustScheme(t, 13, Repeat(0, U8(0, "k"), List("xs", U8(0, "e")))),
		low(mustScheme(t, 14, Repeat(0, U8(0, "k")))),
		// 15 a wide round that reaches MaxSlots first
		mustScheme(t, 15, Repeat(0, append([]Field{U8(0, "k")}, When(1, Eq(0, 1), wide...))...)),
		// 16 groups and flags
		mustScheme(t, 16, U8(0, "a"), Flags(1, Group(1, "g", U8(1, "x"), U8(2, "y")), U8(3, "z"))),
		// 17 a count that is a u32, so a huge count meets a short packet or a limit
		mustScheme(t, 17, U32(0, "n"), Times(1, 0, U8(1, "v"))),
		// 18 a list element that holds a times: one counter for the whole call
		mustScheme(t, 18, List("items", Nested("item", U8(0, "n"), Times(1, 0, U16(1, "k"))))),
		// 0x40 the golden position
		positionMapScheme(t),
	}
}
