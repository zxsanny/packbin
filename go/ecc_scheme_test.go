package packbin

import (
	"bytes"
	"fmt"
	"strings"
	"testing"
)

// The scheme setting, the session, a compact text field and the dispatch rule of message ECC: AZ-2685 AC-1,
// AC-2 (EC-1, EC-2, EC-3) and AC-6 (EC-10, EC-11, EC-16).

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

func TestEccSessionPayloadIsThePaddedClearMessagePlusNAndTheParityCoversThePaddedBytes(t *testing.T) {
	// Arrange
	opener, _ := sessionPair(t, sessionNonce(t))
	s := positionParity(t, 4)

	// Act
	payload, err := opener.Pack(s, goldenMap())

	// Assert
	if err != nil || len(payload) != 13+4 || hexOf(payload[:13]) != sessionCipherHex {
		t.Fatalf("payload %x, %v", payload, err)
	}
	want, perr := protect(payload[:13], 4)
	if perr != nil || !bytes.Equal(payload, want) {
		t.Fatalf("parity %x does not cover the padded bytes: want %x, %v", payload[13:], want, perr)
	}
}

func TestEccSessionN0KeepsThePayloadAsLongAsTheClearMessage(t *testing.T) {
	// Arrange
	opener, waiter := sessionPair(t, sessionNonce(t))
	s := positionParity(t, 0)

	// Act
	payload, err := opener.Pack(s, goldenMap())
	row, repaired, rerr := waiter.UnpackMapRepair(payload, 0, s)

	// Assert
	if err != nil || hexOf(payload) != sessionCipherHex || rerr != nil || repaired != 0 || !isPosition(row) {
		t.Fatalf("payload %x %v; row %v %d %v", payload, err, row, repaired, rerr)
	}
}

func TestEccSessionN4TwoWrongBytesAreRepairedBeforeThePadIsRemoved(t *testing.T) {
	// Arrange
	opener, waiter := sessionPair(t, sessionNonce(t))
	s := positionParity(t, 4)
	payload, err := opener.Pack(s, goldenMap())
	if err != nil {
		t.Fatal(err)
	}
	wrong := corrupt(payload, []int{2, 15}, []byte{0x80, 0x21})
	before := append([]byte(nil), wrong...)

	// Act
	row, repaired, rerr := waiter.UnpackMapRepair(wrong, 2, s)

	// Assert
	if rerr != nil || repaired != 2 || !isPosition(row) || !bytes.Equal(wrong, before) {
		t.Fatalf("row %v, %d, %v", row, repaired, rerr)
	}
}

func TestEccSessionTypedRowIsRecoveredThroughUnpackRepair(t *testing.T) {
	// Arrange
	opener, waiter := sessionPair(t, sessionNonce(t))
	s := withParity(t, positionTypedScheme(t), 4)
	payload, err := opener.Pack(s, goldenRow())
	if err != nil {
		t.Fatal(err)
	}

	// Act
	row, repaired, rerr := waiter.UnpackRepair(corrupt(payload, []int{0, 16}, []byte{0xff, 0x01}), 2, s)

	// Assert
	got, ok := row.(*Position)
	if rerr != nil || repaired != 2 || !ok || *got != *goldenRow() {
		t.Fatalf("row %v, %d, %v", row, repaired, rerr)
	}
}

func TestEccSessionThreeWrongBytesAreRefusedThenTheNextPayloadIsRead(t *testing.T) {
	// Arrange
	opener, waiter := sessionPair(t, sessionNonce(t))
	s := positionParity(t, 4)
	first := mustSessionPack(t, opener, s, goldenMap())
	second := mustSessionPack(t, opener, s, map[string]any{"sid": 9, "lat": 1, "lon": 2, "profile": 3})

	// Act
	refused, _, refusedErr := waiter.UnpackMapRepair(corrupt(first, []int{1, 5, 11}, []byte{1, 2, 3}), 2, s)
	next, repaired, nextErr := waiter.UnpackMapRepair(second, 2, s)

	// Assert
	asError(t, refusedErr, Uncorrectable)
	if refused != nil || nextErr != nil || repaired != 0 || next["sid"] != uint16(9) {
		t.Fatalf("refused %v; next %v, %d, %v", refused, next, repaired, nextErr)
	}
}

func TestEccSessionALimitAboveHalfNIsRefusedBeforeTheReceivePositionMoves(t *testing.T) {
	// Arrange
	opener, waiter := sessionPair(t, sessionNonce(t))
	s := positionParity(t, 4)
	payload, err := opener.Pack(s, goldenMap())
	if err != nil {
		t.Fatal(err)
	}

	// Act
	_, _, badErr := waiter.UnpackMapRepair(payload, 3, s)
	row, repaired, err := waiter.UnpackMapRepair(payload, 2, s)

	// Assert
	asError(t, badErr, InvalidScheme)
	if err != nil || repaired != 0 || !isPosition(row) {
		t.Fatalf("after the refusal: %v, %d, %v", row, repaired, err)
	}
}

func TestEccSessionAMessageAboveTheLimitIsRefusedAndTheSendPositionDoesNotMove(t *testing.T) {
	// Arrange
	opener, _ := sessionPair(t, sessionNonce(t))
	big := withParity(t, mustScheme(t, 0, Bytes(0, "b", 222)), 32)

	// Act
	refused, refusedErr := opener.Pack(big, map[string]any{"b": make([]byte, 222)})
	first, err := opener.Pack(positionParity(t, 0), goldenMap())

	// Assert
	asError(t, refusedErr, PackRefused)
	if refused != nil || err != nil || hexOf(first) != sessionCipherHex {
		t.Fatalf("refused %x; first %x, %v", refused, first, err)
	}
}

func TestEccSessionAProtectedPayloadReadWithoutRepairIsRefusedNotThrown(t *testing.T) {
	// Arrange
	opener, waiter := sessionPair(t, sessionNonce(t))
	payload, err := opener.Pack(positionParity(t, 4), goldenMap())
	if err != nil {
		t.Fatal(err)
	}

	// Act
	row, rerr := waiter.UnpackMap(payload, positionMapScheme(t))

	// Assert
	if row != nil || rerr == nil {
		t.Fatalf("row %v, %v", row, rerr)
	}
}

func TestEccSessionUnpackWithoutLimitDetectsAWrongByte(t *testing.T) {
	// Arrange
	opener, waiter := sessionPair(t, sessionNonce(t))
	s := positionParity(t, 2)
	payload, err := opener.Pack(s, goldenMap())
	if err != nil {
		t.Fatal(err)
	}

	// Act
	_, uerr := waiter.Unpack(corrupt(payload, []int{4}, []byte{9}), s)

	// Assert
	asError(t, uerr, Uncorrectable)
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
	opener, waiter := sessionPair(t, sessionNonce(t))
	payload := mustSessionPack(t, opener, four, map[string]any{"a": 1, "b": 2})
	_, sessionErr := waiter.UnpackMap(payload, four, two)
	after, _, afterErr := waiter.UnpackMapRepair(payload, 0, four)

	// Assert
	for _, err := range []error{mixed, plainErr, sessionErr} {
		e := asError(t, err, InvalidScheme)
		if !strings.Contains(e.Reason, "4") || !(strings.Contains(e.Reason, "2") || strings.Contains(e.Reason, "0")) {
			t.Errorf("reason %q does not name both counts", e.Reason)
		}
	}
	if afterErr != nil || after["a"] != uint16(1) {
		t.Fatalf("a refused call spent the receive position: %v, %v", after, afterErr)
	}
}

func mustSessionPack(t testing.TB, sess *PackSession, s *Scheme, row any) []byte {
	t.Helper()
	payload, err := sess.Pack(s, row)
	if err != nil {
		t.Fatalf("session Pack: %v", err)
	}
	return payload
}
