package packbin

import (
	"bytes"
	"math"
	"strconv"
	"strings"
	"testing"
	"time"
)

// refusedPack asserts a refused pack: nil bytes, kind PackRefused, and the reason TypeScript words.
func refusedPack(t testing.TB, s *Scheme, row any, reason string) {
	t.Helper()
	raw, err := Pack(s, row)
	e := asError(t, err, PackRefused)
	if raw != nil || e.Reason != reason {
		t.Fatalf("bytes %x, reason %q, want %q", raw, e.Reason, reason)
	}
}

func listOf(n int, v any) []any {
	out := make([]any, n)
	for i := range out {
		out[i] = v
	}
	return out
}

func TestAC1PackRefusesARepeatListAboveMaxRounds(t *testing.T) {
	// Arrange
	layout := repeatK(t)

	// Act / Assert
	refusedPack(t, layout, map[string]any{"k": listOf(65_536, 7)},
		"k: the repeat count is 65536, above the limit of 65535 rounds")
}

func TestAC1RepeatCapNamesTheListThatPassesTheLimit(t *testing.T) {
	// Arrange
	layout := limited(t, mustScheme(t, 1, Repeat(0, U8(0, "a"), U8(1, "b"))), func(l *Limits) { l.MaxRounds = 3 })

	// Act / Assert
	refusedPack(t, layout, map[string]any{"a": 1, "b": []any{1, 2, 3, 4}},
		"b: the repeat count is 4, above the limit of 3 rounds")
}

func TestAC1RepeatCapHoldsInFlagsASplitBitAWhenAndAListElement(t *testing.T) {
	// Arrange
	fb := FlagByte("m")
	k := []any{1, 2, 3, 4}
	cases := []struct {
		where  string
		scheme *Scheme
		row    map[string]any
	}{
		{"flags", mustScheme(t, 1, Flags(0, Repeat(0, U8(0, "k")))), map[string]any{"k": k}},
		{"split bit", mustScheme(t, 1, fb, fb.Bit(Repeat(0, U8(0, "k")))), map[string]any{"k": k}},
		{"when", mustScheme(t, 1, U8(0, "m"), When(1, Eq(0, 1), Repeat(1, U8(1, "k")))), map[string]any{"m": 1, "k": k}},
		{"list element", mustScheme(t, 1, List("items", Nested("item", Repeat(0, U8(0, "k"))))),
			map[string]any{"items": []any{map[string]any{"k": k}}}},
	}

	for _, c := range cases {
		t.Run(c.where, func(t *testing.T) {
			// Act / Assert
			refusedPack(t, limited(t, c.scheme, func(l *Limits) { l.MaxRounds = 3 }), c.row,
				"k: the repeat count is 4, above the limit of 3 rounds")
		})
	}
}

func TestAC1RepeatOfMaxRoundsEntriesPacksAndRoundTrips(t *testing.T) {
	// Arrange
	layout := repeatK(t)

	// Act
	raw, err := Pack(layout, map[string]any{"k": listOf(65_535, 7)})
	row, unpackErr := UnpackMap(raw, layout)
	again, againErr := Pack(layout, row)

	// Assert
	if err != nil || unpackErr != nil || againErr != nil || len(raw) != 65_536 || !bytes.Equal(raw, again) {
		t.Fatalf("%d bytes: %v %v %v", len(raw), err, unpackErr, againErr)
	}
}

func TestAC3RepeatWithMaxRoundsRaisedPacksMore(t *testing.T) {
	// Arrange
	layout := limited(t, repeatK(t), func(l *Limits) { l.MaxRounds = 70_000 })

	// Act
	raw, err := Pack(layout, map[string]any{"k": listOf(70_000, 7)})

	// Assert
	if err != nil || len(raw) != 70_001 {
		t.Fatalf("%d bytes: %v", len(raw), err)
	}
}

func TestAC1LoweredRepeatLimitLowersWhatPacks(t *testing.T) {
	// Arrange
	layout := limited(t, repeatK(t), func(l *Limits) { l.MaxRounds = 3 })

	// Act / Assert
	refusedPack(t, layout, map[string]any{"k": []any{1, 2, 3, 4}}, "k: the repeat count is 4, above the limit of 3 rounds")
	if got := mustPack(t, layout, map[string]any{"k": []any{1, 2, 3}}); got != "01010203" {
		t.Fatalf("got %s", got)
	}
}

func TestAC1PackRefusesATimesCountAboveMaxRoundsBeforeAnyRound(t *testing.T) {
	// Arrange
	layout := timesK32(t)
	factor := loadFactor()
	start := time.Now()

	// Act / Assert
	refusedPack(t, layout, map[string]any{"n": DefaultMaxRounds + 1, "k": 7},
		"k: the times count is 65536, above the limit of 65535 rounds")
	refusedPack(t, layout, map[string]any{"n": uint32(4_000_000_000), "k": 7},
		"k: the times count is 4000000000, above the limit of 65535 rounds")
	refusedPack(t, layout, map[string]any{"n": 70_000},
		"k: the times count is 70000, above the limit of 65535 rounds")
	assertWithin(t, "the refusals looped over the rounds", time.Since(start), time.Second, factor)
}

func TestAC1LoweredTimesLimitLowersWhatPacks(t *testing.T) {
	// Arrange
	layout := limited(t, timesK32(t), func(l *Limits) { l.MaxRounds = 3 })

	// Act / Assert
	refusedPack(t, layout, map[string]any{"n": 4, "k": 7}, "k: the times count is 4, above the limit of 3 rounds")
	if got := mustPack(t, layout, map[string]any{"n": 3, "k": 7}); got != "0103000000070707" {
		t.Fatalf("got %s", got)
	}
}

func TestAC1TimesCapHoldsForAMemberOfFlags(t *testing.T) {
	// Arrange
	layout := mustScheme(t, 1, U32(0, "n"), Flags(1, Times(1, 0, U8(1, "k")), U16(2, "h")))

	// Act / Assert
	refusedPack(t, layout, map[string]any{"n": 65_536, "k": 7, "h": 1},
		"k: the times count is 65536, above the limit of 65535 rounds")
}

func TestAC1TimesOfMaxRoundsPacksAndRoundTrips(t *testing.T) {
	// Arrange
	layout := timesK32(t)

	// Act
	raw, err := Pack(layout, map[string]any{"n": DefaultMaxRounds, "k": 7})
	row, unpackErr := UnpackMap(raw, layout)
	again, againErr := Pack(layout, row)

	// Assert
	if err != nil || unpackErr != nil || againErr != nil || len(raw) != 5+DefaultMaxRounds ||
		len(row["k"].([]any)) != DefaultMaxRounds || !bytes.Equal(raw, again) {
		t.Fatalf("%d bytes: %v %v %v", len(raw), err, unpackErr, againErr)
	}
}

func TestAC3TimesWithMaxRoundsRaisedPacksALargerCount(t *testing.T) {
	// Arrange
	base := timesK32(t)
	raised := limited(t, base, func(l *Limits) { l.MaxRounds = 70_000 })

	// Act
	raw, err := Pack(raised, map[string]any{"n": 66_000, "k": 7})
	_, unpackErr := UnpackMap(raw, raised)

	// Assert
	if err != nil || unpackErr != nil || len(raw) != 5+66_000 {
		t.Fatalf("%d bytes: %v %v", len(raw), err, unpackErr)
	}
	if _, err := Pack(base, map[string]any{"n": 66_000, "k": 7}); err == nil {
		t.Fatal("the default scheme packed a count above its limit")
	}
}

func TestAC1PackedPacketOfExactlyMaxBytesPacksAndOneMoreIsRefused(t *testing.T) {
	// Arrange
	layout := limited(t, mustScheme(t, 1, Utf8(0, "s")), func(l *Limits) { l.MaxBytes = 64 })

	// Act
	exact, err := Pack(layout, map[string]any{"s": strings.Repeat(ctrl, 61)})

	// Assert
	if err != nil || len(exact) != 64 || hexOf(exact) != "013e10"+strings.Repeat("01", 61) {
		t.Fatalf("%x, %v", exact, err)
	}
	refusedPack(t, layout, map[string]any{"s": strings.Repeat(ctrl, 62)},
		"s: the packet would be 65 bytes, above the limit of 64 bytes")
}

func TestAC1TheBudgetHoldsRoundByRound(t *testing.T) {
	// Arrange
	layout := limited(t, repeatK(t), func(l *Limits) { l.MaxBytes = 64 })

	// Act
	exact, err := Pack(layout, map[string]any{"k": listOf(63, 7)})

	// Assert
	if err != nil || hexOf(exact) != "01"+strings.Repeat("07", 63) {
		t.Fatalf("%x, %v", exact, err)
	}
	refusedPack(t, layout, map[string]any{"k": listOf(64, 7)}, "k: the packet would be 65 bytes, above the limit of 64 bytes")
}

func TestAC1TheTypeByteCountsAndAFlagByteOrAListCountIsNamedByItsMember(t *testing.T) {
	// Arrange
	one := func(l *Limits) { l.MaxBytes = 1 }
	fb := FlagByte("m")
	cases := []struct {
		name   string
		scheme *Scheme
		row    map[string]any
		reason string
	}{
		{"value", limited(t, mustScheme(t, 1, U8(0, "a")), one), map[string]any{"a": 1},
			"a: the packet would be 2 bytes, above the limit of 1 bytes"},
		{"split flag byte", limited(t, mustScheme(t, 1, fb, fb.Bit(U8(0, "c"))), one), map[string]any{"c": 1},
			"m: the packet would be 2 bytes, above the limit of 1 bytes"},
		{"combined flag byte", limited(t, mustScheme(t, 1, Flags(0, U8(0, "c"))), one), map[string]any{"c": 1},
			"c: the packet would be 2 bytes, above the limit of 1 bytes"},
		{"list count", limited(t, mustScheme(t, 1, List("xs", U8(0, "v"))), func(l *Limits) { l.MaxBytes = 2 }),
			map[string]any{"xs": []any{}}, "xs: the packet would be 3 bytes, above the limit of 2 bytes"},
		{"flag byte of a times", limited(t, mustScheme(t, 1, U8(0, "n"), Flags(1, Times(1, 0, U8(1, "k")))),
			func(l *Limits) { l.MaxBytes = 2 }), map[string]any{"n": 1, "k": 3},
			"k: the packet would be 3 bytes, above the limit of 2 bytes"},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Act / Assert
			refusedPack(t, c.scheme, c.row, c.reason)
		})
	}
	bare := limited(t, mustScheme(t, 1), one)
	if got := mustPack(t, bare, map[string]any{}); got != "01" {
		t.Fatalf("got %s", got)
	}
}

func TestAC1ALoneStringUnderATimesIsRefusedNamingItInUnderASecond(t *testing.T) {
	// Arrange
	layout := mustScheme(t, 1, U32(0, "n"), Times(1, 0, Utf8(1, "s")))
	row := map[string]any{"n": 65_535, "s": strings.Repeat(ctrl, 65_535)}
	factor := loadFactor()
	start := time.Now()

	// Act
	raw, err := Pack(layout, row)
	took := time.Since(start)

	// Assert
	e := asError(t, err, PackRefused)
	if raw != nil || e.Name != "s" || e.Reason != "s: the packet would be 16777989 bytes, above the limit of 16777216 bytes" {
		t.Fatalf("%x, %+v", raw, e)
	}
	assertWithin(t, "the refusal of a lone string under a times", took, time.Second, factor)
}

func elementTimes(t testing.TB) *Scheme {
	return mustScheme(t, 1, List("items", Nested("item", U32(0, "n"), Times(1, 0, Utf8(1, "s")))))
}

func elementRows(items int) map[string]any {
	row := make([]any, items)
	for i := range row {
		row[i] = map[string]any{"n": 65_535, "s": strings.Repeat(ctrl, 16)}
	}
	return map[string]any{"items": row}
}

func TestAC1AnElementThatHoldsATimesIsRefusedAtTheDefaultBudgetNamingItsMember(t *testing.T) {
	// Arrange
	layout := elementTimes(t)

	// Act / Assert
	refusedPack(t, layout, elementRows(16), "s: the packet would be 16777233 bytes, above the limit of 16777216 bytes")
}

func TestAC1AnElementTimesPacksAndUnpacksWithMaxBytesRaised(t *testing.T) {
	// Arrange
	layout := limited(t, elementTimes(t), func(l *Limits) { l.MaxBytes = 33_554_432 })

	// Act
	raw, err := Pack(layout, elementRows(16))
	row, unpackErr := UnpackMap(raw, layout)

	// Assert
	if err != nil || len(raw) != 18_874_147 || hexOf(raw[:16]) != "011000ffff0000"+"1110"+strings.Repeat("01", 7) ||
		hexOf(raw[len(raw)-16:]) != strings.Repeat("01", 16) {
		t.Fatalf("%d bytes: %v", len(raw), err)
	}
	if unpackErr != nil {
		t.Fatal(unpackErr)
	}
	items := row["items"].([]any)
	last := items[15].(map[string]any)
	if len(items) != 16 || last["n"] != uint32(65_535) || len(last["s"].([]any)) != 65_535 {
		t.Fatalf("%d items", len(items))
	}
}

func TestAC1SlotsAreChargedBeforeABytesAndAcrossTheWholeCall(t *testing.T) {
	// Arrange
	both := limited(t, timesK32(t), func(l *Limits) { l.MaxSlots, l.MaxBytes = 3, 8 })
	inItems := limited(t, mustScheme(t, 1, List("items", Nested("item", U8(0, "n"), Times(1, 0, U8(1, "k"))))),
		func(l *Limits) { l.MaxSlots = 5 })
	items := func(a, b int) map[string]any {
		return map[string]any{"items": []any{map[string]any{"n": a, "k": 1}, map[string]any{"n": b, "k": 2}}}
	}

	// Act
	atBoth := mustPack(t, both, map[string]any{"n": 3, "k": 7})
	within := mustPack(t, inItems, items(3, 2))

	// Assert
	if atBoth != "0103000000070707" || within != "01020003010101020202" {
		t.Fatalf("%s, %s", atBoth, within)
	}
	refusedPack(t, both, map[string]any{"n": 10, "k": 7}, "k: the rounds would hold 4 slots, above the limit of 3 slots")
	refusedPack(t, limited(t, timesK32(t), func(l *Limits) { l.MaxSlots, l.MaxBytes = 3, 7 }), map[string]any{"n": 10, "k": 7},
		"k: the packet would be 8 bytes, above the limit of 7 bytes")
	refusedPack(t, inItems, items(3, 3), "k: the rounds would hold 6 slots, above the limit of 5 slots")
}

func TestAC1TheRoundCapFiresBeforeAnyRoundAndACountFieldBeforeTheRoundCap(t *testing.T) {
	// Arrange
	rounds := limited(t, timesK32(t), func(l *Limits) { l.MaxRounds, l.MaxSlots, l.MaxBytes = 5, 3, 8 })
	count := limited(t, timesK32(t), func(l *Limits) { l.MaxRounds, l.MaxSlots, l.MaxBytes = 5, 3, 4 })

	// Act / Assert
	refusedPack(t, rounds, map[string]any{"n": 10, "k": 7}, "k: the times count is 10, above the limit of 5 rounds")
	refusedPack(t, count, map[string]any{"n": 10, "k": 7}, "n: the packet would be 5 bytes, above the limit of 4 bytes")
}

func TestAC1AGroupsOwnNameIsNotASlotOnPack(t *testing.T) {
	// Arrange
	layout := limited(t, mustScheme(t, 1, Repeat(0, U8(0, "a"), Group(1, "g", U8(1, "b")))), func(l *Limits) { l.MaxSlots = 5 })
	rows := func(n int) map[string]any {
		a, g := make([]any, n), make([]any, n)
		for i := range n {
			a[i], g[i] = i+1, map[string]any{"b": i + 3}
		}
		return map[string]any{"a": a, "g": g}
	}

	// Act
	two := mustPack(t, layout, rows(2))

	// Assert
	if two != "0101030204" {
		t.Fatalf("got %s", two)
	}
	refusedPack(t, layout, rows(3), "a: the rounds would hold 6 slots, above the limit of 5 slots")
}

func TestAC1WideRoundCountedMaxRoundsTimesIsRefusedNamingTheFirstMember(t *testing.T) {
	// Arrange
	layout, row := wideRound(t)

	// Act / Assert
	refusedPack(t, layout, row, "m0: the rounds would hold 1048580 slots, above the limit of 1048576 slots")
}

// wideRound is u32 n; times(n) { 65 u8 members m0..m64 }, n 65 535, each member the lone scalar 1.
func wideRound(t testing.TB) (*Scheme, map[string]any) {
	body := make([]Field, 65)
	row := map[string]any{"n": 65_535}
	for i := range body {
		name := "m" + strconv.Itoa(i)
		body[i] = U8(i+1, name)
		row[name] = 1
	}
	return mustScheme(t, 1, append([]Field{U32(0, "n")}, Times(1, 0, body...))...), row
}

func TestAC1WithTheRoundLimitsRaisedTheByteBudgetStillStopsALoneScalar(t *testing.T) {
	// Arrange
	layout := limited(t, timesK32(t), func(l *Limits) { l.MaxRounds, l.MaxSlots, l.MaxBytes = math.MaxInt, math.MaxInt, 20 })

	// Act / Assert
	refusedPack(t, layout, map[string]any{"n": uint32(4_000_000_000), "k": 7},
		"k: the packet would be 21 bytes, above the limit of 20 bytes")
}
