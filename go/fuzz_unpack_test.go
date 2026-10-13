package packbin

import (
	"errors"
	"strings"
	"testing"
	"time"
)

// unpackBound is how long one unpack of one fuzz input may take (project AC-2); the race detector
// slows an unpack down several times over.
func unpackBound() time.Duration {
	if raceEnabled {
		return 10 * time.Second
	}
	return time.Second
}

// fuzzInputCap is the longest input FuzzUnpack reads. A packet near 1 MiB takes up to a second with every
// scheme, which would leave the fuzzer minimising one input for minutes; the large packets that reach a
// default limit are read by TestAMebibyteOfAnyByteIsReadWithinTheBound.
const fuzzInputCap = 1 << 15

// FuzzUnpack: every input, read as a packet of each scheme and as a packet for all of them, returns
// within a second, never panics, and gives either a row or a well-formed error. It does not assert
// that an unpacked row packs again: a flags times whose bit is clear with a count above 0 unpacks and
// repacks with "missing" (as in TypeScript), so a row of an unpack is not always a row of a pack.
// The seed corpus in testdata/fuzz/FuzzUnpack holds the ring payloads, the golden row and every
// unpack and limit packet of fixtures/hostile/cases.txt, each with and without its type byte.
func FuzzUnpack(f *testing.F) {
	schemes := fuzzSchemes(f)
	f.Fuzz(func(t *testing.T, input []byte) {
		input = input[:min(len(input), fuzzInputCap)]
		for _, s := range schemes {
			packet := append([]byte{byte(s.TypeNumber())}, input...)
			checkUnpack(t, packet, s)
		}
		checkUnpack(t, input, schemes...)
	})
}

func checkUnpack(t *testing.T, packet []byte, schemes ...*Scheme) {
	t.Helper()
	start := time.Now()
	row, err := Unpack(packet, schemes...)
	byName, mapErr := UnpackMap(packet, schemes...)
	if elapsed := time.Since(start); elapsed > unpackBound() {
		t.Fatalf("unpack of %d bytes took %v: %x", len(packet), elapsed, head(packet))
	}
	if (err == nil) != (mapErr == nil) {
		t.Fatalf("Unpack error %v, UnpackMap error %v: %x", err, mapErr, head(packet))
	}
	if err == nil {
		if _, ok := row.(map[string]any); !ok || byName == nil {
			t.Fatalf("a read gave row %T and map %v: %x", row, byName, head(packet))
		}
		return
	}
	if row != nil || byName != nil {
		t.Fatalf("an error came with a row: %v: %x", err, head(packet))
	}
	if msg := wellFormed(err, packet, schemes); msg != "" {
		t.Fatalf("%s: %v: %x", msg, err, head(packet))
	}
}

// wellFormed says what is wrong with an error unpack returned, or "".
func wellFormed(err error, packet []byte, schemes []*Scheme) string {
	var e *Error
	if !errors.As(err, &e) || e == nil {
		return "not an *Error"
	}
	sentinels := map[Kind]*Error{ShortPacket: ErrShortPacket, TrailingBytes: ErrTrailingBytes,
		UnknownType: ErrUnknownType, BadValue: ErrBadValue, TooMany: ErrTooMany}
	sentinel, known := sentinels[e.Kind]
	switch {
	case !known:
		return "a kind unpack never returns"
	case !errors.Is(err, sentinel):
		return "errors.Is does not match the kind"
	case strings.HasPrefix(e.Kind.String(), "kind("):
		return "an unnamed kind"
	case !strings.HasPrefix(e.Error(), "packbin: ") || len(e.Error()) < 12:
		return "an empty message"
	case e.Field < NoField || e.Needed < 0 || e.Left < 0 || e.Left > len(packet):
		return "a number out of range"
	case e.Kind == TooMany && e.Needed != 0:
		return "a round limit with bytes needed"
	case e.Kind == TrailingBytes && (e.Left == 0 || e.Needed != 0):
		return "trailing bytes that are none"
	case e.Kind == UnknownType && (len(packet) == 0 || e.Actual != int(packet[0]) || hasType(schemes, e.Actual)):
		return "an unknown type that is known"
	case e.Kind == ShortPacket && len(packet) == 0 && (e.Needed != 1 || e.Left != 0):
		return "an empty packet that is not a one byte short read"
	}
	return ""
}

func hasType(schemes []*Scheme, number int) bool {
	for _, s := range schemes {
		if s.TypeNumber() == number {
			return true
		}
	}
	return false
}

func head(b []byte) []byte { return b[:min(len(b), 64)] }

// The ring payloads and the golden row read with the fuzz scheme of their kind (under its type
// number), so the seed corpus starts the fuzzer inside each scheme and not at its type check.
func TestFuzzSeedsReadWithTheSchemeOfTheirKind(t *testing.T) {
	// Arrange
	schemes := fuzzSchemes(t)
	seeds := map[int]string{
		0: "0107007a7873616e6e7902000400757365720a0064697370617463686572030007006368616e6e656c010004007265616403006d6170040004007265616407006770735f6669780300736574040065646974050073746f7265020004007265616405007772697465",
		1: "01020003006d61700100010002006f7007006770735f666978050073746f72650200010002006f70040072656164010002006f7005007772697465",
		2: "0100", 4: "01030102020303", 5: "01010902",
		6: "01020001020304", 7: "01020001007801020100790304", 8: "010300010100020200",
		len(schemes) - 1: goldenHex(t),
	}

	for i, wire := range seeds {
		// Act
		packet := mustHex(t, wire)
		packet[0] = byte(schemes[i].TypeNumber())
		_, err := UnpackMap(packet, schemes[i])

		// Assert
		if err != nil {
			t.Errorf("scheme %d (type %d): %v", i, schemes[i].TypeNumber(), err)
		}
	}
}

// A packet of a mebibyte of one byte (a count of 0, 1 or 255 rounds for every count it reads) reaches
// the default round and slot limits of the wide schemes, and is read by each scheme within the bound.
func TestAMebibyteOfAnyByteIsReadWithinTheBound(t *testing.T) {
	// Arrange
	schemes := fuzzSchemes(t)

	for _, fill := range []byte{0, 1, 0xff} {
		body := make([]byte, 1<<20)
		for i := range body {
			body[i] = fill
		}
		for _, s := range schemes {
			// Act / Assert
			checkUnpack(t, append([]byte{byte(s.TypeNumber())}, body...), s)
		}
	}
}
