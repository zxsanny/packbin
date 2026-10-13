package packbin

import (
	"errors"
	"math/rand/v2"
	"testing"
)

// hostileRoundSchemes are round and counted shapes for the no-panic sweeps: counts from u64, i64 and a
// u2 slot, groups and split bytes in rounds, a typed round.
func hostileRoundSchemes(t testing.TB) []*Scheme {
	fb := FlagByte("m")
	return []*Scheme{
		mustScheme(t, 1, U64(0, "n"), Sized(1, "p", 0), Packed(2, 2, "q", 0, -1), Times(3, 0, U8(3, "x"))),
		mustScheme(t, 1, I64(0, "n"), Bits(1, "b", 0), Times(2, 0, Flags(2, Bool(2, "on"), Group(3, "g", U16(3, "v"))))),
		mustScheme(t, 1, U2(Slot(0, "a"), Slot(1, "c")), Sized(2, "p", 1), Repeat(3, fb, fb.Bit(U8(3, "k")),
			fb.Bit(Group(4, "h", U8(4, "n"), Sized(5, "s", 4))), When(6, Eq(3, 1), U8(6, "w")))),
		mustScheme(t, 1, Flags(0, U8(0, "n"), Times(1, 0, U8(1, "pt"), Bits(2, "bb", 1)), Repeat(3, U8(3, "r")))),
		samplesScheme(t),
		routeScheme(t),
	}
}

var hostileNames = []string{"n", "p", "q", "x", "b", "on", "g", "v", "a", "c", "k", "h", "s", "w", "pt", "bb", "r", "mark"}

func hostileValue(r *rand.Rand, depth int) any {
	switch r.IntN(12) {
	case 0:
		return nil
	case 1:
		return r.IntN(5)
	case 2:
		return uint64(1) << 63
	case 3:
		return -1
	case 4:
		return []byte{1, 0}
	case 5:
		return "x"
	case 6:
		return true
	case 7:
		return 1.5
	}
	if depth > 1 {
		return r.IntN(3)
	}
	if r.IntN(2) == 0 {
		m := map[string]any{}
		for range r.IntN(3) {
			m[hostileNames[r.IntN(len(hostileNames))]] = hostileValue(r, depth+1)
		}
		return m
	}
	list := make([]any, r.IntN(4))
	for i := range list {
		list[i] = hostileValue(r, depth+1)
	}
	return list
}

// No input makes Unpack or Pack of a round or counted kind panic: random buffers and random map rows
// end in a row or an error value. Counts here stay small (the round limits are AZ-2444).
func TestRoundsNeverPanic(t *testing.T) {
	// Arrange
	schemes := hostileRoundSchemes(t)
	r := rand.New(rand.NewPCG(2442, 24))

	// Act and Assert: a panic fails the test.
	for _, s := range schemes {
		for range 3000 {
			buf := make([]byte, 1+r.IntN(24))
			buf[0] = 1
			for i := 1; i < len(buf); i++ {
				buf[i] = byte(r.IntN(4))
				if r.IntN(8) == 0 {
					buf[i] = 0xff
				}
			}
			// A packet pack would not write (a times bit clear beside a count above 0) can unpack to a
			// row pack refuses, as in TypeScript; either way the result is a value.
			if row, err := Unpack(buf, s); err == nil {
				if _, err := Pack(s, row); err != nil {
					asError(t, err, PackRefused)
				}
			} else {
				var e *Error
				if !errors.As(err, &e) {
					t.Fatalf("%x: %v", buf, err)
				}
			}
			if s.row != nil {
				continue
			}
			row := map[string]any{}
			for _, name := range hostileNames {
				if r.IntN(2) == 0 {
					row[name] = hostileValue(r, 0)
				}
			}
			if n, ok := row["n"].(uint64); ok && n > 8 {
				row["n"] = 2
			}
			if _, err := Pack(s, row); err != nil {
				asError(t, err, PackRefused)
			}
		}
	}
}
