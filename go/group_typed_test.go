package packbin

import (
	"reflect"
	"testing"
)

type gInner struct {
	B uint8
	C *uint8
}

type gOuter struct {
	A uint8
	G *gInner
}

type gByValue struct {
	A uint8
	G gInner
}

type gMark struct {
	Mark bool
	N    *uint8
}

func innerFields() []Field {
	return []Field{
		Bind(U8(1, "b"), func(r *gInner) uint8 { return r.B }, func(r *gInner, v uint8) { r.B = v }),
		Flags(2, Bind(U8(2, "c"), func(r *gInner) *uint8 { return r.C }, func(r *gInner, v *uint8) { r.C = v })),
	}
}

// nested-group "flags inside an anchored group" in the typed form: the group is a *gInner.
func typedGroupScheme(t testing.TB) *Scheme {
	return mustScheme(t, 1,
		Bind(U8(0, "a"), func(r *gOuter) uint8 { return r.A }, func(r *gOuter, v uint8) { r.A = v }),
		Bind(Group(1, "g", innerFields()...), func(r *gOuter) *gInner { return r.G }, func(r *gOuter, v *gInner) { r.G = v }),
	)
}

// The same group under flags: nil is no value, the bit is clear.
func typedFlagsGroupScheme(t testing.TB) *Scheme {
	return mustScheme(t, 1,
		Bind(U8(0, "a"), func(r *gOuter) uint8 { return r.A }, func(r *gOuter, v uint8) { r.A = v }),
		Flags(1, Bind(Group(1, "g", innerFields()...), func(r *gOuter) *gInner { return r.G }, func(r *gOuter, v *gInner) { r.G = v })),
	)
}

func u8p(v uint8) *uint8 { return &v }

// AC-4 typed: the bytes of the map rows, from structs; Unpack gives the struct back.
func TestAC4AnchoredGroupTypedRows(t *testing.T) {
	cases := []struct {
		name   string
		scheme func(t testing.TB) *Scheme
		row    *gOuter
		wire   string
	}{
		{"flags inside an anchored group", typedGroupScheme, &gOuter{A: 1, G: &gInner{B: 2, C: u8p(3)}}, "0101020103"},
		{"flags member nil", typedGroupScheme, &gOuter{A: 1, G: &gInner{B: 2}}, "01010200"},
		{"group under flags, given", typedFlagsGroupScheme, &gOuter{A: 1, G: &gInner{B: 2, C: u8p(3)}}, "010101020103"},
		{"group under flags, nil", typedFlagsGroupScheme, &gOuter{A: 1}, "010100"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Arrange
			s := c.scheme(t)

			// Act
			wire := mustPack(t, s, c.row)
			back, err := Unpack(mustHex(t, c.wire), s)

			// Assert
			if wire != c.wire {
				t.Fatalf("pack %s, want %s", wire, c.wire)
			}
			if err != nil || !reflect.DeepEqual(back, c.row) {
				t.Fatalf("unpack %+v err %v", back, err)
			}
			if mapWire := mustPack(t, s, mustUnpackMap(t, s, c.wire)); mapWire != c.wire {
				t.Fatalf("map form packs %s", mapWire)
			}
		})
	}
}

func TestAC4TypedGroupNilOutsideFlagsIsMissing(t *testing.T) {
	// Act
	raw, err := Pack(typedGroupScheme(t), &gOuter{A: 1})

	// Assert
	e := asError(t, err, PackRefused)
	if raw != nil || e.Field != 1 || e.Name != "b" {
		t.Fatalf("raw %x err %v", raw, e)
	}
}

func TestAC4TypedGroupByValueIsAlwaysGiven(t *testing.T) {
	// Arrange
	s := mustScheme(t, 1,
		Bind(U8(0, "a"), func(r *gByValue) uint8 { return r.A }, func(r *gByValue, v uint8) { r.A = v }),
		Flags(1, Bind(Group(1, "g", innerFields()...), func(r *gByValue) gInner { return r.G }, func(r *gByValue, v gInner) { r.G = v })),
	)
	row := &gByValue{A: 1, G: gInner{B: 2}}

	// Act
	wire := mustPack(t, s, row)
	back, err := Unpack(mustHex(t, wire), s)

	// Assert
	if wire != "0101010200" || err != nil || !reflect.DeepEqual(back, row) {
		t.Fatalf("wire %s back %+v err %v", wire, back, err)
	}
}

func TestAC4TypedEmptyGroupIsABool(t *testing.T) {
	// Arrange
	m := FlagByte("m")
	s := mustScheme(t, 1, m,
		m.Bit(Bind(Group(0, "mark"), func(r *gMark) bool { return r.Mark }, func(r *gMark, v bool) { r.Mark = v })),
		m.Bit(Bind(U8(0, "n"), func(r *gMark) *uint8 { return r.N }, func(r *gMark, v *uint8) { r.N = v })))

	for _, row := range []*gMark{{Mark: true, N: u8p(3)}, {}} {
		// Act
		wire := mustPack(t, s, row)
		back, err := Unpack(mustHex(t, wire), s)

		// Assert
		if err != nil || !reflect.DeepEqual(back, row) {
			t.Fatalf("%s: back %+v err %v", wire, back, err)
		}
	}
}

// The typed form of the README late-when row.
type lateRow struct {
	Mode uint8
	G    *lateInner
}

type lateInner struct {
	D    uint8
	A, B *uint8
}

func TestAC2ReadmeLateWhenInAGroupTyped(t *testing.T) {
	// Arrange
	fb := FlagByte("fb")
	s := mustScheme(t, 1, fb,
		Bind(U8(0, "mode"), func(r *lateRow) uint8 { return r.Mode }, func(r *lateRow, v uint8) { r.Mode = v }),
		fb.Bit(Bind(Group(1, "g",
			Bind(U8(1, "d"), func(r *lateInner) uint8 { return r.D }, func(r *lateInner, v uint8) { r.D = v }),
			When(2, Eq(0, 1), Bind(U8(2, "a"), func(r *lateInner) *uint8 { return r.A }, func(r *lateInner, v *uint8) { r.A = v })),
			When(3, Eq(0, 2), Bind(U8(3, "b"), func(r *lateInner) *uint8 { return r.B }, func(r *lateInner, v *uint8) { r.B = v })),
		), func(r *lateRow) *lateInner { return r.G }, func(r *lateRow, v *lateInner) { r.G = v })))
	row := &lateRow{Mode: 1, G: &lateInner{D: 5, A: u8p(9)}}

	// Act
	wire := mustPack(t, s, row)
	back, err := Unpack(mustHex(t, wire), s)

	// Assert
	if wire != "0101010509" || err != nil || !reflect.DeepEqual(back, row) {
		t.Fatalf("wire %s back %+v err %v", wire, back, err)
	}
}

type otherInner struct{ B uint8 }

func TestTypedGroupBindingRefusals(t *testing.T) {
	bindB := func() Field {
		return Bind(U8(1, "b"), func(r *gInner) uint8 { return r.B }, func(r *gInner, v uint8) { r.B = v })
	}
	bindA := Bind(U8(0, "a"), func(r *gOuter) uint8 { return r.A }, func(r *gOuter, v uint8) { r.A = v })
	getG, setG := func(r *gOuter) *gInner { return r.G }, func(r *gOuter, v *gInner) { r.G = v }
	checkRefused(t, []refusedCase{
		{"group bound to an integer", build(bindA, Bind(Group(1, "g", bindB()), func(r *gOuter) uint8 { return 0 },
			func(*gOuter, uint8) {})), 1, "a uint8 member cannot hold group g; bind a struct or a pointer to a struct"},
		{"empty group bound to a struct", build(Flags(0, Bind(Group(0, "mark"), getG, setG))), 0,
			"a *packbin.gInner member cannot hold every empty group value"},
		{"group bound, member not", build(bindA, Bind(Group(1, "g", U8(1, "b")), getG, setG)), 1,
			"not bound to row type packbin.gInner (the row of group g); bind every value field of a scheme, or none"},
		{"member bound, group not", build(U8(0, "a"), Group(1, "g", bindB())), 1,
			"bound to row type packbin.gInner, but its group g is not bound"},
		{"member bound to another row type", build(bindA, Bind(Group(1, "g",
			Bind(U8(1, "b"), func(r *otherInner) uint8 { return r.B }, func(r *otherInner, v uint8) { r.B = v })), getG, setG)), 1,
			"bound to row type packbin.otherInner, but its group g is bound to packbin.gInner"},
		{"group bound to the outer row type", build(bindA, Group(1, "g", bindB())), 1,
			"not bound to row type packbin.gOuter; bind every value field of a scheme, or none"},
	})
}

// Two when branches declare one name with different kinds: Unpack fills only the member of the
// branch that was read, and never panics on the other.
type branchRow struct {
	K  uint8
	X8 *uint8
	XB []byte
}

func TestTypedWhenBranchesOfDifferentKindsFillOnlyTheRead(t *testing.T) {
	// Arrange
	s := mustScheme(t, 1,
		Bind(U8(0, "k"), func(r *branchRow) uint8 { return r.K }, func(r *branchRow, v uint8) { r.K = v }),
		When(1, Eq(0, 0), Bind(U8(1, "x"), func(r *branchRow) *uint8 { return r.X8 }, func(r *branchRow, v *uint8) { r.X8 = v })),
		When(2, Eq(0, 1), Bind(Bytes(2, "x", 2), func(r *branchRow) []byte { return r.XB }, func(r *branchRow, v []byte) { r.XB = v })),
	)

	// Act
	bytesBranch, err1 := Unpack(mustHex(t, "0101aabb"), s)
	u8Branch, err2 := Unpack(mustHex(t, "010007"), s)

	// Assert
	if err1 != nil || !reflect.DeepEqual(bytesBranch, &branchRow{K: 1, XB: []byte{0xaa, 0xbb}}) {
		t.Fatalf("bytes branch %+v err %v", bytesBranch, err1)
	}
	if err2 != nil || !reflect.DeepEqual(u8Branch, &branchRow{K: 0, X8: u8p(7)}) {
		t.Fatalf("u8 branch %+v err %v", u8Branch, err2)
	}
}
