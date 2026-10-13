package packbin

import (
	"bytes"
	"math"
	"reflect"
	"testing"
)

type countedKind struct {
	name   string
	member func() Field
	body   string
	field  string
	row    map[string]any // the member's value for count 3
	want   any            // what unpack gives for it
}

func countedKinds() []countedKind {
	return []countedKind{
		{"sized", func() Field { return Sized(1, "p", 0) }, "616263", "p", gm("p", []byte("abc")), []byte("abc")},
		{"packed", func() Field { return Packed(2, 1, "p", 0, 0) }, "24", "p", gm("p", []int{0, 1, 2}), []byte{0, 1, 2}},
		{"times", func() Field { return Times(1, 0, U8(1, "x")) }, "010203", "x", gm("x", []any{1, 2, 3}), u8List(1, 2, 3)},
	}
}

func withCount(row map[string]any, n any) map[string]any {
	out := gm("n", n)
	for k, v := range row {
		out[k] = v
	}
	return out
}

// AC-2 (u64-count): sized, packed and times counted by a u64 unpack and pack; a count no buffer can
// hold is an error value naming the member, never a panic.
func TestAC2U64Counts(t *testing.T) {
	for _, k := range countedKinds() {
		t.Run(k.name, func(t *testing.T) {
			// Arrange
			s := mustScheme(t, 1, U64(0, "n"), k.member())
			wire := "010300000000000000" + k.body

			// Act
			back := mustUnpackMap(t, s, wire)
			again := mustPack(t, s, back)
			fromRow := mustPack(t, s, withCount(k.row, uint64(3)))
			_, tooLarge := UnpackMap(mustHex(t, "01ffffffffffffffff"+k.body), s)
			_, past53 := UnpackMap(mustHex(t, "010000000000002000"+k.body), s)
			raw, packErr := Pack(s, withCount(k.row, uint64(1)<<53))

			// Assert
			if back["n"] != uint64(3) || !reflect.DeepEqual(back[k.field], k.want) || again != wire || fromRow != wire {
				t.Fatalf("back %v again %s from row %s", back, again, fromRow)
			}
			e := asError(t, tooLarge, ShortPacket)
			if e.Name != k.field || e.Needed != 0 || e.Left != len(k.body)/2 {
				t.Fatalf("2^64-1: %+v", e)
			}
			// 2^53 is a count in Go (TypeScript cannot read it exactly and refuses it as unreadable).
			if p := asError(t, past53, ShortPacket); p.Name != k.field {
				t.Fatalf("2^53: %+v", p)
			}
			if p := asError(t, packErr, PackRefused); raw != nil || p.Name != k.field {
				t.Fatalf("pack 2^53: %x %+v", raw, p)
			}
		})
	}
}

// TS-F4 rows of u64-count: an i64 count that is negative or too large is an error value on unpack and
// refused on pack.
func TestAC2I64Counts(t *testing.T) {
	counts := []struct {
		label string
		wire  string
		value int64
	}{{"-1", "ffffffffffffffff", -1}, {"i64 min", "0000000000000080", math.MinInt64}, {"2^63-1", "ffffffffffffff7f", math.MaxInt64}}
	for _, k := range countedKinds() {
		for _, c := range counts {
			t.Run(k.name+" "+c.label, func(t *testing.T) {
				// Arrange
				s := mustScheme(t, 1, I64(0, "n"), k.member())

				// Act
				row, err := UnpackMap(mustHex(t, "01"+c.wire+k.body), s)
				raw, packErr := Pack(s, withCount(k.row, c.value))

				// Assert
				e := asError(t, err, ShortPacket)
				if row != nil || e.Name != k.field {
					t.Fatalf("unpack %v %+v", row, e)
				}
				if c.value < 0 && (e.Needed != 0 || e.Left != len(k.body)/2) {
					t.Fatalf("a negative count is unreadable: %+v", e)
				}
				if p := asError(t, packErr, PackRefused); raw != nil || p.Field == NoField {
					t.Fatalf("pack %x %+v", raw, p)
				}
			})
		}
	}
	// The largest exact count reads as a count, so sized reports the bytes it lacks.
	s := mustScheme(t, 1, U64(0, "n"), Sized(1, "p", 0))
	_, err := UnpackMap(mustHex(t, "01ffffffffffff1f0061"), s)
	if e := asError(t, err, ShortPacket); e.Name != "p" || e.Needed != 1<<53-1 || e.Left != 1 {
		t.Fatalf("2^53-1: %+v", e)
	}
}

// AC-2 (when-on-written-values): counts and whens read what pack wrote in their scope.
func TestAC2CountsReadWhatPackWrote(t *testing.T) {
	sized := func(t testing.TB) *Scheme { return skipN(t, Sized(2, "data", 1)) }
	bits := func(t testing.TB) *Scheme { return skipN(t, Bits(2, "data", 1)) }
	packed := func(t testing.TB) *Scheme { return skipN(t, Packed(2, 2, "data", 1, 0)) }
	times := func(t testing.TB) *Scheme { return skipN(t, Times(2, 1, U8(2, "x"))) }
	runRefusals(t, []refusalCase{
		{"sized count skipped", sized, gm("p", 1, "n", 2, "data", []byte{1, 2}), 2, "data", "data: count n was not written"},
		{"bits count skipped", bits, gm("p", 1, "n", 2, "data", []int{1, 0}), 2, "data", "data: count n was not written"},
		{"packed count skipped", packed, gm("p", 1, "n", 2, "data", []int{1, 2}), 2, "data", "data: count n was not written"},
		{"times count skipped", times, gm("p", 1, "n", 2, "x", []any{1, 2}), 2, "x", "times: count n was not written"},
		{"count skipped in a round", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Repeat(0, U8(0, "k"), When(1, Eq(0, 1), U8(1, "n")), Packed(2, 2, "data", 1, 0)))
		}, gm("k", []any{0}, "n", []any{3}, "data", []any{[]int{1, 2, 3}}), 2, "data", "data: count n was not written"},
	})
	runPacks(t, []packCase{
		{"sized count written", sized, gm("p", 0, "n", 2, "data", []byte{7, 8}), "0100020708"},
		{"bits count written", bits, gm("p", 0, "n", 2, "data", []int{1, 0}), "01000201"},
		{"packed count written", packed, gm("p", 0, "n", 2, "data", []int{1, 2}), "01000209"},
		{"times count written", times, gm("p", 0, "n", 2, "x", []any{5, 6}), "0100020506"},
	})
	roundWhen := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, Repeat(0, U8(0, "k"), When(1, Eq(0, 1), U8(1, "a")), When(2, Eq(1, 5), U8(2, "b"))))
	}
	runUnpackCases(t, []unpackCase{
		{"a when on a field skipped in the round", roundWhen, gm("k", []any{0}, "a", []any{5}, "b", []any{3}), "0100",
			gm("k", u8List(0), "a", []any{nil}, "b", []any{nil})},
		{"a when on a field another when skipped", func(t testing.TB) *Scheme {
			return skipN(t, When(2, Eq(1, 0), U8(2, "v")))
		}, gm("p", 1, "n", 0, "v", 4), "0101", gm("p", uint8(1))},
	})
}

// AC-2 (when-on-written-values AC-2): a seeded chain of whens in a round reads back what was written.
func TestAC2RoundWhenChainReadsBack(t *testing.T) {
	rng := mulberry32(2198)
	pick := func(n int) int { return int(rng() * float64(n)) }
	for range 500 {
		s := mustScheme(t, 1, Repeat(0, U8(0, "a"),
			When(1, Eq(0, pick(3)), U8(1, "b")),
			When(2, Eq(pick(2), pick(3)), U8(2, "c"))))
		for range 20 {
			rounds := 1 + pick(3)
			list := func() []any {
				out := make([]any, rounds)
				for i := range out {
					out[i] = pick(3)
				}
				return out
			}
			row := gm("a", list(), "b", list(), "c", list())

			// Act
			wire, err := Pack(s, row)
			back, backErr := UnpackMap(wire, s)
			again, againErr := Pack(s, back)

			// Assert
			if err != nil || backErr != nil || againErr != nil || !bytes.Equal(again, wire) {
				t.Fatalf("%v -> %x: %v %v %v %x", row, wire, err, backErr, againErr, again)
			}
		}
	}
}
