package packbin

import (
	"reflect"
	"testing"
)

const droppedBeforeByte = "is not written before the flag byte, so its bit is clear"

func splitScheme(t testing.TB, fields func(m *FlagByteHandle) []Field) *Scheme {
	t.Helper()
	return mustScheme(t, 1, fields(FlagByte("m"))...)
}

// WS: the condition is written before the byte.
func splitWS(t testing.TB) *Scheme {
	return splitScheme(t, func(m *FlagByteHandle) []Field {
		return []Field{U8(0, "mode"), m, m.Bit(When(1, Eq(0, 1), U8(1, "speed"))), m.Bit(U16(2, "heading"))}
	})
}

func splitWhenAfter(t testing.TB) *Scheme {
	return splitScheme(t, func(m *FlagByteHandle) []Field {
		return []Field{m, U8(0, "mode"), m.Bit(When(1, Eq(0, 1), U8(1, "speed"))), m.Bit(U16(2, "heading"))}
	})
}

func splitWhenInBit(t testing.TB) *Scheme {
	return splitScheme(t, func(m *FlagByteHandle) []Field {
		return []Field{m, m.Bit(U8(0, "mode")), m.Bit(When(1, Eq(0, 1), U8(1, "speed"))), m.Bit(U16(2, "heading"))}
	})
}

// TS: the count is written before the byte.
func splitTS(t testing.TB) *Scheme {
	return splitScheme(t, func(m *FlagByteHandle) []Field {
		return []Field{U8(0, "n"), m, m.Bit(Times(1, 0, U8(1, "pt"))), m.Bit(U16(2, "heading"))}
	})
}

func splitTimesAfter(t testing.TB) *Scheme {
	return splitScheme(t, func(m *FlagByteHandle) []Field {
		return []Field{m, U8(0, "n"), m.Bit(Times(1, 0, U8(1, "pt"))), m.Bit(U16(2, "heading"))}
	})
}

func splitTimesSkipped(t testing.TB) *Scheme {
	return splitScheme(t, func(m *FlagByteHandle) []Field {
		return []Field{m, m.Bit(U8(0, "n")), m.Bit(Times(1, 0, U8(1, "pt"))), m.Bit(U16(2, "heading"))}
	})
}

func splitTimesInGroup(t testing.TB) *Scheme {
	return splitScheme(t, func(m *FlagByteHandle) []Field {
		return []Field{m, m.Bit(U8(0, "n")), m.Bit(Group(1, "g", Times(1, 0, U8(1, "pt")))), m.Bit(U16(2, "heading"))}
	})
}

// review B2/B7: a times under a when inside a split bit, its count in a bit of its own.
func splitTimesInWhen(t testing.TB) *Scheme {
	return splitScheme(t, func(m *FlagByteHandle) []Field {
		return []Field{U8(0, "mode"), m, m.Bit(U8(1, "n")), m.Bit(When(2, Eq(0, 1), Times(2, 1, U8(2, "pt"))))}
	})
}

// AC-2 (split-form-loud-pack, AZ-2331): a split flag byte pack refuses a body its bit cannot carry,
// naming the body member; a false condition stays a silent skip.
func TestAC2SplitFormLoudPack(t *testing.T) {
	combinedTimes := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, Flags(0, U8(0, "n"), Times(1, 0, U8(1, "pt"))))
	}
	runRefusals(t, []refusalCase{
		{"when condition after the byte", splitWhenAfter, gm("mode", 1, "speed", 7, "heading", 90), 1, "speed", droppedBeforeByte},
		{"when condition in an earlier bit", splitWhenInBit, gm("mode", 1, "speed", 7, "heading", 90), 1, "speed", droppedBeforeByte},
		{"times count after the byte", splitTimesAfter, gm("n", 2, "pt", []any{5, 6}, "heading", 90), 1, "pt", droppedBeforeByte},
		{"times count skipped", splitTimesSkipped, gm("pt", []any{5}, "heading", 90), 1, "pt", droppedBeforeByte},
		// The given group sets its bit, so its times finds no count (as TypeScript given {g: {pt: [5]}};
		// given pt flat, TypeScript refuses it as dropped before the byte).
		{"times count skipped, in a group", splitTimesInGroup, gm("g", gm("pt", []any{5}), "heading", 90), 1, "pt",
			"times: count n was not written"},
		{"split count rows: count 0 with a list", splitTS, gm("n", 0, "pt", []any{5}, "heading", 90), 1, "pt", "pt: 1 items, times count 0"},
		{"split count rows: short list", splitTS, gm("n", 2, "pt", []any{5}, "heading", 90), 1, "pt", "missing pt"},
		{"combined skipped count with values (AZ-2360)", combinedTimes, gm("pt", []any{5}), 1, "pt", "the count of its times is not written"},
		{"value out of range, when body", splitWS, gm("mode", 1, "speed", 300, "heading", 90), 1, "speed", "does not fit"},
		{"value out of range, times body", splitTS, gm("n", 1, "pt", []any{300}, "heading", 90), 1, "pt", "does not fit"},
		{"B2 skipped count under a when in a split bit", splitTimesInWhen, gm("mode", 1, "pt", []any{5}), 2, "pt", droppedBeforeByte},
	})
	runPacks(t, []packCase{
		{"no body after the byte", splitWhenAfter, gm("mode", 1, "heading", 90), "0102015a00"},
		{"no values after the byte", splitTimesAfter, gm("n", 0, "heading", 90), "0102005a00"},
		{"no count", splitTimesSkipped, gm("heading", 90), "01045a00"},
		{"false condition, source before", splitWS, gm("mode", 0, "speed", 7, "heading", 90), "0100025a00"},
		{"false condition, source after", splitWhenAfter, gm("mode", 0, "speed", 7, "heading", 90), "0102005a00"},
		{"reference true row", splitWS, gm("mode", 1, "speed", 7, "heading", 90), "010103075a00"},
		{"reference no body", splitWS, gm("mode", 1, "heading", 90), "0101025a00"},
		{"times 0", splitTS, gm("n", 0, "heading", 90), "0100025a00"},
		{"times 1", splitTS, gm("n", 1, "pt", []any{5}, "heading", 90), "010103055a00"},
		{"times 2", splitTS, gm("n", 2, "pt", []any{5, 6}, "heading", 90), "01020305065a00"},
		{"times only", splitTS, gm("n", 2, "pt", []any{5, 6}), "0102010506"},
		{"combined false when body", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, U8(0, "mode"), Flags(1, When(1, Eq(0, 1), U8(1, "speed")), U16(2, "heading")))
		}, gm("mode", 0, "speed", 7, "heading", 90), "0100025a00"},
		{"combined count skipped", combinedTimes, gm(), "0100"},
		{"combined count given", combinedTimes, gm("n", 2, "pt", []any{5, 6}), "0103020506"},
		{"B2 false condition", splitTimesInWhen, gm("mode", 0, "pt", []any{5}), "010000"},
		{"B7 empty list under a skipped count in a when", splitTimesInWhen, gm("mode", 1, "pt", []any{}), "010100"},
		{"B7 empty list, bare", splitTimesSkipped, gm("pt", []any{}, "heading", 90), "01045a00"},
	})
	ws := mustUnpackMap(t, splitWS(t), "0100025a00")
	ts := mustUnpackMap(t, splitTS(t), "01020305065a00")
	if !reflect.DeepEqual(ws, gm("mode", uint8(0), "heading", uint16(90))) ||
		!reflect.DeepEqual(ts, gm("n", uint8(2), "pt", u8List(5, 6), "heading", uint16(90))) {
		t.Fatalf("unpacked %v %v", ws, ts)
	}
}

// AC-2 (split-form-reference, AZ-2115): a when between the flag byte and its bit.
func TestAC2SplitFormReference(t *testing.T) {
	reference := func(t testing.TB) *Scheme {
		return splitScheme(t, func(m *FlagByteHandle) []Field {
			return []Field{U8(0, "sid"), m, When(1, Eq(0, 9), U8(1, "shape")), m.Bit(U16(2, "heading"))}
		})
	}
	runUnpackCases(t, []unpackCase{
		{"reference row", reference, gm("sid", 9, "shape", 4, "heading", 90), "010901045a00",
			gm("sid", uint8(9), "shape", uint8(4), "heading", uint16(90))},
		{"short row", reference, gm("sid", 1), "010100", gm("sid", uint8(1))},
	})
}

// AC-2 (loop21-parity-probes U4): a split-bit times with its count above 0 written after the byte and
// no body packs a clear bit; with a body it is refused.
func TestAC2U4SplitCountAfterTheByte(t *testing.T) {
	runPacks(t, []packCase{
		{"body absent", splitTimesAfter, gm("n", 2, "heading", 90), "0102025a00"},
		{"body empty", splitTimesAfter, gm("n", 2, "pt", []any{}, "heading", 90), "0102025a00"},
		{"count 0, body absent", splitTimesAfter, gm("n", 0, "heading", 90), "0102005a00"},
	})
	runRefusals(t, []refusalCase{
		{"body present", splitTimesAfter, gm("n", 2, "pt", []any{5, 6}, "heading", 90), 1, "pt", droppedBeforeByte},
	})
}
