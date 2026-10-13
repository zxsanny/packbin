package packbin

import (
	"reflect"
	"strings"
	"testing"
)

func anchoredElem() Field { return Group(0, "p", U8(0, "a")) }

// buildRefusal builds the scheme and returns the InvalidScheme error it must give.
func buildRefusal(t testing.TB, fields ...Field) *Error {
	t.Helper()
	s, err := NewScheme(1, fields...)
	if s != nil || err == nil {
		t.Fatalf("scheme built: %v", err)
	}
	return asError(t, err, InvalidScheme)
}

// AC-2 (list-element-kinds, AC-1 to AC-5): a list or dict whose element is an anchored group is refused
// when the scheme is built, wherever it stands; a when or times element, a wrong id and an empty
// anchored group keep their refusals; an earlier refusal elsewhere in the scheme comes first.
func TestAC2ElementOfAnchoredGroupIsRefused(t *testing.T) {
	m := FlagByte("m")
	const msg = "element is an anchored group (p)"
	places := map[string][]Field{
		"a list":                {List("g", anchoredElem())},
		"a dict":                {Dict("g", anchoredElem())},
		"a when body":           {U8(0, "k"), When(1, Eq(0, 1), List("g", anchoredElem()))},
		"a repeat body":         {Repeat(0, List("g", anchoredElem()))},
		"a times body":          {U8(0, "n"), Times(1, 0, List("g", anchoredElem()))},
		"a nested row element":  {List("t", Nested("q", List("g", anchoredElem())))},
		"a flags member":        {Flags(0, List("g", anchoredElem()))},
		"a flag bit":            {m, m.Bit(List("g", anchoredElem()))},
		"flags in flags":        {Flags(0, Flags(0, List("g", anchoredElem())))},
		"the element of a dict": {Dict("t", Dict("u", Group(0, "g", U8(0, "a"))))},
	}
	for place, fields := range places {
		t.Run(place, func(t *testing.T) {
			// Act
			e := buildRefusal(t, fields...)

			// Assert
			if !strings.Contains(e.Reason, msg) && !strings.Contains(e.Reason, "element is an anchored group (g)") {
				t.Fatalf("got %v", e)
			}
		})
	}
	t.Run("a when element keeps its refusal", func(t *testing.T) {
		e := buildRefusal(t, List("w", When(0, Eq(0, 1), U8(0, "a"))))
		if !strings.Contains(e.Reason, "eq names field id 0, which is not declared earlier in the same scope") {
			t.Fatalf("got %v", e)
		}
	})
	t.Run("a times element keeps its refusal", func(t *testing.T) {
		e := buildRefusal(t, List("t", Times(0, 0, U8(0, "a"))))
		if !strings.Contains(e.Reason, "count names field id 0, which is not declared earlier in the same scope") {
			t.Fatalf("got %v", e)
		}
	})
	t.Run("a wrong field id keeps its refusal", func(t *testing.T) {
		e := buildRefusal(t, List("g", Group(1, "p", U8(1, "a"))))
		if e.Field != 1 || !strings.Contains(e.Reason, "expected 0, got 1") {
			t.Fatalf("got %+v", e)
		}
	})
	t.Run("a flags element anchor must be 0", func(t *testing.T) {
		e := buildRefusal(t, List("pts", Flags(1, U8(1, "a"))))
		if !strings.Contains(e.Reason, "expected 0, got 1") {
			t.Fatalf("got %v", e)
		}
	})
	t.Run("an empty anchored group keeps its refusal", func(t *testing.T) {
		e := buildRefusal(t, List("g", Group(0, "p")))
		if !strings.Contains(e.Reason, "empty group p: allowed only directly inside flags or a flag bit") {
			t.Fatalf("got %v", e)
		}
	})
	t.Run("an earlier refusal elsewhere comes first", func(t *testing.T) {
		e := buildRefusal(t, List("g", anchoredElem()), When(0, Eq(5, 1), U8(0, "b")))
		if !strings.Contains(e.Reason, "eq names field id 5") {
			t.Fatalf("got %v", e)
		}
	})
	t.Run("a repeat, a u2, a bool and a sized cannot be an element", func(t *testing.T) {
		for _, f := range []Field{Repeat(0, U8(0, "a")), U2(Slot(0, "a")), Bool(0, "on"), Sized(0, "d", 0), nil} {
			if e := buildRefusal(t, List("x", f)); e.Reason == "" {
				t.Fatalf("no reason")
			}
		}
		if e := buildRefusal(t, Dict("x", Repeat(0, U8(0, "a")))); !strings.Contains(e.Reason, "repeat is not a dictionary element") {
			t.Fatalf("got %v", e)
		}
	})
}

// AC-2 (list-element-kinds AC-6): elements that work keep their bytes, and the unpacked row repacks to them.
func TestAC2ElementsThatWorkKeepTheirBytes(t *testing.T) {
	cases := []struct {
		name   string
		scheme func(t testing.TB) *Scheme
		row    map[string]any
		wire   string
	}{
		{"list of group", pairNested, gm("pts", []any{gm("a", 1, "b", 2), gm("a", 3, "b", 4)}), "01020001020304"},
		{"dict of group", dictPairNested, gm("m", map[string]any{"y": gm("a", 3, "b", 4), "x": gm("a", 1, "b", 2)}),
			"01020001007801020100790304"},
		{"list of flags", listFlagsScheme, gm("pts", []any{gm("a", 1), gm(), gm("b", 2)}), "010300010100020200"},
		{"list of leaf", func(t testing.TB) *Scheme { return mustScheme(t, 1, List("t", U8(0, "p"))) }, gm("t", []any{1, 2}), "0102000102"},
		{"list of list of group", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, List("t", List("u", Nested("g", U8(0, "a")))))
		}, gm("t", []any{[]any{gm("a", 1)}}), "010100010001"},
		{"anchored group inside the element", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, List("t", Nested("g", U8(0, "a"), Group(1, "q", U8(1, "b")))))
		}, gm("t", []any{gm("a", 1, "q", gm("b", 2))}), "0101000102"},
		{"when inside the element", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, List("t", Nested("g", U8(0, "a"), When(1, Eq(0, 1), U8(1, "b")))))
		}, gm("t", []any{gm("a", 1, "b", 2), gm("a", 0)}), "010200010200"},
		{"times inside the element", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, List("t", Nested("g", U8(0, "a"), Times(1, 0, U8(1, "b")))))
		}, gm("t", []any{gm("a", 2, "b", []any{3, 4})}), "010100020304"},
		{"anchored group beside a list of group", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Group(0, "h", U8(0, "k")), List("pts", Nested("p", U8(0, "a"))))
		}, gm("h", gm("k", 7), "pts", []any{gm("a", 1)}), "0107010001"},
		{"top-level anchored group", func(t testing.TB) *Scheme { return mustScheme(t, 1, Group(0, "g", U8(0, "a"))) },
			gm("g", gm("a", 1)), "0101"},
		{"big-endian element", func(t testing.TB) *Scheme { return mustScheme(t, 1, List("xs", Be(U16(0, "n")))) },
			gm("xs", []any{1}), "0101000001"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Arrange
			s := c.scheme(t)

			// Act
			wire, _, again := repack(t, s, c.row)

			// Assert
			if wire != c.wire || again != c.wire {
				t.Fatalf("wire %s, repack %s, want %s", wire, again, c.wire)
			}
		})
	}
}

// AC-2 (list-group-elements): the unpacked shape, absent members, items that are not objects, names
// shared with the row, references inside an item, a list in an item, a group element in a round.
func TestAC2GroupAndFlagsElements(t *testing.T) {
	t.Run("list of group unpacks each item", func(t *testing.T) {
		got := mustUnpackMap(t, pairNested(t), "01020001020304")
		want := gm("pts", []any{gm("a", uint8(1), "b", uint8(2)), gm("a", uint8(3), "b", uint8(4))})
		if !reflect.DeepEqual(got, want) {
			t.Fatalf("got %#v", got)
		}
	})
	t.Run("dict of flags", func(t *testing.T) {
		s := mustScheme(t, 1, Dict("m", Flags(0, U8(0, "a"), U16(1, "b"))))
		wire := "01" + "0200" + "0100" + "78" + "00" + "0100" + "79" + "02" + "0200"
		packed := mustPack(t, s, gm("m", map[string]any{"y": gm("b", 2), "x": gm()}))
		got := mustUnpackMap(t, s, wire)
		if packed != wire || !reflect.DeepEqual(got, gm("m", map[string]any{"x": gm(), "y": gm("b", uint16(2))})) {
			t.Fatalf("packed %s, got %#v", packed, got)
		}
	})
	t.Run("leaf elements", func(t *testing.T) {
		s := mustScheme(t, 1, List("ids", U16(0, "id")), Dict("names", Utf8(0, "name")))
		wire := "01" + "0200" + "0100" + "0200" + "0100" + "0100" + "6b" + "0100" + "76"
		got := mustPack(t, s, gm("ids", []any{1, 2}, "names", map[string]string{"k": "v"}))
		if got != wire {
			t.Fatalf("got %s", got)
		}
	})
	t.Run("an absent member names it", func(t *testing.T) {
		runRefusals(t, []refusalCase{
			{"absent b", pairNested, gm("pts", []any{gm("a", 1, "b", 2), gm("a", 3)}), 1, "b", "missing b"},
			{"an item that is not an object", pairNested, gm("pts", []any{7}), -1, "pts", "pts"},
			{"a nil item", pairNested, gm("pts", []any{nil}), -1, "pts", "no value"},
			{"not a list", pairNested, gm("pts", 7), -1, "pts", "expected a list"},
			{"no list", pairNested, gm(), -1, "pts", "expected a list"},
		})
	})
	t.Run("element members do not collide with row members of the same name", func(t *testing.T) {
		s := mustScheme(t, 1, U8(0, "a"), List("pts", Nested("p", U8(0, "a"), U8(1, "b"))))
		wire := "01" + "09" + "0100" + "0102"
		got, back, _ := repack(t, s, gm("a", 9, "pts", []any{gm("a", 1, "b", 2)}))
		if got != wire || back["a"] != uint8(9) {
			t.Fatalf("got %s %#v", got, back)
		}
	})
	t.Run("a reference inside an element reads the item it sits in", func(t *testing.T) {
		s := mustScheme(t, 1, List("rows", Nested("row", U8(0, "n"), Sized(1, "d", 0))))
		wire := "01" + "0200" + "01" + "aa" + "02" + "0102"
		row := gm("rows", []any{gm("n", 1, "d", []byte{0xaa}), gm("n", 2, "d", []byte{1, 2})})
		packed, back, again := repack(t, s, row)
		if packed != wire || again != wire || len(back["rows"].([]any)) != 2 {
			t.Fatalf("packed %s again %s", packed, again)
		}
	})
	t.Run("a list inside a group element has its own ids and items", func(t *testing.T) {
		s := mustScheme(t, 1, List("pts", Nested("p", U8(0, "a"), List("tags", U8(0, "t")))))
		wire := "01" + "0200" + "01" + "0200" + "0708" + "02" + "0000"
		row := gm("pts", []any{gm("a", 1, "tags", []any{7, 8}), gm("a", 2, "tags", []any{})})
		packed, back, _ := repack(t, s, row)
		want := gm("pts", []any{gm("a", uint8(1), "tags", []any{uint8(7), uint8(8)}), gm("a", uint8(2), "tags", []any{})})
		if packed != wire || !reflect.DeepEqual(back, want) {
			t.Fatalf("packed %s back %#v", packed, back)
		}
	})
	t.Run("a flags element keeps its flag byte apart from the flags of the row", func(t *testing.T) {
		s := mustScheme(t, 1, Flags(0, U8(0, "t")), List("pts", Flags(0, U8(0, "a"))))
		wire := "01" + "01" + "05" + "0200" + "01" + "01" + "00"
		packed, back, _ := repack(t, s, gm("t", 5, "pts", []any{gm("a", 1), gm()}))
		if packed != wire || !reflect.DeepEqual(back, gm("t", uint8(5), "pts", []any{gm("a", uint8(1)), gm()})) {
			t.Fatalf("packed %s back %#v", packed, back)
		}
	})
	t.Run("a bool in a flags element sets its bit only for true", func(t *testing.T) {
		s := mustScheme(t, 1, List("pts", Flags(0, Bool(0, "on"), U8(1, "n"))))
		items := []any{gm("on", true, "n", 3), gm("n", 4), gm("on", true)}
		wire := "01" + "0300" + "03" + "03" + "02" + "04" + "01"
		packed, back, _ := repack(t, s, gm("pts", items))
		want := []any{gm("on", true, "n", uint8(3)), gm("n", uint8(4)), gm("on", true)}
		if packed != wire || !reflect.DeepEqual(back["pts"], want) {
			t.Fatalf("packed %s back %#v", packed, back)
		}
	})
}

// AC-2: a group element in a repeat round packs the items of each round; a list per round.
func TestAC2ListInARepeatRound(t *testing.T) {
	s := mustScheme(t, 1, Repeat(0, U8(0, "k"), List("rows", Nested("p", U8(0, "a"), U8(1, "b")))))
	rows := []any{[]any{gm("a", 1, "b", 2)}, []any{gm("a", 3, "b", 4), gm("a", 5, "b", 6)}}
	wire := "01" + "01" + "0100" + "0102" + "02" + "0200" + "0304" + "0506"

	// Act
	packed, back, again := repack(t, s, gm("k", []any{1, 2}, "rows", rows))

	// Assert
	want := []any{[]any{gm("a", uint8(1), "b", uint8(2))},
		[]any{gm("a", uint8(3), "b", uint8(4)), gm("a", uint8(5), "b", uint8(6))}}
	if packed != wire || again != wire || !reflect.DeepEqual(back["rows"], want) {
		t.Fatalf("packed %s again %s back %#v", packed, again, back)
	}
}
