package packbin

import (
	"reflect"
	"strings"
	"testing"
)

type innerRow struct {
	Mode uint8
	X    uint8
}

type outerRow struct {
	Mode uint8
	In   innerRow
}

type outerPtrRow struct {
	Mode uint8
	In   *innerRow
}

func repeatingNamesMap(t testing.TB) *Scheme {
	return mustScheme(t, 1, U8(0, "mode"), Nested("in", U8(0, "mode"), U8(1, "x")))
}

func outerTyped(t testing.TB) *Scheme {
	return mustScheme(t, 1,
		Bind(U8(0, "mode"), func(r *outerRow) uint8 { return r.Mode }, func(r *outerRow, v uint8) { r.Mode = v }),
		Bind(Nested("in",
			Bind(U8(0, "mode"), func(r *innerRow) uint8 { return r.Mode }, func(r *innerRow, v uint8) { r.Mode = v }),
			Bind(U8(1, "x"), func(r *innerRow) uint8 { return r.X }, func(r *innerRow, v uint8) { r.X = v }),
		), func(r *outerRow) innerRow { return r.In }, func(r *outerRow, v innerRow) { r.In = v }),
	)
}

func outerPtrTyped(t testing.TB) *Scheme {
	return mustScheme(t, 1,
		Bind(U8(0, "mode"), func(r *outerPtrRow) uint8 { return r.Mode }, func(r *outerPtrRow, v uint8) { r.Mode = v }),
		Bind(Nested("in",
			Bind(U8(0, "mode"), func(r *innerRow) uint8 { return r.Mode }, func(r *innerRow, v uint8) { r.Mode = v }),
			Bind(U8(1, "x"), func(r *innerRow) uint8 { return r.X }, func(r *innerRow, v uint8) { r.X = v }),
		), func(r *outerPtrRow) *innerRow { return r.In }, func(r *outerPtrRow, v *innerRow) { r.In = v }),
	)
}

// AC-3 (U26 A, Go-4): a nested-row group whose names repeat the outer names reads its values from the
// nested map or the nested struct, never from the outer row; the two forms give the same bytes.
func TestAC3NestedMapAndStructGiveTheSameBytes(t *testing.T) {
	const wire = "01010203"
	// Arrange
	mapScheme, typed, pointer := repeatingNamesMap(t), outerTyped(t), outerPtrTyped(t)

	// Act
	fromMap := mustPack(t, mapScheme, gm("mode", 1, "in", gm("mode", 2, "x", 3)))
	fromStruct := mustPack(t, typed, &outerRow{Mode: 1, In: innerRow{Mode: 2, X: 3}})
	fromPointer := mustPack(t, pointer, &outerPtrRow{Mode: 1, In: &innerRow{Mode: 2, X: 3}})
	fromTypedMap := mustPack(t, typed, gm("mode", 1, "in", gm("mode", 2, "x", 3)))

	// Assert
	for name, got := range map[string]string{"map": fromMap, "struct": fromStruct, "pointer": fromPointer, "typed scheme, map row": fromTypedMap} {
		if got != wire {
			t.Fatalf("%s packed %s, want %s", name, got, wire)
		}
	}
}

func TestAC3NestedRowUnpacksToTheNestedMapAndStruct(t *testing.T) {
	// Arrange
	const wire = "01010203"

	// Act
	asMap := mustUnpackMap(t, repeatingNamesMap(t), wire)
	asStruct, err := Unpack(mustHex(t, wire), outerTyped(t))
	asPointer, perr := Unpack(mustHex(t, wire), outerPtrTyped(t))

	// Assert
	if !reflect.DeepEqual(asMap, gm("mode", uint8(1), "in", gm("mode", uint8(2), "x", uint8(3)))) {
		t.Fatalf("map %#v", asMap)
	}
	if err != nil || !reflect.DeepEqual(asStruct, &outerRow{Mode: 1, In: innerRow{Mode: 2, X: 3}}) {
		t.Fatalf("struct %#v %v", asStruct, err)
	}
	if perr != nil || !reflect.DeepEqual(asPointer, &outerPtrRow{Mode: 1, In: &innerRow{Mode: 2, X: 3}}) {
		t.Fatalf("pointer %#v %v", asPointer, perr)
	}
}

func TestAC3NestedRowNeverReadsTheOuterRow(t *testing.T) {
	runRefusals(t, []refusalCase{
		{"the inner name only in the outer row", repeatingNamesMap, gm("mode", 1, "in", gm("x", 3)), 0, "mode", "missing mode"},
		{"a flat key naming an inner member", repeatingNamesMap, gm("mode", 1, "x", 3), 1, "x", "member of group in"},
		{"the group not given", repeatingNamesMap, gm("mode", 1), 0, "mode", "missing mode"},
		{"the group given as a number", repeatingNamesMap, gm("mode", 1, "in", 5), -1, "in", "expected a map[string]any"},
	})
}

// AC-2 (nested-group): flags and a flag byte inside a nested row.
func TestAC2FlagsInsideANestedRow(t *testing.T) {
	split := func(t testing.TB) *Scheme {
		fb := FlagByte("m")
		return mustScheme(t, 1, Nested("g", fb, fb.Bit(U8(0, "c")), fb.Bit(U16(1, "d"))))
	}
	rows := []groupRow{
		{"flags inside a nested row", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, U8(0, "a"), Nested("g", U8(0, "b"), Flags(1, U8(1, "c"))))
		}, gm("a", 1, "g", gm("b", 2, "c", 3)), "0101020103", nil},
		{"flags member left out", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, U8(0, "a"), Nested("g", U8(0, "b"), Flags(1, U8(1, "c"))))
		}, gm("a", 1, "g", gm("b", 2)), "01010200", nil},
		{"a split flag byte finds its bits in the nested row, both", split, gm("g", gm("c", 3, "d", 4)), "0103030400", nil},
		{"a split flag byte, one bit", split, gm("g", gm("d", 4)), "01020400", nil},
		{"flags under a flag bit of a nested row", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Flags(0, Nested("g", Flags(0, U8(0, "n")))))
		}, gm("g", gm("n", 5)), "01010105", nil},
		{"a flag byte read in a nested row sees only its own bits", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Flags(0, U8(0, "a")), Nested("g", Flags(0, U8(0, "b"))))
		}, gm("g", gm("b", 2)), "01000102", nil},
		{"a nested row under flags", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Flags(0, Nested("g", U8(0, "b"))))
		}, gm("g", gm("b", 2)), "010102", nil},
		{"an empty nested row is a mark", func(t testing.TB) *Scheme { return mustScheme(t, 1, Flags(0, Nested("mark"))) },
			gm("mark", true), "0101", nil},
		{"an absent nested row clears its bit", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Flags(0, Nested("g", U8(0, "b"))))
		}, gm(), "0100", nil},
	}
	for _, c := range rows {
		t.Run(c.name, func(t *testing.T) {
			// Act
			wire, back, again := repack(t, c.scheme(t), c.row)

			// Assert
			want := c.row
			if c.back != nil {
				want = c.back
			}
			if wire != c.wire || again != c.wire || len(back) != len(want) {
				t.Fatalf("wire %s again %s back %#v, want %s", wire, again, back, c.wire)
			}
		})
	}
}

// A nested row has references of its own: a when and a count name its own fields, not the row's.
func TestNestedRowHasItsOwnIdsAndReferences(t *testing.T) {
	whenIn := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, U8(0, "k"), Nested("g", U8(0, "m"), When(1, Eq(0, 1), U8(1, "v"))))
	}
	sizedIn := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, U8(0, "n"), Nested("g", U8(0, "n"), Sized(1, "d", 0)))
	}
	runPacks(t, []packCase{
		{"the when reads the nested field 0", whenIn, gm("k", 0, "g", gm("m", 1, "v", 7)), "01000107"},
		{"not the outer field 0", whenIn, gm("k", 1, "g", gm("m", 0)), "010100"},
		{"the sized reads the nested count", sizedIn, gm("n", 9, "g", gm("n", 2, "d", []byte{5, 6})), "0109020506"},
	})
	if got := mustUnpackMap(t, sizedIn(t), "0109020506"); !reflect.DeepEqual(got, gm("n", uint8(9), "g", gm("n", uint8(2), "d", []byte{5, 6}))) {
		t.Fatalf("got %#v", got)
	}
}

// AC-2 (nested-group, member names): a nested row names its members in a scope of its own, so they may
// repeat a name of the row around it (TypeScript flattens the row and refuses these); a name declared
// twice in one scope, or a group named like a member beside it, is still refused.
func TestNestedRowNames(t *testing.T) {
	builds := map[string][]Field{
		"a member shadowing an outer member":     {U8(0, "sid"), Nested("g", U8(0, "sid"))},
		"a group named like its child":           {Flags(0, Nested("session", U16(0, "session")))},
		"two groups sharing a member name":       {Nested("first", U8(0, "n")), Nested("second", U8(0, "n"))},
		"a group in a group sharing a member":    {Nested("outer", U8(0, "n"), Nested("inner", U8(0, "n")))},
		"a group in a round, an outer name":      {U8(0, "k"), Repeat(1, Nested("g", U8(0, "k")))},
		"a list named like a member of a group":  {List("l", U8(0, "e")), Nested("g", U8(0, "l"))},
		"a member under flags and in the group":  {Flags(0, U8(0, "v")), Nested("g", U8(0, "v"))},
		"a u2 slot named like a member of group": {U2(Slot(0, "a"), Slot(1, "b")), Nested("g", U8(0, "b"))},
	}
	for name, fields := range builds {
		t.Run("builds: "+name, func(t *testing.T) {
			if _, err := NewScheme(1, fields...); err != nil {
				t.Fatalf("refused: %v", err)
			}
		})
	}
	refused := map[string][]Field{
		"the group named like a member beside it": {U8(0, "g"), Nested("g", U8(0, "b"))},
		"a name twice inside the group":           {Nested("g", U8(0, "b"), U8(1, "b"))},
		"an anchored group member named like one": {U8(0, "a"), Group(1, "g", U8(1, "a"))},
	}
	for name, fields := range refused {
		t.Run("refused: "+name, func(t *testing.T) {
			if e := buildRefusal(t, fields...); !strings.Contains(e.Reason, "declared twice") {
				t.Fatalf("got %v", e)
			}
		})
	}
}

func TestNestedRowIdsStartAtZero(t *testing.T) {
	if _, err := NewScheme(1, U8(0, "a"), Nested("g", U8(0, "b"), U8(1, "c")), U8(1, "d")); err != nil {
		t.Fatalf("refused: %v", err)
	}
	e := buildRefusal(t, Nested("g", U8(1, "b")))
	if e.Field != 1 || !strings.Contains(e.Reason, "expected 0, got 1") {
		t.Fatalf("got %+v", e)
	}
}
