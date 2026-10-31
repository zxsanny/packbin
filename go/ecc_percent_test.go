package packbin

import (
	"bytes"
	"strings"
	"testing"
	"time"
)

// Parity percentage (AZ-3504; contract message-ecc 1.1.0): setting, bytes, round trip, repair, limits, dispatch.

func percentScheme(t testing.TB, s *Scheme, p int) *Scheme {
	t.Helper()
	c, err := s.WithParityPercent(p)
	if err != nil {
		t.Fatalf("WithParityPercent(%d): %v", p, err)
	}
	return c
}

// blobScheme is a scheme whose clear message is length bytes (the type byte and a Bytes field); length >= 1.
func blobScheme(t testing.TB, typeNumber, length int) *Scheme {
	t.Helper()
	return mustScheme(t, typeNumber, Bytes(0, "b", length-1))
}

// wantCount is the count of the contract, with its own integer formula.
func wantCount(p, length int) int {
	n := 0
	for n < 32 && n*100 < p*length {
		n++
	}
	return n
}

func TestPercentSetterReportsAndLastSetterWins(t *testing.T) {
	// Arrange
	base := positionMapScheme(t)

	// Act
	a := percentScheme(t, base, 25)
	b, errB := a.WithParity(4)
	c, errC := b.WithParityPercent(10)

	// Assert
	if errB != nil || errC != nil {
		t.Fatal(errB, errC)
	}
	if a.ParityPercent() != 25 || a.Parity() != 0 || b.ParityPercent() != 0 || b.Parity() != 4 ||
		c.ParityPercent() != 10 || c.Parity() != 0 || base.ParityPercent() != 0 {
		t.Fatalf("settings: %d/%d %d/%d %d/%d", a.ParityPercent(), a.Parity(), b.ParityPercent(), b.Parity(), c.ParityPercent(), c.Parity())
	}
	var nilScheme *Scheme
	if nilScheme.ParityPercent() != 0 {
		t.Fatal("a nil scheme has a percentage")
	}
}

func TestPercentSetterRefusesOutsideZeroToHundred(t *testing.T) {
	for _, p := range []int{-1, 101, 1000} {
		// Act
		s, err := positionMapScheme(t).WithParityPercent(p)

		// Assert
		e := asError(t, err, InvalidScheme)
		if s != nil || !strings.Contains(e.Reason, "100") {
			t.Fatalf("p=%d: scheme %v, reason %q", p, s, e.Reason)
		}
	}
	if _, err := (*Scheme)(nil).WithParityPercent(5); err == nil {
		t.Fatal("a nil scheme took a percentage")
	}
}

func TestPercentOtherLimitSettersKeepThePercentage(t *testing.T) {
	// Arrange
	s := percentScheme(t, positionMapScheme(t), 20)

	// Act
	l, err := s.WithLimits(DefaultLimits())

	// Assert
	if err != nil || l.ParityPercent() != 20 {
		t.Fatalf("limits setter: %v, percent %d", err, l.ParityPercent())
	}
}

func TestPercentCountAndBytesMatchTheFixedCountScheme(t *testing.T) {
	for _, p := range []int{0, 10, 25, 50, 100} {
		for _, length := range []int{1, 3, 10, 40, 100, 222} {
			// Arrange
			clear := blobScheme(t, 7, length)
			row := map[string]any{"b": bytes.Repeat([]byte{0x5a}, length-1)}
			n := wantCount(p, length)
			if n != percentCount(p, length) {
				t.Fatalf("percentCount(%d,%d) = %d, want %d", p, length, percentCount(p, length), n)
			}
			fixed := withParity(t, clear, n)

			// Act
			got, err := Pack(percentScheme(t, clear, p), row)
			want, werr := Pack(fixed, row)

			// Assert
			if err != nil || werr != nil || !bytes.Equal(got, want) || len(got) != length+n {
				t.Fatalf("p=%d L=%d: %x %v vs %x %v", p, length, got, err, want, werr)
			}
		}
	}
}

func TestPercentLargestMessageAndOneAboveIsTooLong(t *testing.T) {
	for p, largest := range map[int]int{1: 251, 10: 230, 25: 222, 50: 222, 100: 222} {
		// Arrange
		if largestClear(p) != largest {
			t.Fatalf("largestClear(%d) = %d, want %d", p, largestClear(p), largest)
		}
		s := percentScheme(t, blobScheme(t, 1, largest+1), p)

		// Act
		out, err := Pack(s, map[string]any{"b": make([]byte, largest)})

		// Assert
		e := asError(t, err, PackRefused)
		if out != nil || !strings.Contains(e.Reason, "above the limit of") {
			t.Fatalf("p=%d: %x, reason %q", p, out, e.Reason)
		}
	}
	// Percentage 0 has no limit, as a count of 0.
	s := percentScheme(t, blobScheme(t, 1, 254), 0)
	if out, err := Pack(s, map[string]any{"b": make([]byte, 253)}); err != nil || len(out) != 254 {
		t.Fatalf("p=0 at 254: %d, %v", len(out), err)
	}
}

func TestPercentRoundTripEveryPair(t *testing.T) {
	pairs := 0
	for p := 0; p <= 100; p++ {
		last := 254
		if p > 0 {
			last = largestClear(p)
		}
		for length := 0; length <= last; length++ {
			pairs++
			// Arrange
			plain := make([]byte, length)
			for i := range plain {
				plain[i] = byte(i*7 + p)
			}
			n := wantCount(p, length)

			// Act
			sent, err := protectPercent(plain, p)
			clear, repaired, rerr := repairPercent(sent, p, 0)

			// Assert
			if err != nil || len(sent) != length+n || rerr != nil || repaired != 0 || !bytes.Equal(clear, plain) {
				t.Fatalf("p=%d L=%d: sent %d (%v), clear ok %v, %d, %v", p, length, len(sent), err, bytes.Equal(clear, plain), repaired, rerr)
			}
			if length == 0 {
				continue
			}
			s := percentScheme(t, blobScheme(t, 3, length), p)
			packed, err := Pack(s, map[string]any{"b": plain[1:]})
			if err != nil {
				t.Fatalf("p=%d L=%d: pack %v", p, length, err)
			}
			row, repaired, err := UnpackMapRepair(packed, 0, s)
			if err != nil || repaired != 0 || !bytes.Equal(row["b"].([]byte), packed[1:length]) {
				t.Fatalf("p=%d L=%d: unpack %v, %d, %v", p, length, row, repaired, err)
			}
		}
	}
	if pairs != 22752+0 {
		t.Fatalf("pairs = %d, want 22752", pairs)
	}
}

func TestPercentImpossibleLengthIsUncorrectableAndABufferAbove254IsTooLong(t *testing.T) {
	// Arrange: at 1 percent a sent length of 1 gives no clear length.
	s := percentScheme(t, positionMapScheme(t), 1)

	// Act
	row, repaired, err := UnpackRepair([]byte{0x40}, 0, s)
	_, _, errLong := UnpackRepair(make([]byte, 255), 0, s)
	_, _, errZero := UnpackRepair(make([]byte, 255), 0, percentScheme(t, positionMapScheme(t), 0))

	// Assert
	if e := asError(t, err, Uncorrectable); e.Field != NoField || e.Name != "" {
		t.Fatalf("names a field: %+v", e)
	}
	if row != nil || repaired != 0 {
		t.Fatalf("row %v, repaired %d", row, repaired)
	}
	asError(t, errLong, TooLong)
	if errZero == nil {
		t.Fatal("255 zero bytes were read as a position")
	}
	asError(t, errZero, UnknownType)
}

func TestPercentRepairUsesTheCountOfThatMessage(t *testing.T) {
	for _, c := range []struct{ p, n, bad int }{{50, 20, 10}, {25, 10, 5}} {
		// Arrange
		plain := bytes.Repeat([]byte{0x11, 0x22}, 20)
		sent, err := protectPercent(plain, c.p)
		if err != nil || len(sent) != 40+c.n {
			t.Fatal(len(sent), err)
		}
		positions, values := pickWrong(newRand(uint64(c.p)), len(sent), c.bad)

		// Act
		got, repaired, err := repairPercent(corrupt(sent, positions, values), c.p, c.bad)

		// Assert
		if err != nil || repaired != c.bad || !bytes.Equal(got, plain) {
			t.Fatalf("p=%d: %v, repaired %d", c.p, err, repaired)
		}
	}
}

func TestPercentLimitOutsideSixteenIsBadLimitAndAHighLimitIsLowered(t *testing.T) {
	// Arrange: 40 clear bytes at 25 percent: 10 parity bytes, limit lowered to 5.
	plain := bytes.Repeat([]byte{0x33}, 40)
	sent, _ := protectPercent(plain, 25)
	positions, values := pickWrong(newRand(9), len(sent), 5)
	damaged := corrupt(sent, positions, values)

	// Act
	_, _, low := repairPercent(damaged, 25, -1)
	_, _, high := repairPercent(damaged, 25, 17)
	got, repaired, err := repairPercent(damaged, 25, 16)

	// Assert
	asError(t, low, InvalidScheme)
	asError(t, high, InvalidScheme)
	if err != nil || repaired != 5 || !bytes.Equal(got, plain) {
		t.Fatalf("limit 16: %v, %d", err, repaired)
	}
	more, mv := pickWrong(newRand(10), len(sent), 6)
	if _, _, err := repairPercent(corrupt(sent, more, mv), 25, 16); err == nil {
		t.Fatal("six wrong bytes with a lowered limit of 5 were accepted as repaired")
	}
}

func TestPercentZeroKeepsTheLimitRuleOfCountZero(t *testing.T) {
	// Arrange
	s := percentScheme(t, positionMapScheme(t), 0)
	message, _ := Pack(s, goldenMap())

	// Act
	_, _, above := UnpackRepair(message, 1, s)
	_, _, ok := UnpackRepair(message, 0, s)

	// Assert
	asError(t, above, InvalidScheme)
	if ok != nil {
		t.Fatal(ok)
	}
}

func TestPercentDispatchSharesOneSetting(t *testing.T) {
	// Arrange
	a, b := mustScheme(t, 1, U8(0, "x")), mustScheme(t, 2, U8(0, "y"))
	same := []*Scheme{percentScheme(t, a, 30), percentScheme(t, b, 30)}
	message, err := Pack(same[1], map[string]any{"y": 9})
	if err != nil {
		t.Fatal(err)
	}

	// Act
	row, _, ok := UnpackMapRepair(message, 0, same...)
	_, _, twoPercents := UnpackRepair(message, 0, percentScheme(t, a, 30), percentScheme(t, b, 31))
	_, _, mixed := UnpackRepair(message, 0, percentScheme(t, a, 30), withParity(t, b, 3))
	plainMessage, _ := Pack(b, map[string]any{"y": 9})
	_, _, zeroAndCount := UnpackRepair(plainMessage, 0, percentScheme(t, a, 0), withParity(t, b, 0))

	// Assert
	if ok != nil || row["y"] != uint8(9) {
		t.Fatalf("%v %v", row, ok)
	}
	asError(t, twoPercents, InvalidScheme)
	asError(t, mixed, InvalidScheme)
	if zeroAndCount != nil {
		t.Fatalf("percentage 0 and count 0 are the same setting: %v", zeroAndCount)
	}
}

func TestPercentFixedCountSchemesKeepTheirBytes(t *testing.T) {
	// Arrange
	s := positionParity(t, 8)

	// Act
	message, err := Pack(s, goldenMap())
	row, repaired, rerr := readPosition(t, message, 8, 4)

	// Assert
	if err != nil || rerr != nil || repaired != 0 || !isPosition(row) || len(message) < 8 {
		t.Fatal(err, rerr)
	}
}

func TestPercentUnpackFindsTheCountWithinTheSpeedBound(t *testing.T) {
	// Arrange
	s := percentScheme(t, blobScheme(t, 1, 222), 100)
	message, err := Pack(s, map[string]any{"b": make([]byte, 221)})
	if err != nil {
		t.Fatal(err)
	}
	factor := loadFactor()

	// Act
	start := time.Now()
	for range 1000 {
		if _, _, err := UnpackMapRepair(message, 0, s); err != nil {
			t.Fatal(err)
		}
	}
	elapsed := time.Since(start)

	// Assert
	assertWithin(t, "1000 percentage unpacks", elapsed, time.Second, factor)
}
