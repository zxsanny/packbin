package packbin

import "testing"

const loneBuffer = "a byte buffer in a repeat or times round needs a list with one buffer per round"

func timesBytes(t testing.TB) *Scheme {
	return mustScheme(t, 1, U8(0, "n"), Times(1, 0, Bytes(1, "b", 2)))
}

func repeatBytes(t testing.TB) *Scheme { return mustScheme(t, 1, Repeat(0, Bytes(0, "b", 2))) }

func timesSized(t testing.TB) *Scheme {
	return mustScheme(t, 1, U8(0, "n"), Times(1, 0, U8(1, "c"), Sized(2, "s", 1)))
}

// Lone-bytes-in-round (AZ-2332): one byte buffer given for a bytes or sized name of a round would reach
// every round, so it is refused naming the member; so is a lone []byte for bits or packed (TypeScript
// refuses a Uint8Array there as no list), and a buffer inside a group map given once for every round.
func TestLoneBufferInARoundIsRefused(t *testing.T) {
	groupWhen := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, U8(0, "n"), Times(1, 0, U8(1, "k"),
			Flags(2, Group(2, "g", When(2, Eq(1, 2), Bytes(2, "b", 2))))))
	}
	runRefusals(t, []refusalCase{
		{"bytes in a times", timesBytes, gm("n", 2, "b", []byte{1, 2}), 1, "b", "b: " + loneBuffer},
		{"bytes in a one-round times", timesBytes, gm("n", 1, "b", []byte{1, 2}), 1, "b", loneBuffer},
		{"bytes in a repeat", repeatBytes, gm("b", []byte{1, 2}), 0, "b", loneBuffer},
		{"sized whose length fits", timesSized, gm("n", 1, "c", 1, "s", []byte{9}), 2, "s", "s: " + loneBuffer},
		{"bits", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Repeat(0, U8(0, "c"), Bits(1, "v", 0)))
		}, gm("c", []any{3}, "v", []byte{1, 0, 1}), 1, "v", loneBuffer},
		{"in a group map given once", groupWhen, gm("n", 2, "k", []any{2, 2}, "g", gm("b", []byte{9, 9})), 2, "b", loneBuffer},
		{"a group member given flat (Go-4)", groupWhen, gm("n", 2, "k", []any{2, 2}, "b", []byte{9, 9}), 2, "b", "member of group g"},
	})
	runPacks(t, []packCase{
		{"times, a buffer a round", timesBytes, gm("n", 2, "b", []any{[]byte{1, 2}, []byte{3, 4}}), "010201020304"},
		{"repeat, a buffer a round", repeatBytes, gm("b", [][]byte{{1, 2}, {3, 4}}), "0101020304"},
		{"sized, a buffer a round", timesSized, gm("n", 2, "c", []any{1, 1}, "s", []any{[]byte{9}, []byte{8}}), "010201090108"},
		{"one round", timesBytes, gm("n", 1, "b", []any{[]byte{1, 2}}), "01010102"},
		{"bytes outside a round", func(t testing.TB) *Scheme { return mustScheme(t, 1, Bytes(0, "b", 2)) }, gm("b", []byte{1, 2}), "010102"},
		{"bits, a list a round", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Repeat(0, U8(0, "c"), Bits(1, "v", 0)))
		}, gm("c", []any{3, 1}, "v", []any{[]byte{1, 0, 1}, []int{1}}), "0103050101"},
	})
	if again := mustPack(t, timesBytes(t), mustUnpackMap(t, timesBytes(t), "010201020304")); again != "010201020304" {
		t.Fatalf("repack %s", again)
	}
}

// Count refusals name the member and the count: a negative packed count after the bias, a bits list
// of the wrong length, an item out of range.
func TestCountedValueRefusals(t *testing.T) {
	biased := func(t testing.TB) *Scheme { return mustScheme(t, 1, U8(0, "n"), Packed(1, 1, "p", 0, -1)) }
	signed := func(t testing.TB) *Scheme { return mustScheme(t, 1, I8(0, "n"), Packed(2, 1, "p", 0, -1)) }
	bits := func(t testing.TB) *Scheme { return mustScheme(t, 1, U8(0, "n"), Bits(1, "v", 0)) }
	runRefusals(t, []refusalCase{
		{"packed count 0 with bias -1", biased, gm("n", 0, "p", []int{}), 1, "p", "p: item count -1"},
		{"packed negative count with bias -1", signed, gm("n", -3, "p", []int{}), 1, "p", "p: item count -4"},
		{"packed list of the wrong length", biased, gm("n", 3, "p", []int{1}), 1, "p", "expected a list of 2 items for packed, got 1 items"},
		{"packed item out of range", signed, gm("n", 2, "p", []int{4}), 1, "p", "item 0 is 4; expected 0..3"},
		{"bits not a list", bits, gm("n", 1, "v", 1), 1, "v", "expected a list of 1 items for bits, got 1"},
		{"bits item 2", bits, gm("n", 1, "v", []int{2}), 1, "v", "expected 0..1"},
		{"bits item a float", bits, gm("n", 1, "v", []any{1.0}), 1, "v", "item 0 is 1"},
		{"sized not bytes", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, U8(0, "n"), Sized(1, "p", 0))
		}, gm("n", 1, "p", "a"), 1, "p", "expected []byte for sized, got string"},
		{"u2 slot missing", func(t testing.TB) *Scheme { return mustScheme(t, 1, U2(Slot(0, "a"), Slot(1, "b"))) },
			gm("a", 1), 1, "b", "expected a 2-bit integer 0..3, got nil"},
		{"u2 slot out of range", func(t testing.TB) *Scheme { return mustScheme(t, 1, U2(Slot(0, "a"))) },
			gm("a", 4), 0, "a", "got 4"},
	})
}
