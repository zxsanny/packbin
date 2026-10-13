package packbin

import (
	"bytes"
	"strings"
	"testing"
)

// A nil *Scheme is what NewScheme returns with an error; its accessors answer instead of panicking.
func TestNilSchemeAccessorsDoNotPanic(t *testing.T) {
	// Arrange
	var s *Scheme

	// Act
	number := s.TypeNumber()
	limits := s.Limits()

	// Assert
	if number != 0 || limits != (Limits{}) {
		t.Fatalf("nil scheme: type number %d, limits %+v", number, limits)
	}
}

// F42: a zero-value Scheme (not made by NewScheme) is refused by every entry point with an *Error.
func TestZeroValueSchemeIsRefused(t *testing.T) {
	zero := &Scheme{}
	good := mustScheme(t, 5, U8(0, "a"))
	opener, waiter := sessionPair(t, sessionNonce(t))
	const named = "not made by NewScheme"
	t.Run("Pack", func(t *testing.T) {
		_, err := Pack(zero, map[string]any{})
		if e := asError(t, err, PackRefused); !strings.Contains(e.Reason, named) {
			t.Fatalf("got %v", e)
		}
	})
	t.Run("Unpack with the zero scheme first and a packet of 0", func(t *testing.T) {
		_, err := Unpack([]byte{0}, zero)
		if e := asError(t, err, InvalidScheme); !strings.Contains(e.Reason, named) {
			t.Fatalf("got %v", e)
		}
	})
	t.Run("Unpack with the zero scheme among good ones", func(t *testing.T) {
		_, err := Unpack([]byte{5, 1}, good, zero)
		asError(t, err, InvalidScheme)
	})
	t.Run("UnpackMap", func(t *testing.T) {
		_, err := UnpackMap([]byte{0}, zero)
		asError(t, err, InvalidScheme)
	})
	t.Run("WithLimits", func(t *testing.T) {
		s, err := zero.WithLimits(DefaultLimits())
		if s != nil {
			t.Fatalf("a scheme came back: %v", s)
		}
		asError(t, err, InvalidScheme)
	})
	t.Run("accessors", func(t *testing.T) {
		if zero.TypeNumber() != 0 || zero.Limits() != (Limits{}) {
			t.Fatalf("type number %d, limits %+v", zero.TypeNumber(), zero.Limits())
		}
	})
	t.Run("PackSession.Pack", func(t *testing.T) {
		_, err := opener.Pack(zero, map[string]any{})
		asError(t, err, PackRefused)
	})
	t.Run("PackSession.Unpack and UnpackMap spend no position", func(t *testing.T) {
		_, err := waiter.Unpack([]byte{0}, zero)
		asError(t, err, InvalidScheme)
		_, err = waiter.UnpackMap([]byte{0}, zero)
		asError(t, err, InvalidScheme)
		payload, err := opener.Pack(good, map[string]any{"a": uint8(7)})
		if err != nil {
			t.Fatalf("pack: %v", err)
		}
		row, err := waiter.UnpackMap(payload, good)
		if err != nil || row["a"] != uint8(7) {
			t.Fatalf("the first position was spent: %v, %v", row, err)
		}
	})
}

// cyclic points at itself: reading through it never ends.
type cyclic *cyclic

// F42: a value behind more than 8 pointers, or a type that points at itself, is an unsupported value and
// a refused pack, not a stack overflow; two pointers still pack.
func TestPointerChaseIsBounded(t *testing.T) {
	// Arrange
	s := mustScheme(t, 1, U8(0, "a"))
	var loop cyclic
	loop = cyclic(&loop)
	v := uint8(9)
	p1 := &v
	p2 := &p1

	// Act
	_, errLoop := Pack(s, map[string]any{"a": loop})
	packed, errTwo := Pack(s, map[string]any{"a": p2})

	// Assert
	asError(t, errLoop, PackRefused)
	if errTwo != nil || !bytes.Equal(packed, []byte{1, 9}) {
		t.Fatalf("a **uint8: %v, %v", packed, errTwo)
	}
}
