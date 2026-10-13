package packbin

import (
	"bytes"
	"reflect"
	"testing"
)

const (
	sessionCipherHex = "b55d0a29c56c203712b241232e"
	sessionNonceHex  = "01000000000000000000000000000000"
)

func sessionSeed() []byte {
	seed := make([]byte, SeedSize)
	for i := range seed {
		seed[i] = byte(i + 1)
	}
	return seed
}

func sessionNonce(t testing.TB) []byte { return mustHex(t, sessionNonceHex) }

func mustLoad(t testing.TB, seed []byte) *PackSession {
	t.Helper()
	s, err := LoadSession(seed)
	if err != nil {
		t.Fatalf("LoadSession: %v", err)
	}
	return s
}

// sessionPair is an opener and a waiter on the same seed and value.
func sessionPair(t testing.TB, nonce []byte) (opener, waiter *PackSession) {
	t.Helper()
	opener, waiter = mustLoad(t, sessionSeed()), mustLoad(t, sessionSeed())
	if _, err := opener.StartWith(nonce); err != nil {
		t.Fatalf("StartWith: %v", err)
	}
	if err := waiter.Join(nonce); err != nil {
		t.Fatalf("Join: %v", err)
	}
	return opener, waiter
}

func goldenFieldMismatches(row map[string]any) int {
	want := map[string]any{"sid": uint16(1), "lat": int32(500_000_000), "lon": int32(300_000_000), "profile": uint8(1)}
	bad := 0
	for k, v := range want {
		if !reflect.DeepEqual(row[k], v) {
			bad++
		}
	}
	for _, k := range []string{"heading", "speed", "altitude"} {
		if _, ok := row[k]; ok {
			bad++
		}
	}
	return bad
}

func TestSessionAC1OpenerPackMatchesCSharpCiphertext(t *testing.T) {
	// Arrange
	opener := mustLoad(t, sessionSeed())
	if _, err := opener.StartWith(sessionNonce(t)); err != nil {
		t.Fatal(err)
	}

	// Act
	payload, err := opener.Pack(positionMapScheme(t), goldenMap())

	// Assert
	if err != nil {
		t.Fatal(err)
	}
	if len(payload) != 13 || hexOf(payload) != sessionCipherHex || mismatchedBytes(payload, mustHex(t, sessionCipherHex)) != 0 {
		t.Fatalf("payload %s", hexOf(payload))
	}
}

func TestSessionAC1TypedRowGivesTheSameCiphertext(t *testing.T) {
	// Arrange
	opener := mustLoad(t, sessionSeed())
	if _, err := opener.StartWith(sessionNonce(t)); err != nil {
		t.Fatal(err)
	}

	// Act
	payload, err := opener.Pack(positionTypedScheme(t), goldenRow())

	// Assert
	if err != nil || hexOf(payload) != sessionCipherHex {
		t.Fatalf("payload %s, err %v", hexOf(payload), err)
	}
}

func TestSessionKeyedFirstPacketVectors(t *testing.T) {
	// Arrange: the TypeScript rows of AZ-2243, one u8 of 0 under the value 01 x16.
	one := mustScheme(t, 1, U8(0, "a"))
	cases := []struct {
		name string
		seed []byte
		want string
	}{
		{"seed 1..32", sessionSeed(), "d9bc"},
		{"zero seed", make([]byte, SeedSize), "5781"},
	}
	for _, c := range cases {
		opener := mustLoad(t, c.seed)
		if _, err := opener.StartWith(bytes.Repeat([]byte{1}, NonceSize)); err != nil {
			t.Fatal(err)
		}

		// Act
		payload, err := opener.Pack(one, map[string]any{"a": 0})

		// Assert
		if err != nil || hexOf(payload) != c.want {
			t.Fatalf("%s: %s, err %v", c.name, hexOf(payload), err)
		}
	}
}

func TestSessionAC2WaiterRecoversTheFiveFields(t *testing.T) {
	// Arrange
	opener, waiter := sessionPair(t, sessionNonce(t))
	scheme := positionMapScheme(t)

	// Act
	payload, err := opener.Pack(scheme, goldenMap())
	if err != nil {
		t.Fatal(err)
	}
	row, err := waiter.UnpackMap(payload, scheme)

	// Assert
	if err != nil {
		t.Fatal(err)
	}
	if len(payload) != len(mustHex(t, expectedHex)) {
		t.Fatalf("payload length %d", len(payload))
	}
	if n := goldenFieldMismatches(row); n != 0 {
		t.Fatalf("field mismatches %d: %v", n, row)
	}
}

func TestSessionAC2TypedRowRoundTrip(t *testing.T) {
	// Arrange
	opener, waiter := sessionPair(t, sessionNonce(t))
	scheme := positionTypedScheme(t)

	// Act
	payload, err := opener.Pack(scheme, goldenRow())
	if err != nil {
		t.Fatal(err)
	}
	got, err := waiter.Unpack(payload, scheme)

	// Assert
	if err != nil || !reflect.DeepEqual(got, goldenRow()) {
		t.Fatalf("got %+v, err %v", got, err)
	}
}

func TestSessionAC3WaiterCanSend(t *testing.T) {
	// Arrange
	opener, waiter := sessionPair(t, sessionNonce(t))
	scheme := positionMapScheme(t)

	// Act
	payload, err := waiter.Pack(scheme, goldenMap())
	if err != nil {
		t.Fatal(err)
	}
	row, err := opener.UnpackMap(payload, scheme)

	// Assert
	if err != nil || goldenFieldMismatches(row) != 0 {
		t.Fatalf("row %v, err %v", row, err)
	}
	if hexOf(payload) == sessionCipherHex {
		t.Fatal("the waiter sends with the other half of the key")
	}
}

func TestSessionAC4SecondPacketUsesTheNextPosition(t *testing.T) {
	// Arrange
	opener, waiter := sessionPair(t, sessionNonce(t))
	scheme := positionMapScheme(t)
	first, err := opener.Pack(scheme, goldenMap())
	if err != nil {
		t.Fatal(err)
	}
	if _, err := waiter.UnpackMap(first, scheme); err != nil {
		t.Fatal(err)
	}

	// Act
	second, err := opener.Pack(scheme, goldenMap())
	if err != nil {
		t.Fatal(err)
	}
	row, err := waiter.UnpackMap(second, scheme)

	// Assert
	if err != nil || goldenFieldMismatches(row) != 0 {
		t.Fatalf("row %v, err %v", row, err)
	}
	if bytes.Equal(first, second) {
		t.Fatal("two packets of one direction carry the same bytes")
	}
}

func TestSessionAC5TwoClientsDoNotShareAStream(t *testing.T) {
	// Arrange: one seed, two different 16-byte values.
	nonceA, nonceB := sessionNonce(t), bytes.Repeat([]byte{2}, NonceSize)
	opener := mustLoad(t, sessionSeed())
	if _, err := opener.StartWith(nonceA); err != nil {
		t.Fatal(err)
	}
	other := mustLoad(t, sessionSeed())
	if err := other.Join(nonceB); err != nil {
		t.Fatal(err)
	}
	scheme := positionMapScheme(t)
	payload, err := opener.Pack(scheme, goldenMap())
	if err != nil {
		t.Fatal(err)
	}

	// Act
	row, err := other.UnpackMap(payload, scheme)

	// Assert
	if err == nil && goldenFieldMismatches(row) == 0 {
		t.Fatalf("client B read client A's row: %v", row)
	}
}

func TestSessionAC6BadSetupCreatesNothing(t *testing.T) {
	// Arrange
	created := 0

	// Act
	for _, n := range []int{0, 31, 33} {
		if s, err := LoadSession(make([]byte, n)); s != nil || err == nil {
			created++
		}
	}
	loaded := mustLoad(t, sessionSeed())
	for _, n := range []int{0, 15, 17} {
		if err := loaded.Join(make([]byte, n)); err == nil {
			created++
		}
		if out, err := loaded.StartWith(make([]byte, n)); out != nil || err == nil {
			created++
		}
	}

	// Assert
	if created != 0 {
		t.Fatalf("sessions created: %d", created)
	}
	if _, err := loaded.StartWith(sessionNonce(t)); err != nil {
		t.Fatalf("a refused value must leave the seed in place: %v", err)
	}
}

func TestSessionAC7PackBeforeTheConnectionIsOpenFails(t *testing.T) {
	// Arrange
	loaded := mustLoad(t, sessionSeed())

	// Act
	payload, err := loaded.Pack(positionMapScheme(t), goldenMap())

	// Assert
	asError(t, err, PackRefused)
	if payload != nil {
		t.Fatalf("payloads produced: %x", payload)
	}
}

func TestSessionStartDrawsSixteenRandomBytesTheWaiterJoins(t *testing.T) {
	// Arrange
	opener, waiter := mustLoad(t, sessionSeed()), mustLoad(t, sessionSeed())
	again := mustLoad(t, sessionSeed())
	scheme := positionMapScheme(t)

	// Act
	nonce, err := opener.Start()
	if err != nil {
		t.Fatal(err)
	}
	other, err := again.Start()
	if err != nil {
		t.Fatal(err)
	}
	if err := waiter.Join(nonce); err != nil {
		t.Fatal(err)
	}
	payload, err := opener.Pack(scheme, goldenMap())
	if err != nil {
		t.Fatal(err)
	}
	row, err := waiter.UnpackMap(payload, scheme)

	// Assert
	if len(nonce) != NonceSize || bytes.Equal(nonce, other) {
		t.Fatalf("values %x and %x", nonce, other)
	}
	if err != nil || goldenFieldMismatches(row) != 0 {
		t.Fatalf("row %v, err %v", row, err)
	}
}

func TestSessionStartWithReturnsACopyOfTheValue(t *testing.T) {
	// Arrange
	opener := mustLoad(t, sessionSeed())
	nonce := sessionNonce(t)

	// Act
	out, err := opener.StartWith(nonce)
	nonce[0] = 0xff

	// Assert
	if err != nil || hexOf(out) != sessionNonceHex {
		t.Fatalf("out %x, err %v", out, err)
	}
}

func TestSessionClearPackIsUnchanged(t *testing.T) {
	// Act
	got := mustPack(t, positionMapScheme(t), goldenMap())

	// Assert
	if got != expectedHex {
		t.Fatalf("clear pack %s", got)
	}
}
