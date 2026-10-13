package packbin

import (
	"reflect"
	"testing"
)

type groupRow struct {
	name   string
	scheme func(t testing.TB) *Scheme
	row    map[string]any
	wire   string
	back   map[string]any // nil: unpack gives row back
}

func gm(kv ...any) map[string]any {
	m := map[string]any{}
	for i := 0; i < len(kv); i += 2 {
		m[kv[i].(string)] = kv[i+1]
	}
	return m
}

func nestedFlagsScheme(t testing.TB) *Scheme {
	return mustScheme(t, 1, Flags(0, Group(0, "g", Flags(0, U8(0, "n")))))
}

func nestedGroupScheme(t testing.TB) *Scheme {
	return mustScheme(t, 1, Flags(0, Group(0, "g", Group(0, "h", U8(0, "n")))))
}

func siblingAndFlagsScheme(t testing.TB) *Scheme {
	return mustScheme(t, 1, Flags(0, Group(0, "g", U8(0, "a"), Flags(1, U8(1, "c")))))
}

// WG of flags-when-member: a when inside a group under flags.
func whenGroupScheme(t testing.TB) *Scheme {
	return mustScheme(t, 1, U8(0, "mode"), Flags(1, Group(1, "g", When(1, Eq(0, 1), U8(1, "speed"))), U16(2, "heading")))
}

// GS of flags-when-member: a group sibling of the when.
func groupSiblingScheme(t testing.TB) *Scheme {
	return mustScheme(t, 1, U8(0, "mode"),
		Flags(1, Group(1, "g", U8(1, "extra"), When(2, Eq(0, 1), U8(2, "speed"))), U16(3, "heading")))
}

func anchoredFlagsScheme(t testing.TB) *Scheme {
	return mustScheme(t, 1, U8(0, "a"), Group(1, "g", U8(1, "b"), Flags(2, U8(2, "c"))))
}

func splitInGroupScheme(t testing.TB) *Scheme {
	fb := FlagByte("m")
	return mustScheme(t, 1, Group(0, "g", fb, fb.Bit(U8(0, "c")), fb.Bit(U16(1, "d"))))
}

func whenBranchGroupScheme(t testing.TB) *Scheme {
	return mustScheme(t, 1, U8(0, "kind"), When(1, Eq(0, 0), Group(1, "g", U8(1, "shape"))), When(2, Eq(0, 1), U16(2, "shape")))
}

// README Flags (loop 21): a late when in a split bit's group packs when another member holds a value.
func readmeLateWhenScheme(t testing.TB) *Scheme {
	fb := FlagByte("fb")
	return mustScheme(t, 1, fb, U8(0, "mode"),
		fb.Bit(Group(1, "g", U8(1, "d"), When(2, Eq(0, 1), U8(2, "a")), When(3, Eq(0, 2), U8(3, "b")))))
}

// AC-4: the TypeScript flag-group-presence and nested-group rows that need no round or collection,
// with the group's values in a nested map (owner decision U26 A). Each row packs to its wire, the wire
// unpacks to the row (or back), and that row packs to the same wire.
func TestAC4AnchoredGroupMapRows(t *testing.T) {
	rows := []groupRow{
		{"presence: group holding only flags", nestedFlagsScheme, gm("g", gm("n", 5)), "01010105", nil},
		{"presence: group holding only a group", nestedGroupScheme, gm("g", gm("h", gm("n", 5))), "010105", nil},
		{"presence: absent nested flags", nestedFlagsScheme, gm(), "0100", nil},
		{"presence: absent nested group", nestedGroupScheme, gm(), "0100", nil},
		{"presence: sibling and nested value", siblingAndFlagsScheme, gm("g", gm("a", 1, "c", 2)), "0101010102", nil},
		{"presence: an empty map sets the bit", nestedFlagsScheme, gm("g", gm()), "010100", nil},
		{"nested: flags inside an anchored group", anchoredFlagsScheme, gm("a", 1, "g", gm("b", 2, "c", 3)), "0101020103", nil},
		{"nested: flags member left out", anchoredFlagsScheme, gm("a", 1, "g", gm("b", 2)), "01010200", nil},
		{"nested: split byte in a group, both bits", splitInGroupScheme, gm("g", gm("c", 3, "d", 4)), "0103030400", nil},
		{"nested: split byte in a group, one bit", splitInGroupScheme, gm("g", gm("d", 4)), "01020400", nil},
		{"nested: flag byte in a group sees its own bits", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Flags(0, U8(0, "a")), Group(1, "g", Flags(1, U8(1, "b"))))
		}, gm("g", gm("b", 2)), "01000102", nil},
		{"nested: an anchored group shares the scope, other branch", whenBranchGroupScheme, gm("kind", 1, "shape", 300),
			"01012c01", nil},
		{"nested: an anchored group shares the scope, group branch", whenBranchGroupScheme, gm("kind", 0, "g", gm("shape", 5)),
			"010005", nil},
		{"group under flags given as a map", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Flags(0, Group(0, "g", U8(0, "b"))))
		}, gm("g", gm("b", 2)), "010102", nil},
		{"top-level anchored group", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Group(0, "g", U8(0, "a")))
		}, gm("g", gm("a", 1)), "0101", nil},
		{"a when after a group names its member", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Group(0, "g", U8(0, "n")), When(1, Eq(0, 1), U8(1, "v")))
		}, gm("g", gm("n", 1), "v", 7), "010107", nil},
		{"a group is transparent to the flag byte scope", func(t testing.TB) *Scheme {
			fb := FlagByte("fb")
			return mustScheme(t, 1, Group(0, "g", fb), fb.Bit(U8(0, "a")))
		}, gm("a", 5), "010105", gm("g", gm(), "a", 5)},
		{"a bit is numbered before the bits nested in its group", func(t testing.TB) *Scheme {
			m := FlagByte("m")
			return mustScheme(t, 1, m, m.Bit(Group(0, "g", U8(0, "y"), m.Bit(U8(1, "x")))))
		}, gm("g", gm("y", 1, "x", 2)), "01030102", nil},
		{"README late when in a group", readmeLateWhenScheme, gm("mode", 1, "g", gm("d", 5, "a", 9)), "0101010509", nil},
		{"empty group mark set", func(t testing.TB) *Scheme { return mustScheme(t, 1, Flags(0, Group(0, "mark"))) },
			gm("mark", true), "0101", nil},
		{"empty group mark false", func(t testing.TB) *Scheme { return mustScheme(t, 1, Flags(0, Group(0, "mark"))) },
			gm("mark", false), "0100", gm()},
		{"empty group mark split", func(t testing.TB) *Scheme {
			m := FlagByte("m")
			return mustScheme(t, 1, m, m.Bit(Group(0, "mark")), m.Bit(U8(0, "n")))
		}, gm("mark", true, "n", 3), "010303", nil},
	}
	rows = append(rows, whenGroupRows()...)
	for _, c := range rows {
		t.Run(c.name, func(t *testing.T) {
			// Arrange
			s := c.scheme(t)
			want := c.back
			if want == nil {
				want = c.row
			}

			// Act
			wire := mustPack(t, s, c.row)
			back := mustUnpackMap(t, s, c.wire)

			// Assert
			if wire != c.wire {
				t.Fatalf("pack %s, want %s", wire, c.wire)
			}
			if !sameRow(back, want) {
				t.Fatalf("unpack %#v, want %#v", back, want)
			}
			if again := mustPack(t, s, back); again != c.wire {
				t.Fatalf("repack %s", again)
			}
		})
	}
}

// flags-when-member WG and GS rows, the group's values nested.
func whenGroupRows() []groupRow {
	return []groupRow{
		{"WG when true", whenGroupScheme, gm("mode", 1, "g", gm("speed", 7), "heading", 90), "010103075a00", nil},
		{"WG when false", whenGroupScheme, gm("mode", 0, "heading", 90), "0100025a00", nil},
		{"WG when true without body", whenGroupScheme, gm("mode", 1, "heading", 90), "0101025a00", nil},
		{"WG only the when", whenGroupScheme, gm("mode", 1, "g", gm("speed", 7)), "01010107", nil},
		{"GS sibling with the when true", groupSiblingScheme, gm("mode", 1, "g", gm("extra", 4, "speed", 7), "heading", 90),
			"01010304075a00", nil},
		{"GS sibling with the when false", groupSiblingScheme, gm("mode", 0, "g", gm("extra", 4), "heading", 90),
			"010003045a00", nil},
		{"GS group with nothing in it", groupSiblingScheme, gm("mode", 1, "heading", 90), "0101025a00", nil},
	}
}

// sameRow compares rows with the numbers as the Go types unpack gives; a test row uses int literals.
func sameRow(got, want map[string]any) bool {
	if len(got) != len(want) {
		return false
	}
	for k, w := range want {
		g, ok := got[k]
		if !ok {
			return false
		}
		switch wv := w.(type) {
		case map[string]any:
			gv, isMap := g.(map[string]any)
			if !isMap || !sameRow(gv, wv) {
				return false
			}
		case int:
			if !sameValue(g, wv) {
				return false
			}
		default:
			if !reflect.DeepEqual(g, w) {
				return false
			}
		}
	}
	return true
}

// AC-4: the refusals of the same tests: a set group with a required member missing names it.
func TestAC4AnchoredGroupMapRefusals(t *testing.T) {
	cases := []struct {
		name   string
		scheme func(t testing.TB) *Scheme
		row    map[string]any
		field  int
		member string
	}{
		{"sibling missing", siblingAndFlagsScheme, gm("g", gm("c", 2)), 0, "a"},
		{"GS when body missing", groupSiblingScheme, gm("mode", 1, "g", gm("extra", 4), "heading", 90), 2, "speed"},
		{"GS sibling missing, group on through the when", groupSiblingScheme, gm("mode", 1, "g", gm("speed", 7), "heading", 90),
			1, "extra"},
		{"top-level group not given", anchoredFlagsScheme, gm("a", 1), 1, "b"},
		{"group given a number", anchoredFlagsScheme, gm("a", 1, "g", 5), 1, "g"},
		{"group given a typed struct", anchoredFlagsScheme, gm("a", 1, "g", struct{ B uint8 }{2}), 1, "g"},
		{"member out of range", anchoredFlagsScheme, gm("a", 1, "g", gm("b", 300)), 1, "b"},
		// U26 A: a member's value is read from the group's map, never from the row around it.
		{"member given flat", anchoredFlagsScheme, gm("a", 1, "b", 2), 1, "b"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Act
			raw, err := Pack(c.scheme(t), c.row)

			// Assert
			e := asError(t, err, PackRefused)
			if raw != nil || e.Field != c.field || e.Name != c.member {
				t.Fatalf("raw %x err %v", raw, e)
			}
		})
	}
}

// U26 A: a value given flat for a member of an absent group under flags is not the group's: the bit
// stays clear (TypeScript sets it from the flat value and refuses the missing sibling).
func TestU26FlatMemberDoesNotSetTheGroupBit(t *testing.T) {
	// Arrange
	s := siblingAndFlagsScheme(t)

	// Act
	wire := mustPack(t, s, gm("c", 2))

	// Assert
	if wire != "0100" {
		t.Fatalf("got %s", wire)
	}
}

// AC-4: unpack of a group reads its members into its map; a short packet names the member.
func TestAC4GroupShortPacketNamesTheMember(t *testing.T) {
	// Arrange
	s := anchoredFlagsScheme(t)

	// Act
	row, err := UnpackMap(mustHex(t, "010102"), s)

	// Assert
	e := asError(t, err, ShortPacket)
	if row != nil || e.Field != 2 || e.Needed != 1 || e.Left != 0 {
		t.Fatalf("row %v err %+v", row, e)
	}
}

// Hostile pack_split_when_source_after_byte with a group as the when body: the dropped value is named
// by the group, as TypeScript names it; a false condition stays a silent skip.
func TestSplitWhenSourceAfterByteNamesTheGroup(t *testing.T) {
	// Arrange
	m := FlagByte("m")
	s := mustScheme(t, 1, m, U8(0, "mode"), m.Bit(When(1, Eq(0, 1), Group(1, "g", U8(1, "a")))))

	// Act
	raw, err := Pack(s, gm("mode", 1, "g", gm("a", 5)))
	quiet := mustPack(t, s, gm("mode", 0, "g", gm("a", 5)))

	// Assert
	e := asError(t, err, PackRefused)
	if raw != nil || e.Field != 1 || e.Name != "g" {
		t.Fatalf("raw %x err %v", raw, e)
	}
	if quiet != "010000" {
		t.Fatalf("false condition: %s", quiet)
	}
}

// Go-1 applies to a name only a bool declares: when branches that declare one name as a bool and as
// an integer take either value, and each branch writes its own.
func TestGo1NameSharedByWhenBranchesTakesEitherKind(t *testing.T) {
	// Arrange
	s := mustScheme(t, 1, U8(0, "k"), When(1, Eq(0, 0), Flags(1, Bool(1, "x"))), When(2, Eq(0, 1), U8(2, "x")))

	// Act
	asInt := mustPack(t, s, gm("k", 1, "x", 7))
	asBool := mustPack(t, s, gm("k", 0, "x", true))

	// Assert
	if asInt != "010107" || asBool != "010001" {
		t.Fatalf("int %s bool %s", asInt, asBool)
	}
}
