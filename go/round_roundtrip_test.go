package packbin

import (
	"fmt"
	"testing"
)

// mulberry32 is the seeded generator of the TypeScript round-roundtrip test.
func mulberry32(seed uint32) func() float64 {
	a := seed
	return func() float64 {
		a += 0x6d2b79f5
		t := (a ^ a>>15) * (1 | a)
		t = (t + (t^t>>7)*(61|t)) ^ t
		return float64(t^t>>14) / 4294967296
	}
}

// The round-roundtrip shapes: each body is built so that each byte 0..3 is a canonical value of
// whatever reads it, so a packet that unpacks must repack to the same bytes. The TypeScript
// unanchored group is an anchored one here (Nested comes later); the bytes are the same.
func roundTripShapes() map[string]func(t testing.TB) *Scheme {
	return map[string]func(t testing.TB) *Scheme{
		"whenRepeat": whenRepeat,
		"boolFlags":  flagsRepeat,
		"groupInFlags": func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Repeat(0, U8(0, "k"), Flags(1, Group(1, "mark", U8(1, "g")), U16(2, "n"))))
		},
		"u2AndWhen": func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Repeat(0, U8(0, "k"), U2(Slot(1, "p"), Slot(2, "q")), When(3, Eq(0, 2), U8(3, "v"))))
		},
		"group": func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Repeat(0, U8(0, "k"), Group(1, "row", U8(1, "v"), When(2, Eq(1, 1), U8(2, "w")))))
		},
		"whenWithFlags": func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Repeat(0, U8(0, "k"), Flags(1, U8(1, "a"), U8(2, "b")),
				When(3, Eq(0, 1), Flags(3, U8(3, "c"), Bool(4, "d")))))
		},
		"splitFlagByte": func(t testing.TB) *Scheme {
			fb := FlagByte("m")
			return mustScheme(t, 1, Repeat(0, fb, fb.Bit(U8(0, "a")), fb.Bit(Bool(1, "b"))))
		},
		"countInRound": func(t testing.TB) *Scheme { return mustScheme(t, 1, Repeat(0, U8(0, "n"), Sized(1, "p", 0))) },
		"whenTimes": func(t testing.TB) *Scheme {
			return mustScheme(t, 1, U8(0, "a"), Times(1, 0, U8(1, "k"), When(2, Eq(1, 1), U8(2, "v")),
				Flags(3, U8(3, "f"), Bool(4, "g"))))
		},
		"flagsTimes": flagsTimes,
	}
}

// AC-2 (round-roundtrip): a packet that unpacks repacks to the same bytes, with one entry a round.
func TestAC2RandomRoundPacketsRepack(t *testing.T) {
	for name, build := range roundTripShapes() {
		t.Run(name, func(t *testing.T) {
			// Arrange
			s := build(t)
			rng := mulberry32(0x5eed)
			accepted, manyRounds := 0, 0

			// Act and Assert
			for range 3000 {
				body := make([]byte, int(rng()*14))
				for j := range body {
					body[j] = byte(rng() * 4)
				}
				wire := append([]byte{1}, body...)
				row, err := UnpackMap(wire, s)
				if err != nil {
					continue
				}
				accepted++
				again, err := Pack(s, row)
				if err != nil || hexOf(again) != hexOf(wire) {
					t.Fatalf("repack of %x: %x %v", wire, again, err)
				}
				sizes := map[int]bool{}
				longest := 0
				for _, v := range row {
					if list, ok := v.([]any); ok {
						sizes[len(list)] = true
						longest = max(longest, len(list))
					}
				}
				if len(sizes) > 1 {
					t.Fatalf("%x: lists of different lengths %v", wire, sizes)
				}
				if longest >= 2 {
					manyRounds++
				}
			}
			if accepted <= 200 || manyRounds <= 50 {
				t.Fatalf("accepted %d, many rounds %d", accepted, manyRounds)
			}
		})
	}
}

// A large packet keeps one entry a round for every name a round can hold.
func TestAC2LargeRepeatKeepsOneEntryPerRound(t *testing.T) {
	// Arrange
	body := make([]Field, 36)
	for i := range body {
		if i%2 == 0 {
			body[i] = U8(1+i, fmt.Sprintf("f%d", i))
		} else {
			body[i] = U16(1+i, fmt.Sprintf("f%d", i))
		}
	}
	s := mustScheme(t, 1, Repeat(0, U8(0, "k"), When(1, Eq(0, 1), body...)))
	const rounds = 28_000
	wire := make([]byte, 1+rounds)
	wire[0] = 1

	// Act
	row, err := UnpackMap(wire, s)

	// Assert
	if err != nil {
		t.Fatal(err)
	}
	for name, v := range row {
		if list, ok := v.([]any); !ok || len(list) != rounds {
			t.Fatalf("%s: %T", name, v)
		}
	}
	if len(row) != 37 {
		t.Fatalf("%d names", len(row))
	}
}
