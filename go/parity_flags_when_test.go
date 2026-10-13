package packbin

import (
	"slices"
	"strings"
	"testing"
)

// AC-1: the AC-3 hex tables of flags-when-member (reference cases of loop 18) for the three shapes WA
// (a when as a flags member), WS (the same in a split flag byte) and WG (the when inside a group), and
// the W2, GS and WE rows. In the map form a group's values sit in a nested map (owner decision Go-4):
// the speed of WG is {"g": {"speed": 7}}, and unpack gives it back there; the bytes are TypeScript's.

func whenFlagsShapes(t testing.TB) (wa, ws, wg *Scheme) {
	speed := func() Field { return When(1, Eq(0, 1), U8(1, "speed")) }
	fb := FlagByte("m")
	wa = mustScheme(t, 1, U8(0, "mode"), Flags(1, speed(), U16(2, "heading")))
	ws = mustScheme(t, 1, U8(0, "mode"), fb, fb.Bit(speed()), fb.Bit(U16(2, "heading")))
	wg = mustScheme(t, 1, U8(0, "mode"), Flags(1, Group(1, "g", speed()), U16(2, "heading")))
	return wa, ws, wg
}

// shaped writes a speed into the row where the shape keeps it: flat, or inside the group's map.
func shaped(group bool, row map[string]any) map[string]any {
	speed, ok := row["speed"]
	if !ok || !group {
		return row
	}
	out := map[string]any{"g": map[string]any{"speed": speed}}
	for k, v := range row {
		if k != "speed" {
			out[k] = v
		}
	}
	return out
}

type whenRow struct {
	name   string
	row    map[string]any // nil: only unpacked
	wire   string
	unpack map[string]any
	// only: the shapes the row applies to ("flags", "split", "group"); empty means all three.
	only string
}

func TestAC1FlagsWhenMemberHexTables(t *testing.T) {
	rows := []whenRow{
		{"when true", gm("mode", 1, "speed", 7, "heading", 90), "010103075a00", gm("mode", 1, "speed", 7, "heading", 90), ""},
		{"when false", gm("mode", 0, "heading", 90), "0100025a00", gm("mode", 0, "heading", 90), ""},
		{"when true without body", gm("mode", 1, "heading", 90), "0101025a00", gm("mode", 1, "heading", 90), ""},
		{"when false with a body given", gm("mode", 0, "speed", 7, "heading", 90), "0100025a00", gm("mode", 0, "heading", 90), "flags split"},
		{"AC-5 old packet", nil, "0101025a00", gm("mode", 1, "heading", 90), ""},
		{"only the when", gm("mode", 1, "speed", 7), "01010107", gm("mode", 1, "speed", 7), "flags group"},
		{"flags only mode", gm("mode", 0), "010000", gm("mode", 0), "flags"},
		{"AC-5 flags new packet", nil, "010103075a00", gm("mode", 1, "speed", 7, "heading", 90), "flags"},
	}
	wa, ws, wg := whenFlagsShapes(t)
	shapes := []struct {
		name   string
		scheme *Scheme
		group  bool
	}{{"flags", wa, false}, {"split", ws, false}, {"group", wg, true}}
	for _, shape := range shapes {
		for _, r := range rows {
			if r.only != "" && !slices.Contains(strings.Fields(r.only), shape.name) {
				continue
			}
			t.Run("AC-3 "+shape.name+" "+r.name, func(t *testing.T) {
				// Arrange
				want := shaped(shape.group, r.unpack)

				// Act
				back := mustUnpackMap(t, shape.scheme, r.wire)

				// Assert
				if r.row != nil {
					if wire := mustPack(t, shape.scheme, shaped(shape.group, r.row)); wire != r.wire {
						t.Fatalf("packs %s, want %s", wire, r.wire)
					}
				}
				if !sameRow(back, want) {
					t.Fatalf("unpacks %#v, want %#v", back, want)
				}
			})
		}
	}
}

// WG "when false with a body given" (Go-4). TypeScript packs the flat row {mode 0, speed 7, heading 90}
// to 0100025a00: the flat speed is not read because the group's when is false, so the group is off.
// Go has no flat form for a group's member: given in the group's map {"g": {"speed": 7}} the group is
// given, so its bit is set (TypeScript packs the same nested row to 0100035a00, probed), and the flat
// row is refused naming the member. Unpack of 0100035a00 gives the group as an empty map.
func TestAC1FlagsWhenMemberGroupWhenFalseWithABodyGivenIsTheNestedFormsOutcome(t *testing.T) {
	_, _, wg := whenFlagsShapes(t)

	// Act
	nested := mustPack(t, wg, gm("mode", 0, "g", gm("speed", 7), "heading", 90))
	raw, flatErr := Pack(wg, gm("mode", 0, "speed", 7, "heading", 90))
	back := mustUnpackMap(t, wg, "0100035a00")

	// Assert
	if nested != "0100035a00" {
		t.Fatalf("nested packs %s, TypeScript packs the nested row to 0100035a00", nested)
	}
	if e := asError(t, flatErr, PackRefused); raw != nil || e.Name != "speed" {
		t.Fatalf("flat row: %x %v", raw, e)
	}
	if !sameRow(back, gm("mode", 0, "g", gm(), "heading", 90)) {
		t.Fatalf("unpacks %#v", back)
	}
}

// W2, WE and the range row of flags-when-member.
func TestAC1FlagsWhenMemberOtherShapes(t *testing.T) {
	w2 := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, U8(0, "mode"),
			Flags(1, When(1, Eq(0, 1), U8(1, "speed"), U8(2, "extra")), U16(3, "heading")))
	}
	we := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, Flags(0, U8(0, "mode"), When(1, Eq(0, 1), U8(1, "speed"))))
	}
	wa := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, U8(0, "mode"), Flags(1, When(1, Eq(0, 1), U8(1, "speed")), U16(2, "heading")))
	}
	runUnpackCases(t, []unpackCase{
		{"AC-3 two body values", w2, gm("mode", 1, "speed", 7, "extra", 8, "heading", 90), "01010307085a00",
			gm("mode", uint8(1), "speed", uint8(7), "extra", uint8(8), "heading", uint16(90))},
		{"AC-3 when names an earlier member of its own flags", we, gm("mode", 1, "speed", 7), "01030107",
			gm("mode", uint8(1), "speed", uint8(7))},
		{"AC-3 same-flags when false", we, gm("mode", 0, "speed", 7), "010100", gm("mode", uint8(0))},
		{"AC-3 same-flags when without body", we, gm("mode", 1), "010101", gm("mode", uint8(1))},
		{"AC-3 same-flags when without mode", we, gm("speed", 7), "0100", gm()},
	})
	runRefusals(t, []refusalCase{
		{"AC-3 W2 body value missing", w2, gm("mode", 1, "speed", 7, "heading", 90), 2, "extra", "extra"},
		{"AC-3 a body value outside its field range fails naming the field", wa, gm("mode", 1, "speed", 300, "heading", 90), 1,
			"speed", "does not fit"},
	})
	runPacks(t, []packCase{
		{"AC-6 a row that does not use the shape is unchanged", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Flags(0, U8(0, "a"), U16(1, "b")))
		}, gm("a", 1, "b", 2), "0103010200"},
	})
}

// flag-group-presence (AC-1, AC-2): a flags group is on when any value inside it is present. The
// group's values are in a nested map; the bytes are TypeScript's.
func TestAC1FlagGroupPresenceCountedKinds(t *testing.T) {
	u2Only := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, Flags(0, Group(0, "g", U2(Slot(0, "p"), Slot(1, "q")))))
	}
	bitsOnly := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, U8(0, "n"), Flags(1, Group(1, "g", Bits(1, "b", 0))))
	}
	sizedOnly := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, U8(0, "n"), Flags(1, Group(1, "g", Sized(1, "d", 0))))
	}
	packedOnly := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, U8(0, "n"), Flags(1, Group(1, "g", Packed(2, 1, "k", 0, 0))))
	}
	runUnpackCases(t, []unpackCase{
		{"AC-1 a u2-only group sets its bit and round-trips", u2Only, gm("g", gm("p", 1, "q", 2)), "010109",
			gm("g", gm("p", uint8(1), "q", uint8(2)))},
		{"AC-1 an anchored bits-only group sets its bit and round-trips", bitsOnly,
			gm("n", 8, "g", gm("b", []int{1, 0, 1, 0, 1, 0, 1, 0})), "01080155",
			gm("n", uint8(8), "g", gm("b", []uint8{1, 0, 1, 0, 1, 0, 1, 0}))},
		{"AC-1 a sized-only group sets its bit and round-trips", sizedOnly, gm("n", 1, "g", gm("d", []byte{9})), "01010109",
			gm("n", uint8(1), "g", gm("d", []byte{9}))},
		{"AC-1 a packed-only group sets its bit and round-trips", packedOnly, gm("n", 2, "g", gm("k", []int{1, 2})), "01020109",
			gm("n", uint8(2), "g", gm("k", []uint8{1, 2}))},
	})
	for _, c := range []struct {
		name   string
		scheme func(t testing.TB) *Scheme
		row    map[string]any
		hex    string
	}{
		{"u2", u2Only, gm(), "0100"},
		{"bits", bitsOnly, gm("n", 1), "010100"},
		{"sized", sizedOnly, gm("n", 1), "010100"},
		{"packed", packedOnly, gm("n", 1), "010100"},
	} {
		runPacks(t, []packCase{{"an absent group keeps its bit clear: " + c.name, c.scheme, c.row, c.hex}})
	}
	runRefusals(t, []refusalCase{
		{"AC-2 a u2 group with one slot set names the slot that is missing", u2Only, gm("g", gm("p", 1)), 1, "q", "q"},
		{"a u2 group with only its second slot set is on, and names the first slot", u2Only, gm("g", gm("q", 1)), 0, "p", "p"},
	})
}
