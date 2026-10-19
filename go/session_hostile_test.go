package packbin

import (
	"bytes"
	"errors"
	"strconv"
	"testing"
)

func allZero(b []byte) bool {
	for _, x := range b {
		if x != 0 {
			return false
		}
	}
	return true
}

func TestSessionLoadKeepsACopyAndThePacketUseWipesIt(t *testing.T) {
	// Arrange
	seed := sessionSeed()
	opener, waiter := mustLoad(t, seed), mustLoad(t, seed)
	heldByOpener, heldByWaiter := opener.seed, waiter.seed

	// Act
	_, errStart := opener.StartWith(sessionNonce(t))
	errJoin := waiter.Join(sessionNonce(t))

	// Assert: the caller's slice is its own (two sessions load the same one), the session's copy is wiped.
	if errStart != nil || errJoin != nil {
		t.Fatalf("%v %v", errStart, errJoin)
	}
	if !bytes.Equal(seed, sessionSeed()) {
		t.Fatal("the caller's seed was changed")
	}
	if !allZero(heldByOpener) || !allZero(heldByWaiter) || opener.seed != nil || waiter.seed != nil {
		t.Fatal("the seed was not wiped after Start and Join")
	}
}

func TestSessionLoadWithAWrongSeedLengthReturnsAnErrorValue(t *testing.T) {
	for _, n := range []int{0, 1, 31, 33, 64} {
		// Act
		s, err := LoadSession(make([]byte, n))

		// Assert
		if s != nil {
			t.Fatalf("%d bytes made a session", n)
		}
		asError(t, err, BadValue)
	}
	if s, err := LoadSession(nil); s != nil || !errors.Is(err, ErrBadValue) {
		t.Fatalf("nil seed: %v %v", s, err)
	}
}

func TestSessionOpenedOnceAndNotAgain(t *testing.T) {
	// Arrange
	nonce := sessionNonce(t)
	opened := func() *PackSession {
		s := mustLoad(t, sessionSeed())
		if _, err := s.StartWith(nonce); err != nil {
			t.Fatal(err)
		}
		return s
	}
	joined := mustLoad(t, sessionSeed())
	if err := joined.Join(nonce); err != nil {
		t.Fatal(err)
	}

	// Act and Assert
	s := opened()
	if out, err := s.Start(); out != nil {
		t.Fatalf("a second Start gave %x", out)
	} else {
		asError(t, err, BadValue)
	}
	asError(t, s.Join(nonce), BadValue)
	if out, err := s.StartWith(nonce); out != nil {
		t.Fatalf("a second StartWith gave %x", out)
	} else {
		asError(t, err, BadValue)
	}
	asError(t, joined.Join(nonce), BadValue)
	if out, err := joined.Start(); out != nil {
		t.Fatalf("Start after Join gave %x", out)
	} else {
		asError(t, err, BadValue)
	}
}

func TestSessionCallsOnNilAndZeroValuesAreErrorsNotPanics(t *testing.T) {
	// Arrange
	scheme := positionMapScheme(t)
	var nilSession *PackSession
	zero := &PackSession{}

	for _, s := range []*PackSession{nilSession, zero} {
		// Act and Assert
		if out, err := s.Start(); out != nil || err == nil {
			t.Fatalf("Start: %x %v", out, err)
		}
		if out, err := s.StartWith(sessionNonce(t)); out != nil || err == nil {
			t.Fatalf("StartWith: %x %v", out, err)
		}
		if err := s.Join(sessionNonce(t)); err == nil {
			t.Fatal("Join of a session without a seed")
		}
		if out, err := s.Pack(scheme, goldenMap()); out != nil {
			t.Fatalf("Pack: %x", out)
		} else {
			asError(t, err, PackRefused)
		}
		if row, err := s.Unpack(mustHex(t, expectedHex), scheme); row != nil {
			t.Fatalf("Unpack: %v", row)
		} else {
			asError(t, err, ShortPacket)
		}
		if row, err := s.UnpackMap(mustHex(t, expectedHex), scheme); row != nil {
			t.Fatalf("UnpackMap: %v", row)
		} else {
			asError(t, err, ShortPacket)
		}
	}
}

func TestSessionUnpackBeforeJoinIsTheShortPacketOfAnEmptyBuffer(t *testing.T) {
	// Arrange
	loaded := mustLoad(t, sessionSeed())

	// Act
	_, err := loaded.Unpack(mustHex(t, sessionCipherHex), positionMapScheme(t))

	// Assert
	e := asError(t, err, ShortPacket)
	if e.Field != NoField || e.Needed != 1 || e.Left != 0 {
		t.Fatalf("%+v", e)
	}
}

func TestSessionPackThatFailsSpendsNoPosition(t *testing.T) {
	// Arrange
	opener := mustLoad(t, sessionSeed())
	if _, err := opener.StartWith(sessionNonce(t)); err != nil {
		t.Fatal(err)
	}
	scheme := positionMapScheme(t)

	// Act
	failures := make([]error, 0, 3)
	for _, row := range []any{nil, map[string]any{"sid": 1}, "not a row"} {
		out, err := opener.Pack(scheme, row)
		if out != nil {
			t.Fatalf("a failed pack gave %x", out)
		}
		failures = append(failures, err)
	}
	_, nilScheme := opener.Pack(nil, goldenMap())
	payload, err := opener.Pack(scheme, goldenMap())

	// Assert
	for _, f := range append(failures, nilScheme) {
		asError(t, f, PackRefused)
	}
	if err != nil || hexOf(payload) != sessionCipherHex {
		t.Fatalf("the packet after the failures is %s, err %v", hexOf(payload), err)
	}
}

func TestSessionUnpackThatCannotBeReadAdvancesAndTheNextMessageUnpacks(t *testing.T) {
	// Arrange: the TypeScript hostile session row. The sender writes 01 00 05; the receiver's scheme
	// for type 1 ends after k, so clear unpack says TrailingBytes(1). A valid type-2 message follows.
	opener, waiter := sessionPair(t, sessionNonce(t))
	sender := mustScheme(t, 1, U8(0, "k"), U8(1, "extra"))
	receiver := mustScheme(t, 1, U8(0, "k"))
	next := mustScheme(t, 2, U8(0, "k"))
	hostile, err := opener.Pack(sender, map[string]any{"k": 0, "extra": 5})
	if err != nil {
		t.Fatal(err)
	}
	fine, err := opener.Pack(next, map[string]any{"k": 7})
	if err != nil {
		t.Fatal(err)
	}
	_, clearErr := Unpack(mustHex(t, "010005"), receiver)

	// Act
	first, firstErr := waiter.Unpack(hostile, receiver, next)
	second, secondErr := waiter.UnpackMap(fine, receiver, next)

	// Assert
	want := asError(t, clearErr, TrailingBytes)
	got := asError(t, firstErr, TrailingBytes)
	if first != nil || got.Left != want.Left {
		t.Fatalf("session gave %v, %+v; clear gave %+v", first, got, want)
	}
	if secondErr != nil || second["k"] != uint8(7) {
		t.Fatalf("the next message: %v, %v", second, secondErr)
	}
}

func TestSessionShortAndUnknownPayloadsAreErrorValues(t *testing.T) {
	// Arrange
	scheme := positionMapScheme(t)
	cases := []struct {
		name    string
		payload []byte
		kind    Kind
	}{
		{"nil payload", nil, ShortPacket},
		{"empty payload", []byte{}, ShortPacket},
		{"one byte", []byte{0x00}, -1},
		{"a payload cut after the type", mustHex(t, sessionCipherHex)[:3], ShortPacket},
		{"a payload with a tail", append(mustHex(t, sessionCipherHex), 1, 2, 3), TrailingBytes},
	}
	for _, c := range cases {
		_, waiter := sessionPair(t, sessionNonce(t))

		// Act
		row, err := waiter.Unpack(c.payload, scheme)

		// Assert
		if row != nil || err == nil {
			t.Fatalf("%s: %v %v", c.name, row, err)
		}
		var e *Error
		if !errors.As(err, &e) {
			t.Fatalf("%s: not an *Error: %v", c.name, err)
		}
		if c.kind != -1 && e.Kind != c.kind {
			t.Fatalf("%s: kind %v", c.name, e.Kind)
		}
	}
}

func TestSessionUnpackLeavesTheCallersPayloadAlone(t *testing.T) {
	// Arrange
	opener, waiter := sessionPair(t, sessionNonce(t))
	scheme := positionMapScheme(t)
	payload, err := opener.Pack(scheme, goldenMap())
	if err != nil {
		t.Fatal(err)
	}
	before := append([]byte(nil), payload...)

	// Act
	_, err = waiter.UnpackMap(payload, scheme)

	// Assert
	if err != nil || !bytes.Equal(payload, before) {
		t.Fatalf("payload changed to %x (err %v)", payload, err)
	}
}

func TestSessionUnusableSchemeListIsRefusedWithoutSpendingAPosition(t *testing.T) {
	// Arrange
	opener, waiter := sessionPair(t, sessionNonce(t))
	scheme := positionMapScheme(t)
	payload, err := opener.Pack(scheme, goldenMap())
	if err != nil {
		t.Fatal(err)
	}
	lists := map[string][]*Scheme{"none": nil, "a nil scheme": {nil}, "a repeated number": {scheme, scheme}}

	// Act and Assert
	for name, list := range lists {
		row, err := waiter.Unpack(payload, list...)
		if row != nil {
			t.Fatalf("%s: row %v", name, row)
		}
		asError(t, err, InvalidScheme)
		mapRow, err := waiter.UnpackMap(payload, list...)
		if mapRow != nil {
			t.Fatalf("%s: map row %v", name, mapRow)
		}
		asError(t, err, InvalidScheme)
	}
	row, err := waiter.UnpackMap(payload, scheme)
	if err != nil || goldenFieldMismatches(row) != 0 {
		t.Fatalf("the packet after the refused calls: %v %v", row, err)
	}
}

func TestSessionPackAndUnpackWithTypedRowsRefuseWrongRowTypes(t *testing.T) {
	// Arrange
	opener, waiter := sessionPair(t, sessionNonce(t))
	typed := positionTypedScheme(t)

	// Act
	out, err := opener.Pack(typed, 42)
	payload, goodErr := opener.Pack(typed, goldenRow())
	got, unpackErr := waiter.Unpack(payload, typed)

	// Assert
	asError(t, err, PackRefused)
	if out != nil || goodErr != nil || unpackErr != nil || got == nil {
		t.Fatalf("%x %v %v %v", out, goodErr, unpackErr, got)
	}
}

// AZ-2704: the checks run in one order in every package (not open, no scheme, duplicate type, parity mix,
// limit): a repeated number is the refusal even when the list also mixes parity counts or the limit is bad.
func TestDuplicateTypeIsRefusedBeforeAParityMixAndABadLimit(t *testing.T) {
	// Arrange
	_, waiter := sessionPair(t, sessionNonce(t))
	scheme := positionMapScheme(t)
	protected, err := scheme.WithParity(4)
	if err != nil {
		t.Fatal(err)
	}
	want := "duplicate type number " + strconv.Itoa(scheme.typeNumber)

	// Act
	_, _, withMix := waiter.UnpackRepair(make([]byte, 8), 0, scheme, protected)
	_, _, withLimit := UnpackRepair(make([]byte, 8), 9, protected, protected)

	// Assert
	for name, err := range map[string]error{"with a parity mix": withMix, "with a bad limit": withLimit} {
		if e := asError(t, err, InvalidScheme); e.Reason != want {
			t.Fatalf("%s: reason %q, want %q", name, e.Reason, want)
		}
	}
}
