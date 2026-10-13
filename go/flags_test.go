package packbin

import (
	"fmt"
	"reflect"
	"testing"
)

func eightU8() []Field {
	out := make([]Field, 8)
	for i := range out {
		out[i] = U8(i, fmt.Sprintf("f%d", i))
	}
	return out
}

// Ported from typescript/tests/bool-flag.test.ts.
func TestSplitFormBool(t *testing.T) {
	// Arrange
	m := FlagByte("m")
	s := mustScheme(t, 1, m, m.Bit(Bool(0, "on")))

	// Act
	off := mustPack(t, s, map[string]any{"on": false})
	on := mustPack(t, s, map[string]any{"on": true})

	// Assert
	if off != "0100" || on != "0101" {
		t.Fatalf("off %s on %s", off, on)
	}
	if back := mustUnpackMap(t, s, "0101"); back["on"] != true {
		t.Fatalf("got %v", back)
	}
	if back := mustUnpackMap(t, s, "0100"); len(back) != 0 {
		t.Fatalf("got %v", back)
	}
}

func TestNinthFlagBitIsASchemeError(t *testing.T) {
	// Arrange
	nine := append(eightU8(), U8(8, "f8"))
	m := FlagByte("m")
	bits := []Field{m}
	for _, f := range nine {
		bits = append(bits, m.Bit(f))
	}

	// Act
	_, combined := NewScheme(1, Flags(0, nine...))
	_, split := NewScheme(1, bits...)

	// Assert
	if e := asError(t, combined, InvalidScheme); e.Field != 8 {
		t.Fatalf("combined: %v", e)
	}
	if e := asError(t, split, InvalidScheme); e.Field != 8 {
		t.Fatalf("split: %v", e)
	}
}

func TestEightFlagBitsPackBothForms(t *testing.T) {
	// Arrange
	m := FlagByte("m")
	split := []Field{m}
	for _, f := range eightU8() {
		split = append(split, m.Bit(f))
	}
	schemes := []*Scheme{mustScheme(t, 1, Flags(0, eightU8()...)), mustScheme(t, 1, split...)}

	for _, s := range schemes {
		// Act
		wire := mustPack(t, s, map[string]any{"f0": 1, "f7": 7})
		back := mustUnpackMap(t, s, wire)

		// Assert
		if wire != "01810107" {
			t.Fatalf("got %s", wire)
		}
		if !reflect.DeepEqual(back, map[string]any{"f0": uint8(1), "f7": uint8(7)}) {
			t.Fatalf("got %v", back)
		}
	}
}

// Ported from typescript/tests/packbin.test.ts: flags width, absence and a set member of each width.
func TestFlagsWidthPresentZeroAndAbsence(t *testing.T) {
	// Arrange
	s := mustScheme(t, 1, Flags(0, U8(0, "a"), U8(1, "b"), U8(2, "c"), U8(3, "d"), U8(4, "e"), U16(5, "b5")))

	// Act
	one := mustPack(t, s, map[string]any{"a": 1})
	wide := mustPack(t, s, map[string]any{"b5": 1})
	none := mustPack(t, s, map[string]any{})

	// Assert
	if one != "010101" || wide != "01200100" || none != "0100" {
		t.Fatalf("one %s wide %s none %s", one, wide, none)
	}
}

// README Flags: a when member of flags is decided against the values written so far.
func TestWhenAsAFlagsMember(t *testing.T) {
	// Arrange
	s := mustScheme(t, 1, U8(0, "mode"), Flags(1, When(1, Eq(0, 1), U8(1, "speed")), U16(2, "heading")))

	// Act
	hit := mustPack(t, s, map[string]any{"mode": 1, "speed": 7, "heading": 90})
	miss := mustPack(t, s, map[string]any{"mode": 0, "speed": 7, "heading": 90})

	// Assert
	if hit != "010103075a00" || miss != "0100025a00" {
		t.Fatalf("hit %s miss %s", hit, miss)
	}
	if back := mustUnpackMap(t, s, hit); !reflect.DeepEqual(back, map[string]any{"mode": uint8(1), "speed": uint8(7), "heading": uint16(90)}) {
		t.Fatalf("got %v", back)
	}
}

// Hostile pack_split_false_condition_silent: a false condition under a split bit is a silent skip.
func TestSplitFalseConditionIsSilent(t *testing.T) {
	// Arrange
	m := FlagByte("m")
	s := mustScheme(t, 1, U8(0, "mode"), m, m.Bit(When(1, Eq(0, 1), U8(1, "speed"))), m.Bit(U16(2, "heading")))

	// Act
	wire := mustPack(t, s, map[string]any{"mode": 0, "speed": 7, "heading": 90})

	// Assert
	if wire != "0100025a00" {
		t.Fatalf("got %s", wire)
	}
}

// Hostile pack_split_when_source_after_byte: the byte is written before the when's source, so its bit
// is clear although the condition holds and the body is given; pack refuses, naming speed.
func TestSplitWhenSourceAfterByteIsRefused(t *testing.T) {
	// Arrange
	m := FlagByte("m")
	s := mustScheme(t, 1, m, U8(0, "mode"), m.Bit(When(1, Eq(0, 1), U8(1, "speed"))))

	// Act
	raw, err := Pack(s, map[string]any{"mode": 1, "speed": 7})
	quiet := mustPack(t, s, map[string]any{"mode": 0, "speed": 7})

	// Assert
	e := asError(t, err, PackRefused)
	if raw != nil || e.Field != 1 || e.Name != "speed" {
		t.Fatalf("raw %x err %v", raw, e)
	}
	if quiet != "010000" {
		t.Fatalf("false condition: %s", quiet)
	}
}

func TestSplitBitInsideWhenSeesTheByteBeforeIt(t *testing.T) {
	// Arrange
	m := FlagByte("m")
	s := mustScheme(t, 1, U8(0, "k"), m, When(1, Eq(0, 1), m.Bit(U8(1, "a"))), m.Bit(U8(2, "b")))

	// Act
	both := mustPack(t, s, map[string]any{"k": 1, "a": 5, "b": 6})
	skipped := mustPack(t, s, map[string]any{"k": 0, "a": 5, "b": 6})

	// Assert: as TypeScript, the split byte sets a's bit although its when does not match (a is given);
	// unpack reads no a, because the when does not match there either.
	if both != "0101030506" || skipped != "01000306" {
		t.Fatalf("both %s skipped %s", both, skipped)
	}
	if back := mustUnpackMap(t, s, skipped); !reflect.DeepEqual(back, map[string]any{"k": uint8(0), "b": uint8(6)}) {
		t.Fatalf("got %v", back)
	}
}

func TestFlagsNestedUnderASplitBit(t *testing.T) {
	// Arrange
	m := FlagByte("m")
	s := mustScheme(t, 1, m, m.Bit(Flags(0, U8(0, "a"), U8(1, "b"))), m.Bit(U8(2, "c")))

	// Act
	wire := mustPack(t, s, map[string]any{"b": 9, "c": 3})
	clear := mustPack(t, s, map[string]any{"c": 3})

	// Assert
	if wire != "0103020903" || clear != "010203" {
		t.Fatalf("wire %s clear %s", wire, clear)
	}
	if back := mustUnpackMap(t, s, wire); !reflect.DeepEqual(back, map[string]any{"b": uint8(9), "c": uint8(3)}) {
		t.Fatalf("got %v", back)
	}
}

func TestBigEndianUnderAFlagBit(t *testing.T) {
	// Arrange
	m := FlagByte("m")
	s := mustScheme(t, 1, m, Be(m.Bit(U16(0, "a"))))

	// Act
	wire := mustPack(t, s, map[string]any{"a": 0x1234})

	// Assert
	if wire != "01011234" {
		t.Fatalf("got %s", wire)
	}
}
