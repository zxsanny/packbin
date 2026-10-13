package packbin

import (
	"reflect"
	"testing"
)

// AC-4: a nil pointer is no value (bit clear, 0 bytes); a pointer to 0 is a value (bit set, 0 written).
func TestAC4NilPointerIsNoValueZeroIsValue(t *testing.T) {
	// Arrange
	s := positionTypedScheme(t)
	zero := uint16(0)
	absent := goldenRow()
	present := goldenRow()
	present.Heading = &zero

	// Act
	clear := mustPack(t, s, absent)
	set := mustPack(t, s, present)

	// Assert
	if clear != expectedHex {
		t.Fatalf("nil heading: %s", clear)
	}
	if set != "4001000065cd1d00a3e111010100"+"00" {
		t.Fatalf("zero heading: %s", set)
	}
	if len(set)/2-len(clear)/2 != 2 {
		t.Fatalf("zero heading adds %d bytes", len(set)/2-len(clear)/2)
	}
	back, err := Unpack(mustHex(t, set), s)
	if err != nil {
		t.Fatal(err)
	}
	if h := back.(*Position).Heading; h == nil || *h != 0 {
		t.Fatalf("heading %v", h)
	}
}

func TestAC4MapNilAndAbsentAreNoValue(t *testing.T) {
	// Arrange
	s := mustScheme(t, 1, Flags(0, U8(0, "b0"), U8(1, "b1"), U8(2, "b2"), U8(3, "b3"), U8(4, "b4"), U16(5, "extra")))
	var nilPtr *uint16
	zero := uint16(0)

	cases := []struct {
		row  map[string]any
		wire string
	}{
		{map[string]any{}, "0100"},
		{map[string]any{"extra": nil}, "0100"},
		{map[string]any{"extra": nilPtr}, "0100"},
		{map[string]any{"extra": 0x1234}, "01203412"},
		{map[string]any{"extra": 0}, "01200000"},
		{map[string]any{"extra": &zero}, "01200000"},
	}
	for _, c := range cases {
		// Act
		wire := mustPack(t, s, c.row)

		// Assert
		if wire != c.wire {
			t.Fatalf("%v: %s, want %s", c.row, wire, c.wire)
		}
	}
}

type flagRow struct {
	On   bool
	Data []byte
}

func TestAC4NilSliceIsNoValueEmptySliceIsValue(t *testing.T) {
	// Arrange
	s := mustScheme(t, 1, Flags(0,
		Bind(Bytes(0, "data", 0), func(r *flagRow) []byte { return r.Data }, func(r *flagRow, v []byte) { r.Data = v })))

	// Act
	none := mustPack(t, s, &flagRow{})
	empty := mustPack(t, s, &flagRow{Data: []byte{}})
	back, err := Unpack(mustHex(t, empty), s)

	// Assert
	if none != "0100" || empty != "0101" {
		t.Fatalf("nil %s empty %s", none, empty)
	}
	if err != nil || back.(*flagRow).Data == nil {
		t.Fatalf("back %+v err %v", back, err)
	}
}

func TestBoolFalseAndAbsentLeaveTheBitClear(t *testing.T) {
	// Arrange
	s := mustScheme(t, 1, Flags(0, Bool(0, "on")))

	for _, c := range []struct {
		row  map[string]any
		wire string
	}{
		{map[string]any{"on": false}, "0100"},
		{map[string]any{}, "0100"},
		{map[string]any{"on": true}, "0101"},
		// As TypeScript: a value other than true leaves the bit clear.
		{map[string]any{"on": 1}, "0100"},
		{map[string]any{"on": "yes"}, "0100"},
	} {
		// Act
		wire := mustPack(t, s, c.row)

		// Assert
		if wire != c.wire {
			t.Fatalf("%v: %s", c.row, wire)
		}
	}
	if back := mustUnpackMap(t, s, "0100"); len(back) != 0 {
		t.Fatalf("clear bit gave %v", back)
	}
	if back := mustUnpackMap(t, s, "0101"); !reflect.DeepEqual(back, map[string]any{"on": true}) {
		t.Fatalf("set bit gave %v", back)
	}
}

func TestBoolTypedFalseIsClear(t *testing.T) {
	// Arrange
	s := mustScheme(t, 1, Flags(0,
		Bind(Bool(0, "on"), func(r *flagRow) bool { return r.On }, func(r *flagRow, v bool) { r.On = v })))

	// Act
	off := mustPack(t, s, &flagRow{})
	on := mustPack(t, s, &flagRow{On: true})
	back, err := Unpack(mustHex(t, on), s)

	// Assert
	if off != "0100" || on != "0101" || err != nil || !back.(*flagRow).On {
		t.Fatalf("off %s on %s back %+v err %v", off, on, back, err)
	}
}
