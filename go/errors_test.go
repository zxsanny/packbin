package packbin

import (
	"errors"
	"testing"
)

// AC-3: a buffer that ends inside a field names the field, the bytes needed and the bytes left.
func TestAC3ShortPacketNamesFieldNeededLeft(t *testing.T) {
	cases := []struct {
		name   string
		scheme *Scheme
		wire   string
		id     int
		field  string
		needed int
		left   int
	}{
		{"golden cut inside lon", positionMapScheme(t), "4001000065cd1d00a3e1", 2, "lon", 4, 3},
		{"golden without motion", positionMapScheme(t), "4001000065cd1d00a3e11101", 4, "", 1, 0},
		{"flags member", mustScheme(t, 1, Flags(0, U8(0, "b0"), U8(1, "b1"), U8(2, "b2"), U8(3, "b3"),
			U8(4, "b4"), U16(5, "extra"))), "012034", 5, "extra", 2, 1},
		{"split flag byte", func() *Scheme {
			m := FlagByte("m")
			return mustScheme(t, 1, U8(0, "a"), m, m.Bit(U8(1, "b")))
		}(), "0105", NoField, "m", 1, 0},
		{"fixed bytes", mustScheme(t, 1, Bytes(0, "b", 3)), "016162", 0, "b", 3, 2},
		{"f64", mustScheme(t, 1, F64(0, "x")), "0100", 0, "x", 8, 1},
		{"when body", mustScheme(t, 1, U8(0, "k"), When(1, Eq(0, 1), U8(1, "v"))), "0101", 1, "v", 1, 0},
		{"empty buffer", positionMapScheme(t), "", NoField, "", 1, 0},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Act
			row, err := Unpack(mustHex(t, c.wire), c.scheme)

			// Assert
			e := asError(t, err, ShortPacket)
			if row != nil {
				t.Fatalf("row %v", row)
			}
			if e.Field != c.id || e.Name != c.field || e.Needed != c.needed || e.Left != c.left {
				t.Fatalf("got %+v", e)
			}
			if !errors.Is(err, ErrShortPacket) || errors.Is(err, ErrTrailingBytes) {
				t.Fatalf("errors.Is: %v", err)
			}
		})
	}
}

func TestAC3TrailingBytesGiveNoRow(t *testing.T) {
	// Arrange
	wire := mustHex(t, expectedHex+"ff")

	for _, s := range []*Scheme{positionMapScheme(t), positionTypedScheme(t)} {
		// Act
		row, err := Unpack(wire, s)
		m, mapErr := UnpackMap(wire, s)

		// Assert
		e := asError(t, err, TrailingBytes)
		if row != nil || m != nil || e.Left != 1 || !errors.Is(mapErr, ErrTrailingBytes) {
			t.Fatalf("row %v map %v err %+v", row, m, e)
		}
	}
}

func TestAC3UnknownTypeNumber(t *testing.T) {
	// Arrange
	modified := mustScheme(t, 1, I32(0, "userId"), U8(1, "status"))
	position := mustScheme(t, 2, I32(0, "userId"), I32(1, "latitude"), I32(2, "longitude"))

	// Act
	row, err := Unpack([]byte{9}, modified, position)

	// Assert
	e := asError(t, err, UnknownType)
	if row != nil || e.Actual != 9 || !errors.Is(err, ErrUnknownType) {
		t.Fatalf("row %v err %+v", row, e)
	}
}

func TestDispatchPicksTheSchemeByFirstByte(t *testing.T) {
	// Arrange
	modified := mustScheme(t, 1, I32(0, "userId"), U8(1, "status"))
	position := mustScheme(t, 2, I32(0, "userId"), I32(1, "latitude"), I32(2, "longitude"))
	raw, err := Pack(position, map[string]any{"userId": 7, "latitude": 8, "longitude": 9})
	if err != nil {
		t.Fatal(err)
	}

	// Act
	row, err := UnpackMap(raw, modified, position)

	// Assert
	if err != nil {
		t.Fatal(err)
	}
	if hexOf(raw) != "02070000000800000009000000" || row["userId"] != int32(7) || row["longitude"] != int32(9) {
		t.Fatalf("raw %x row %v", raw, row)
	}
	if _, ok := row["type"]; ok || len(row) != 3 {
		t.Fatalf("row %v", row)
	}
}

func TestDispatchRefusesDuplicateNilAndNoSchemes(t *testing.T) {
	// Arrange
	a := mustScheme(t, 1, U8(0, "a"))
	b := mustScheme(t, 1, U8(0, "b"))

	for _, schemes := range [][]*Scheme{{a, b}, {a, nil}, {}} {
		// Act
		row, err := Unpack([]byte{1, 2}, schemes...)

		// Assert
		if row != nil || !errors.Is(err, ErrInvalidScheme) {
			t.Fatalf("schemes %v: row %v err %v", schemes, row, err)
		}
	}
}

func TestErrorKindNamesMatchHostileVocabulary(t *testing.T) {
	// Arrange
	want := map[Kind]string{
		ShortPacket: "short_packet", TrailingBytes: "trailing_bytes", UnknownType: "type_mismatch",
		BadValue: "bad_value", InvalidScheme: "scheme_error", PackRefused: "pack_error", TooMany: "too_many",
	}

	for k, name := range want {
		// Act
		got := k.String()

		// Assert
		if got != name {
			t.Fatalf("%d: %s, want %s", int(k), got, name)
		}
	}
}

func TestErrorMessagesNameTheField(t *testing.T) {
	// Arrange
	s := positionMapScheme(t)

	// Act
	_, err := Unpack(mustHex(t, "4001000065cd1d00a3e1"), s)

	// Assert
	if err.Error() != "packbin: short packet at field 2 (lon): needed 4, left 3" {
		t.Fatalf("got %q", err.Error())
	}
}
