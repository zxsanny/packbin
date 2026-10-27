package packbin

import (
	"bytes"
	"fmt"
	"strings"
	"testing"
)

// The scheme setting, a compact text field and the dispatch rule of message ECC: AZ-2685 AC-1, AC-2 (EC-1,
// EC-2, EC-3) and AC-6 (EC-11, EC-16).

func TestEccSchemeDeclaresNoParityUnlessToldAndWithLimitsKeepsIt(t *testing.T) {
	// Arrange
	plain := mustScheme(t, 1, U8(0, "a"))

	// Act
	protected := withParity(t, plain, 4)
	limited, err := protected.WithLimits(Limits{MaxRounds: 1, MaxSlots: 1, MaxBytes: 100})

	// Assert
	if err != nil || plain.Parity() != 0 || protected.Parity() != 4 || limited.Parity() != 4 {
		t.Fatalf("parity %d %d %d, %v", plain.Parity(), protected.Parity(), limited.Parity(), err)
	}
	var none *Scheme
	if none.Parity() != 0 {
		t.Fatalf("a nil scheme has parity %d", none.Parity())
	}
}

func TestEccSchemeWithParityNamesTheCountAnd32(t *testing.T) {
	for _, n := range []int{33, -1, 1000} {
		// Act
		s, err := positionMapScheme(t).WithParity(n)

		// Assert
		e := asError(t, err, InvalidScheme)
		if s != nil || !strings.Contains(e.Reason, "32") || !strings.Contains(e.Reason, fmt.Sprint(n)) {
			t.Errorf("n=%d: scheme %v, reason %q", n, s, e.Reason)
		}
	}
}

func TestEccSchemeWithParityRefusesAnUnusableScheme(t *testing.T) {
	// Act
	_, nilErr := (*Scheme)(nil).WithParity(2)
	_, zeroErr := (&Scheme{}).WithParity(2)

	// Assert
	asError(t, nilErr, InvalidScheme)
	asError(t, zeroErr, InvalidScheme)
}

func TestEccSchemeWithParityLeavesTheOriginalAndPacksTheSameFields(t *testing.T) {
	// Arrange
	plain := positionMapScheme(t)

	// Act
	protected := withParity(t, plain, 8)
	clearBytes, clearErr := Pack(plain, goldenMap())
	protectedBytes, protectedErr := Pack(protected, goldenMap())

	// Assert
	if clearErr != nil || protectedErr != nil || plain.Parity() != 0 {
		t.Fatalf("%v %v parity %d", clearErr, protectedErr, plain.Parity())
	}
	if !bytes.Equal(protectedBytes[:len(clearBytes)], clearBytes) || len(protectedBytes) != len(clearBytes)+8 {
		t.Fatalf("clear %x protected %x", clearBytes, protectedBytes)
	}
}

func TestEccSchemePositionRowsTwoToSixPackTheReportBytes(t *testing.T) {
	for n, parity := range map[int]string{
		1: "ab", 2: "16bd", 4: "ca856682", 8: "6d4f38479f3f2472", 16: "4ace66ecd5e4a28ffa28098279f5f19d",
	} {
		// Act
		got := hexOf(packedPosition(t, n))

		// Assert
		if got != expectedHex+parity {
			t.Errorf("n=%d: %s, want %s", n, got, expectedHex+parity)
		}
	}
	if got := hexOf(packedPosition(t, 0)); got != expectedHex {
		t.Errorf("n=0: %s, want %s", got, expectedHex)
	}
}

func TestEccSchemeUnpackWithoutRepairDetectsAndAcceptsAnIntactMessage(t *testing.T) {
	// Arrange
	s := positionParity(t, 4)
	message := packedPosition(t, 4)

	// Act
	row, err := UnpackMap(message, s)
	typed, typedErr := Unpack(corrupt(message, []int{2}, []byte{1}), s)

	// Assert
	if err != nil || !isPosition(row) {
		t.Fatalf("intact: %v, %v", row, err)
	}
	asError(t, typedErr, Uncorrectable)
	if typed != nil {
		t.Fatalf("a wrong byte returned the row %v", typed)
	}
}

type note struct {
	id   uint8
	text string
	tail uint16
}

func noteScheme(t testing.TB, n int) *Scheme {
	t.Helper()
	return withParity(t, mustScheme(t, 0x21,
		Bind(U8(0, "id"), func(r *note) uint8 { return r.id }, func(r *note, v uint8) { r.id = v }),
		Bind(Utf8(1, "text"), func(r *note) string { return r.text }, func(r *note, v string) { r.text = v }),
		Bind(U16(2, "tail"), func(r *note) uint16 { return r.tail }, func(r *note, v uint16) { r.tail = v }),
	), n)
}

func TestEccTextN4AnyTwoWrongBytesReturnTheOriginalRowAndString(t *testing.T) {
	// Arrange
	s := noteScheme(t, 4)
	want := note{id: 7, text: "packbin ecc 0123456789", tail: 4660}
	message, err := Pack(s, &want)
	if err != nil {
		t.Fatal(err)
	}
	rng := newRand(11)
	cases, wrong := 0, 0

	// Act
	for a := range message {
		for b := a + 1; b < len(message); b++ {
			for range 6 {
				row, repaired, err := UnpackRepair(corrupt(message, []int{a, b}, []byte{byte(1 + rng.IntN(255)), byte(1 + rng.IntN(255))}), 2, s)
				got, ok := row.(*note)
				cases++
				if err != nil || repaired != 2 || !ok || *got != want {
					wrong++
				}
			}
		}
	}

	// Assert
	if cases <= 1000 || wrong != 0 {
		t.Fatalf("%d cases, %d wrong", cases, wrong)
	}
}

func TestEccTextDetectOnlyAWrongByteInTheStringIsRefused(t *testing.T) {
	// Arrange
	s := noteScheme(t, 4)
	message, err := Pack(s, &note{id: 7, text: "packbin ecc 0123456789", tail: 4660})
	if err != nil {
		t.Fatal(err)
	}

	// Act
	row, uerr := Unpack(corrupt(message, []int{4}, []byte{0x10}), s)

	// Assert
	asError(t, uerr, Uncorrectable)
	if row != nil {
		t.Fatalf("row %v", row)
	}
}

func TestEccTextAnInvalidStringIsRefusedAsBeforeAfterTheRepair(t *testing.T) {
	// Arrange: a string of raw UTF-8 holding a lone 0xff byte, protected as it is.
	clear := []byte{0x22, 0x02, 0x10, 0xff}
	s := withParity(t, mustScheme(t, 0x22, Utf8(0, "s")), 4)
	protectedBytes, err := protect(clear, 4)
	if err != nil {
		t.Fatal(err)
	}
	_, want := UnpackMap(clear, mustScheme(t, 0x22, Utf8(0, "s")))
	wantErr := asError(t, want, ShortPacket)

	// Act
	_, _, intact := UnpackMapRepair(protectedBytes, 2, s)
	_, repaired, afterRepair := UnpackMapRepair(corrupt(protectedBytes, []int{3}, []byte{0x21}), 2, s)

	// Assert
	for _, err := range []error{intact, afterRepair} {
		if e := asError(t, err, ShortPacket); e.Name != wantErr.Name || e.Needed != wantErr.Needed || e.Left != wantErr.Left {
			t.Errorf("error %+v, want %+v", e, wantErr)
		}
	}
	if repaired != 0 {
		t.Errorf("repaired %d with a refused row", repaired)
	}
}

func dispatchSchemes(t testing.TB, n int) []*Scheme {
	t.Helper()
	out := make([]*Scheme, 3)
	for i := range out {
		out[i] = withParity(t, mustScheme(t, 0x11+i, U16(0, "a"), U8(1, "b")), n)
	}
	return out
}

func TestEccDispatchTypeByteAmongOneToTwoWrongBytesReachesTheRightScheme(t *testing.T) {
	// Arrange
	rng := newRand(16)
	schemes := dispatchSchemes(t, 4)
	missed, wrongScheme := 0, 0

	// Act
	for i := range 1000 {
		which := i % 3
		message, err := Pack(schemes[which], map[string]any{"a": i, "b": which})
		if err != nil {
			t.Fatal(err)
		}
		positions, values := pickWrong(rng, len(message)-1, i%2)
		for k := range positions {
			positions[k]++
		}
		positions = append([]int{0}, positions...)
		values = append([]byte{byte(1 + rng.IntN(255))}, values...)
		row, repaired, err := UnpackMapRepair(corrupt(message, positions, values), 2, schemes...)
		if err != nil || repaired != len(positions) {
			missed++
		} else if row["a"] != uint16(i) || row["b"] != uint8(which) {
			wrongScheme++
		}
	}

	// Assert
	if missed != 0 || wrongScheme != 0 {
		t.Fatalf("%d missed, %d wrong", missed, wrongScheme)
	}
}

func TestEccDispatchSchemesWithDifferentParityAreRefusedNamingBothCounts(t *testing.T) {
	// Arrange
	four := dispatchSchemes(t, 4)[0]
	two := withParity(t, mustScheme(t, 0x21, U8(0, "a")), 2)
	plain := mustScheme(t, 0x22, U8(0, "a"))
	message, err := Pack(four, map[string]any{"a": 1, "b": 2})
	if err != nil {
		t.Fatal(err)
	}

	// Act
	_, _, mixed := UnpackMapRepair(message, 0, four, two)
	_, plainErr := Unpack(message, four, plain)

	// Assert
	for _, err := range []error{mixed, plainErr} {
		e := asError(t, err, InvalidScheme)
		if !strings.Contains(e.Reason, "4") || !(strings.Contains(e.Reason, "2") || strings.Contains(e.Reason, "0")) {
			t.Errorf("reason %q does not name both counts", e.Reason)
		}
	}
}

// AZ-2704: the checks run in one order in every package (no scheme, duplicate type, parity mix, limit): a
// repeated number is the refusal even when the list also mixes parity counts or the limit is bad.
func TestDuplicateTypeIsRefusedBeforeAParityMixAndABadLimit(t *testing.T) {
	// Arrange
	scheme := positionMapScheme(t)
	protected := withParity(t, scheme, 4)
	want := fmt.Sprintf("duplicate type number %d", scheme.typeNumber)

	// Act
	_, _, withMix := UnpackRepair(make([]byte, 8), 0, scheme, protected)
	_, _, withLimit := UnpackRepair(make([]byte, 8), 9, protected, protected)

	// Assert
	for name, err := range map[string]error{"with a parity mix": withMix, "with a bad limit": withLimit} {
		if e := asError(t, err, InvalidScheme); e.Reason != want {
			t.Fatalf("%s: reason %q, want %q", name, e.Reason, want)
		}
	}
}
