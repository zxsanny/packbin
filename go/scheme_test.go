package packbin

import (
	"errors"
	"testing"
)

type otherRow struct{ X uint8 }

// The construction checks the walker needs, and the Bind checks of this API.
func TestNewSchemeRefusals(t *testing.T) {
	m := FlagByte("m")
	cases := []struct {
		name   string
		build  func() (*Scheme, error)
		field  int
		reason string
	}{
		{"type number 256", func() (*Scheme, error) { return NewScheme(256, U8(0, "a")) }, NoField,
			"type number 256: expected 0..255"},
		{"type number -1", func() (*Scheme, error) { return NewScheme(-1, U8(0, "a")) }, NoField,
			"type number -1: expected 0..255"},
		{"flags anchor", func() (*Scheme, error) { return NewScheme(1, Flags(1, U16(0, "extra"))) }, 1,
			"flags anchor: expected 0, got 1"},
		{"id gap", func() (*Scheme, error) { return NewScheme(1, U8(0, "a"), U8(2, "b")) }, 2,
			"field id: expected 1, got 2"},
		{"negative id", func() (*Scheme, error) { return NewScheme(1, U8(-1, "a")) }, -1,
			"field id: expected 0, got -1"},
		{"when names a later field", func() (*Scheme, error) {
			return NewScheme(1, U8(0, "a"), When(1, Eq(2, 1), U8(1, "b")), U8(2, "c"))
		}, 1, "when 1: eq names field id 2, which is not declared earlier in the same scope"},
		{"bit before its byte", func() (*Scheme, error) { return NewScheme(1, m.Bit(U8(0, "a")), m) }, 0,
			"flag bit 0 (a): its flag byte is not read earlier in the same scope"},
		{"byte read inside a when", func() (*Scheme, error) {
			return NewScheme(1, U8(0, "k"), When(1, Eq(0, 1), m), m.Bit(U8(1, "a")))
		}, 1, "flag bit 0 (a): its flag byte is not read earlier in the same scope"},
		{"nil field", func() (*Scheme, error) { return NewScheme(1, U8(0, "a"), nil) }, NoField, "a field is nil"},
		{"nil flags member", func() (*Scheme, error) { return NewScheme(1, Flags(0, nil)) }, NoField, "a field is nil"},
		{"negative bytes size", func() (*Scheme, error) { return NewScheme(1, Bytes(0, "b", -1)) }, 0,
			"bytes size -1: expected 0 or more"},
		{"bit of a nil handle", func() (*Scheme, error) {
			var h *FlagByteHandle
			return NewScheme(1, h.Bit(U8(0, "a")))
		}, 0, "Bit on a nil flag byte"},
		{"bind a narrow member", func() (*Scheme, error) {
			return NewScheme(1, Bind(U16(0, "a"), func(r *otherRow) uint8 { return r.X }, func(r *otherRow, v uint8) { r.X = v }))
		}, 0, "a uint8 member cannot hold every u16 value"},
		{"bind a signed member to u64", func() (*Scheme, error) {
			return NewScheme(1, Bind(U64(0, "a"), func(*otherRow) int64 { return 0 }, func(*otherRow, int64) {}))
		}, 0, "a int64 member cannot hold every u64 value"},
		{"bind float32 to f64", func() (*Scheme, error) {
			return NewScheme(1, Bind(F64(0, "a"), func(*otherRow) float32 { return 0 }, func(*otherRow, float32) {}))
		}, 0, "a float32 member cannot hold every f64 value"},
		{"bind a string to bytes", func() (*Scheme, error) {
			return NewScheme(1, Bind(Bytes(0, "a", 2), func(*otherRow) string { return "" }, func(*otherRow, string) {}))
		}, 0, "a string member cannot hold bytes(2); bind a []byte"},
		{"bind flags", func() (*Scheme, error) {
			return NewScheme(1, Bind(Flags(0, U8(0, "a")), func(*otherRow) uint8 { return 0 }, func(*otherRow, uint8) {}))
		}, 0, "Bind takes a value field, a slot, a group, a repeat or a times, not flags"},
		{"bind without a setter", func() (*Scheme, error) {
			return NewScheme(1, Bind[otherRow, uint8](U8(0, "a"), func(*otherRow) uint8 { return 0 }, nil))
		}, 0, "Bind needs a getter and a setter"},
		{"bind twice", func() (*Scheme, error) {
			f := Bind(U8(0, "a"), func(r *otherRow) uint8 { return r.X }, func(r *otherRow, v uint8) { r.X = v })
			return NewScheme(1, Bind(f, func(r *otherRow) uint8 { return r.X }, func(r *otherRow, v uint8) { r.X = v }))
		}, 0, "the field is already bound"},
		{"one field unbound", func() (*Scheme, error) {
			return NewScheme(1, Bind(U8(0, "a"), func(r *otherRow) uint8 { return r.X }, func(r *otherRow, v uint8) { r.X = v }),
				U8(1, "b"))
		}, 1, "not bound to row type packbin.otherRow; bind every value field of a scheme, or none"},
		{"two row types", func() (*Scheme, error) {
			return NewScheme(1, Bind(U8(0, "a"), func(r *otherRow) uint8 { return r.X }, func(r *otherRow, v uint8) { r.X = v }),
				Bind(U16(1, "sid"), func(r *Position) uint16 { return r.Sid }, func(r *Position, v uint16) { r.Sid = v }))
		}, 1, "bound to row type packbin.Position, but an earlier field is bound to packbin.otherRow"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Act
			s, err := c.build()

			// Assert
			e := asError(t, err, InvalidScheme)
			if s != nil || e.Field != c.field || e.Reason != c.reason {
				t.Fatalf("got field %d reason %q", e.Field, e.Reason)
			}
			if !errors.Is(err, ErrInvalidScheme) {
				t.Fatalf("errors.Is: %v", err)
			}
		})
	}
}

func TestSchemeTypeNumberIsTheFirstByte(t *testing.T) {
	// Arrange
	s := mustScheme(t, 32, U8(0, "sid"))

	// Act
	wire := mustPack(t, s, map[string]any{"sid": 23})

	// Assert
	if s.TypeNumber() != 32 || wire != "2017" {
		t.Fatalf("type %d wire %s", s.TypeNumber(), wire)
	}
}

func TestOneFieldListBuildsManySchemes(t *testing.T) {
	// Arrange: a handle and fields shared by two schemes; building one does not change the other.
	m := FlagByte("m")
	a := m.Bit(U8(0, "a"))
	first := mustScheme(t, 1, m, a)
	second := mustScheme(t, 2, m, a, m.Bit(U8(1, "x")))

	// Act
	one := mustPack(t, first, map[string]any{"a": 4})
	two := mustPack(t, second, map[string]any{"x": 5, "a": 4})

	// Assert
	if one != "010104" || two != "02030405" {
		t.Fatalf("one %s two %s", one, two)
	}
}

func TestEmptySchemePacksTheTypeByteOnly(t *testing.T) {
	// Arrange
	s := mustScheme(t, 7)

	// Act
	wire := mustPack(t, s, map[string]any{})
	back := mustUnpackMap(t, s, "07")

	// Assert
	if wire != "07" || len(back) != 0 {
		t.Fatalf("wire %s back %v", wire, back)
	}
}
