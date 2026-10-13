package packbin

import "testing"

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
