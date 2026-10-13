package packbin

import (
	"testing"
)

// AC-1: loop20-parity-pins (AZ-2356, AZ-2360, AZ-2363, AZ-2359) and times-count-zero-with-values
// (AZ-2335), row for row from the TypeScript tests. The split-bit rows that earlier Go tasks already
// pin are named in the batch report; these are the rows no Go test had.

const (
	skippedCountText = "pt: a value is given, but the count of its times is not written, so its bit is clear; " +
		"write the count before the times"
	timesCountZeroText = "pt: 2 items, times count 0"
)

// AZ-2356: a split bit whose times count is written after the flag byte.
func countAfterByte(t testing.TB) *Scheme {
	fb := FlagByte("fb")
	return mustScheme(t, 1, fb, U8(0, "n"), fb.Bit(Times(1, 0, U8(1, "pt"))))
}

// AZ-2360: a combined flags whose first member is the count of its second.
func combinedCount(t testing.TB) *Scheme {
	return mustScheme(t, 1, Flags(0, U8(0, "n"), Times(1, 0, U8(1, "pt"))))
}

// AZ-2363: a times inside a when inside a split bit; its count n sits under a when that is false for mode 1.
func timesInWhen(t testing.TB) *Scheme {
	fb := FlagByte("fb")
	return mustScheme(t, 1, U8(0, "mode"), When(1, Eq(0, 9), U8(1, "n")), fb,
		fb.Bit(When(2, Eq(0, 1), Times(2, 1, U8(2, "pt")))))
}

func timesInWhenConditionAfterByte(t testing.TB) *Scheme {
	fb := FlagByte("fb")
	return mustScheme(t, 1, fb, U8(0, "mode"), When(1, Eq(0, 9), U8(1, "n")),
		fb.Bit(When(2, Eq(0, 1), Times(2, 1, U8(2, "pt")))))
}

func TestAC1AZ2356SplitCountOfZeroWrittenAfterTheByte(t *testing.T) {
	runRefusals(t, []refusalCase{
		{"AC-1 with a list of values is refused naming the member", countAfterByte, gm("n", 0, "pt", []any{5, 6}), 1, "pt",
			timesCountZeroText},
	})
	runPacks(t, []packCase{
		{"AC-2 with a lone scalar packs zero rounds", countAfterByte, gm("n", 0, "pt", 5), "010000"},
	})
}

func TestAC1AZ2360CombinedFlagsTimesWhoseCountIsSkipped(t *testing.T) {
	underWhen := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, U8(0, "mode"),
			Flags(1, U8(1, "n"), When(2, Eq(0, 1), Times(2, 1, U8(2, "pt")))))
	}
	runRefusals(t, []refusalCase{
		{"AC-1 with values is refused naming the member", combinedCount, gm("pt", []any{5, 6}), 1, "pt", skippedCountText},
		{"AC-1 a lone scalar is a value too", combinedCount, gm("pt", 5), 1, "pt", "pt: a value is given"},
		{"a times under a when inside combined flags is refused the same way", underWhen, gm("mode", 1, "pt", []any{5}), 2, "pt",
			"pt: a value is given, but the count of its times is not written"},
	})
	runPacks(t, []packCase{
		{"AC-2 no values", combinedCount, gm(), "0100"},
		{"AC-2 an empty list", combinedCount, gm("pt", []any{}), "0100"},
		{"AC-2 the count written", combinedCount, gm("n", 2, "pt", []any{5, 6}), "0103020506"},
		{"a false when stays silent", underWhen, gm("mode", 0, "pt", []any{5}), "010000"},
	})
}

func TestAC1AZ2363TimesInAWhenInASplitBitItsCountNeverWritten(t *testing.T) {
	runRefusals(t, []refusalCase{
		{"AC-1 with values is refused naming the member", timesInWhen, gm("mode", 1, "pt", []any{5, 6}), 2, "pt", droppedBeforeByte},
		{"AC-1 the same with the when condition written after the byte", timesInWhenConditionAfterByte,
			gm("mode", 1, "pt", []any{5, 6}), 2, "pt", droppedBeforeByte},
	})
	runPacks(t, []packCase{
		{"AC-1 after the byte, no values", timesInWhenConditionAfterByte, gm("mode", 1), "010001"},
		{"AC-1 after the byte, a false condition", timesInWhenConditionAfterByte, gm("mode", 2, "pt", []any{5, 6}), "010002"},
	})
}

type level uint8

const levelHigh level = 200

type modeName string

// AZ-2359: a TypeScript numeric enum is a plain number at runtime; the Go counterpart is a named
// integer type, which packs as its integer. A string-valued enum member is not a number.
func TestAC1AZ2359NumericEnumMemberInAU8Slot(t *testing.T) {
	s := func(t testing.TB) *Scheme { return mustScheme(t, 1, U8(0, "level")) }
	runPacks(t, []packCase{{"AC-1 packs the integer's byte", s, gm("level", levelHigh), "01c8"}})
	runRefusals(t, []refusalCase{
		{"AC-1 a string-valued member is refused naming the field", s, gm("level", modeName("fast")), 0, "level", "for u8, got string"},
	})
}

// AZ-2335 (times-count-zero-with-values): a times count of 0 with values is an error naming the member.
func TestAC1AZ2335TimesCountZeroWithValuesNamesTheMember(t *testing.T) {
	plain := func(t testing.TB) *Scheme { return mustScheme(t, 1, U8(0, "n"), Times(1, 0, U8(1, "pt"))) }
	combined := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, U8(0, "n"), Flags(1, Times(1, 0, U8(1, "pt")), U16(2, "heading")))
	}
	twoNames := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, U8(0, "n"), Times(1, 0, U8(1, "pt"), U8(2, "pu")))
	}
	runRefusals(t, []refusalCase{
		{"AC-1 count 0 with one value (outside flags)", plain, gm("n", 0, "pt", []any{5}, "heading", 90), 1, "pt", "pt: 1 items, times count 0"},
		{"AC-1 count 0 with one value (inside flags)", combined, gm("n", 0, "pt", []any{5}, "heading", 90), 1, "pt",
			"pt: 1 items, times count 0"},
		{"the second of two names is the one named", twoNames, gm("n", 0, "pu", []any{6}), 2, "pu", "pu: 1 items, times count 0"},
	})
	runPacks(t, []packCase{
		{"AC-2 outside flags, no values", plain, gm("n", 0, "heading", 90), "0100"},
		{"AC-2 inside flags, no values", combined, gm("n", 0, "heading", 90), "0100025a00"},
		{"AC-2 outside flags, an empty list", plain, gm("n", 0, "pt", []any{}, "heading", 90), "0100"},
		{"AC-2 inside flags, an empty list", combined, gm("n", 0, "pt", []any{}, "heading", 90), "0100025a00"},
		{"a lone scalar with count 0 writes zero rounds", plain, gm("n", 0, "pt", 5), "0100"},
	})
}
