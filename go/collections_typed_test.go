package packbin

import (
	"reflect"
	"strings"
	"testing"
)

type pt struct{ A, B uint8 }

type account struct {
	Name   string
	Roles  []string
	Access map[string][]string
}

type track struct {
	Pts  []pt
	Ptrs []*pt
	By   map[string]pt
	Opt  []uint16
}

func ptFields() []Field {
	return []Field{
		Bind(U8(0, "a"), func(r *pt) uint8 { return r.A }, func(r *pt, v uint8) { r.A = v }),
		Bind(U8(1, "b"), func(r *pt) uint8 { return r.B }, func(r *pt, v uint8) { r.B = v }),
	}
}

func accountScheme(t testing.TB) *Scheme {
	return mustScheme(t, 1,
		Bind(Utf8(0, "username"), func(r *account) string { return r.Name }, func(r *account, v string) { r.Name = v }),
		Bind(List("roles", Utf8(0, "role")), func(r *account) []string { return r.Roles }, func(r *account, v []string) { r.Roles = v }),
		Bind(Dict("access", List("actions", Utf8(0, "action"))),
			func(r *account) map[string][]string { return r.Access }, func(r *account, v map[string][]string) { r.Access = v }),
	)
}

func trackScheme(t testing.TB) *Scheme {
	return mustScheme(t, 1,
		Bind(List("pts", Nested("p", ptFields()...)), func(r *track) []pt { return r.Pts }, func(r *track, v []pt) { r.Pts = v }),
		Bind(List("ptrs", Nested("p", ptFields()...)), func(r *track) []*pt { return r.Ptrs }, func(r *track, v []*pt) { r.Ptrs = v }),
		Bind(Dict("by", Nested("p", ptFields()...)), func(r *track) map[string]pt { return r.By }, func(r *track, v map[string]pt) { r.By = v }),
		Flags(0, Bind(List("opt", U16(0, "o")), func(r *track) []uint16 { return r.Opt }, func(r *track, v []uint16) { r.Opt = v })),
	)
}

// AC-2 (binding, value-fidelity): a typed row packs to the ring bytes and unpacks to the same struct.
func TestTypedUserRowRoundTrips(t *testing.T) {
	// Arrange
	s := accountScheme(t)
	row := &account{Name: "zxsanny", Roles: []string{"user", "dispatcher"}, Access: map[string][]string{
		"channel": {"read"}, "map": {"read", "gps_fix", "set", "edit"}, "store": {"read", "write"},
	}}

	// Act
	packed := mustPack(t, s, row)
	back, err := Unpack(mustHex(t, userHex), s)

	// Assert
	if packed != userHex {
		t.Fatalf("packed %s", packed)
	}
	if err != nil || !reflect.DeepEqual(back, row) {
		t.Fatalf("back %#v %v", back, err)
	}
	if mapPacked := mustPack(t, s, gm("username", "zxsanny", "roles", []string{"user", "dispatcher"},
		"access", map[string][]string{"channel": {"read"}, "map": {"read", "gps_fix", "set", "edit"}, "store": {"read", "write"}})); mapPacked != userHex {
		t.Fatalf("map row packed %s", mapPacked)
	}
}

func TestTypedNestedElementsPackLikeMaps(t *testing.T) {
	// Arrange
	s := trackScheme(t)
	row := &track{
		Pts:  []pt{{1, 2}, {3, 4}},
		Ptrs: []*pt{{5, 6}},
		By:   map[string]pt{"y": {3, 4}, "x": {1, 2}},
		Opt:  []uint16{9},
	}
	asMap := gm("pts", []any{gm("a", 1, "b", 2), gm("a", 3, "b", 4)}, "ptrs", []any{gm("a", 5, "b", 6)},
		"by", map[string]any{"y": gm("a", 3, "b", 4), "x": gm("a", 1, "b", 2)}, "opt", []any{9})

	// Act
	typed := mustPack(t, s, row)
	viaMap := mustPack(t, s, asMap)
	back, err := Unpack(mustHex(t, typed), s)

	// Assert
	want := "01" + "0200" + "0102" + "0304" + "0100" + "0506" + "0200" + "021078" + "0102" + "021079" + "0304" + "01" + "0100" + "0900"
	if typed != want || viaMap != want {
		t.Fatalf("typed %s map %s want %s", typed, viaMap, want)
	}
	if err != nil || !reflect.DeepEqual(back, row) {
		t.Fatalf("back %#v %v", back, err)
	}
}

// Go-5: a nil slice or map is no value (a clear bit), an empty one a value with 0 items.
func TestTypedNilAndEmptyCollections(t *testing.T) {
	s := trackScheme(t)
	empty := &track{Pts: []pt{}, Ptrs: []*pt{}, By: map[string]pt{}, Opt: []uint16{}}

	runRefusals(t, []refusalCase{{"a nil list of a required member", func(testing.TB) *Scheme { return s },
		gm("pts", []any(nil)), -1, "pts", "expected a list"}})
	if _, err := Pack(s, &track{}); err == nil || !strings.Contains(err.Error(), "pts") {
		t.Fatalf("a nil required slice packed: %v", err)
	}
	wire := mustPack(t, s, empty)
	back, err := Unpack(mustHex(t, wire), s)
	if wire != "01"+"0000"+"0000"+"0000"+"01"+"0000" || err != nil || !reflect.DeepEqual(back, empty) {
		t.Fatalf("wire %s back %#v %v", wire, back, err)
	}
	opt := &track{Pts: []pt{}, Ptrs: []*pt{}, By: map[string]pt{}}
	wire = mustPack(t, s, opt)
	back, err = Unpack(mustHex(t, wire), s)
	if wire != "01"+"0000"+"0000"+"0000"+"00" || err != nil || !reflect.DeepEqual(back, opt) {
		t.Fatalf("wire %s back %#v %v", wire, back, err)
	}
}

type vrow struct{ V uint8 }

type itemRow struct {
	N    uint8
	Rows []vrow
}

type itemsRow struct{ Items []itemRow }

// A round in an item is told apart from the round of another item: an item with 0 rounds read gets an
// empty slice, whatever the other items hold (AZ-2442 handoff).
func TestTypedRoundsAreReachedPerItem(t *testing.T) {
	// Arrange
	s := mustScheme(t, 1, Bind(List("items", Nested("it",
		Bind(U8(0, "n"), func(r *itemRow) uint8 { return r.N }, func(r *itemRow, v uint8) { r.N = v }),
		Bind(Times(1, 0, Bind(U8(1, "v"), func(r *vrow) uint8 { return r.V }, func(r *vrow, v uint8) { r.V = v })),
			func(r *itemRow) []vrow { return r.Rows }, func(r *itemRow, v []vrow) { r.Rows = v }),
	)), func(r *itemsRow) []itemRow { return r.Items }, func(r *itemsRow, v []itemRow) { r.Items = v }))
	row := &itemsRow{Items: []itemRow{{N: 0, Rows: []vrow{}}, {N: 2, Rows: []vrow{{7}, {8}}}, {N: 0, Rows: []vrow{}}}}
	wire := "01" + "0300" + "00" + "02" + "0708" + "00"

	// Act
	packed := mustPack(t, s, row)
	back, err := Unpack(mustHex(t, wire), s)

	// Assert
	if packed != wire || err != nil || !reflect.DeepEqual(back, row) {
		t.Fatalf("packed %s back %#v %v", packed, back, err)
	}
}

type tagged struct {
	K    uint8
	Tags []uint8
}

type taggedRounds struct{ Rows []tagged }

func TestTypedListInARound(t *testing.T) {
	// Arrange
	s := mustScheme(t, 1, Bind(Repeat(0,
		Bind(U8(0, "k"), func(r *tagged) uint8 { return r.K }, func(r *tagged, v uint8) { r.K = v }),
		Bind(List("tags", U8(0, "t")), func(r *tagged) []uint8 { return r.Tags }, func(r *tagged, v []uint8) { r.Tags = v }),
	), func(r *taggedRounds) []tagged { return r.Rows }, func(r *taggedRounds, v []tagged) { r.Rows = v }))
	row := &taggedRounds{Rows: []tagged{{1, []uint8{7, 8}}, {2, []uint8{}}}}
	wire := "01" + "01" + "0200" + "0708" + "02" + "0000"

	// Act
	packed := mustPack(t, s, row)
	back, err := Unpack(mustHex(t, wire), s)

	// Assert
	if packed != wire || err != nil || !reflect.DeepEqual(back, row) {
		t.Fatalf("packed %s back %#v %v", packed, back, err)
	}
}

// Bind refuses a member that cannot hold what the list, dict or element holds.
func TestBindRefusesACollectionMemberThatCannotHoldIt(t *testing.T) {
	getA := func(r *account) []int8 { return nil }
	setA := func(r *account, v []int8) {}
	cases := map[string]Field{
		"a slice of int8 for u8 items": Bind(List("roles", U8(0, "x")), getA, setA),
		"a string for a list":          Bind(List("roles", U8(0, "x")), func(r *account) string { return "" }, func(r *account, v string) {}),
		"a slice for a dict":           Bind(Dict("roles", U8(0, "x")), func(r *account) []uint8 { return nil }, func(r *account, v []uint8) {}),
		"a map with int keys":          Bind(Dict("roles", U8(0, "x")), func(r *account) map[int]uint8 { return nil }, func(r *account, v map[int]uint8) {}),
		"a slice of ints for a nested": Bind(List("roles", Nested("p", U8(0, "a"))), func(r *account) []int { return nil }, func(r *account, v []int) {}),
	}
	for name, f := range cases {
		t.Run(name, func(t *testing.T) {
			if e := buildRefusal(t, f); !strings.Contains(e.Reason, "cannot hold") {
				t.Fatalf("got %v", e)
			}
		})
	}
}

// Every member of a nested element is bound to the element's struct, or none is.
func TestBindRefusesAMixOfBoundAndUnboundElementMembers(t *testing.T) {
	list := func(r *track) []pt { return nil }
	set := func(r *track, v []pt) {}
	e := buildRefusal(t, Bind(List("pts", Nested("p", ptFields()[0], U8(1, "b"))), list, set))
	if !strings.Contains(e.Reason, "not bound") {
		t.Fatalf("got %v", e)
	}
	e = buildRefusal(t, Bind(List("pts", Nested("p", U8(0, "a"), U8(1, "b"))), list, set))
	if !strings.Contains(e.Reason, "not bound") {
		t.Fatalf("got %v", e)
	}
	other := Nested("p",
		Bind(U8(0, "a"), func(r *account) uint8 { return 0 }, func(r *account, v uint8) {}),
		Bind(U8(1, "b"), func(r *account) uint8 { return 0 }, func(r *account, v uint8) {}))
	e = buildRefusal(t, Bind(List("pts", other), list, set))
	if !strings.Contains(e.Reason, "bound to") {
		t.Fatalf("got %v", e)
	}
	e = buildRefusal(t, Bind(List("pts", Nested("p", ptFields()...)), list, set), U8(0, "loose"))
	if !strings.Contains(e.Reason, "not bound to row type") {
		t.Fatalf("got %v", e)
	}
}

type shapes struct {
	Grid  [][]uint16
	Ptrs  []*uint16
	Names map[string]*string
	Maps  []map[string]uint8
}

func shapesScheme(t testing.TB) *Scheme {
	return mustScheme(t, 1,
		Bind(List("grid", List("row", U16(0, "v"))), func(r *shapes) [][]uint16 { return r.Grid }, func(r *shapes, v [][]uint16) { r.Grid = v }),
		Bind(List("ptrs", U16(0, "v")), func(r *shapes) []*uint16 { return r.Ptrs }, func(r *shapes, v []*uint16) { r.Ptrs = v }),
		Bind(Dict("names", Utf8(0, "n")), func(r *shapes) map[string]*string { return r.Names }, func(r *shapes, v map[string]*string) { r.Names = v }),
		Bind(List("maps", Dict("m", U8(0, "v"))), func(r *shapes) []map[string]uint8 { return r.Maps }, func(r *shapes, v []map[string]uint8) { r.Maps = v }),
	)
}

func TestTypedNestedSlicesMapsAndPointers(t *testing.T) {
	// Arrange
	s := shapesScheme(t)
	one, name := uint16(7), "n"
	row := &shapes{Grid: [][]uint16{{1, 2}, {}}, Ptrs: []*uint16{&one}, Names: map[string]*string{"k": &name},
		Maps: []map[string]uint8{{"a": 1}, {}}}
	wire := "01" + "0200" + "0200" + "0100" + "0200" + "0000" + "0100" + "0700" + "0100" + "02106b" + "02106e" +
		"0200" + "0100" + "021061" + "01" + "0000"

	// Act
	packed := mustPack(t, s, row)
	back, err := Unpack(mustHex(t, wire), s)

	// Assert
	if packed != wire || err != nil || !reflect.DeepEqual(back, row) {
		t.Fatalf("packed %s\n want %s\n back %#v %v", packed, wire, back, err)
	}
}

func TestTypedNilItemsAreRefused(t *testing.T) {
	s := shapesScheme(t)
	rows := map[string]*shapes{
		"a nil item pointer":  {Grid: [][]uint16{}, Ptrs: []*uint16{nil}, Names: map[string]*string{}, Maps: []map[string]uint8{}},
		"a nil inner slice":   {Grid: [][]uint16{nil}, Ptrs: []*uint16{}, Names: map[string]*string{}, Maps: []map[string]uint8{}},
		"a nil inner map":     {Grid: [][]uint16{}, Ptrs: []*uint16{}, Names: map[string]*string{}, Maps: []map[string]uint8{nil}},
		"a nil value pointer": {Grid: [][]uint16{}, Ptrs: []*uint16{}, Names: map[string]*string{"k": nil}, Maps: []map[string]uint8{}},
	}
	for name, row := range rows {
		t.Run(name, func(t *testing.T) {
			raw, err := Pack(s, row)
			if e := asError(t, err, PackRefused); raw != nil || !strings.Contains(e.Reason, "no value") {
				t.Fatalf("raw %x err %v", raw, e)
			}
		})
	}
}

func TestSplitFlagByteHoldsAListAndAString(t *testing.T) {
	fb := FlagByte("m")
	s := func(testing.TB) *Scheme {
		return mustScheme(t, 1, fb, fb.Bit(List("xs", U8(0, "x"))), fb.Bit(Utf8(0, "s")), fb.Bit(Dict("d", U8(0, "v"))))
	}
	runPacks(t, []packCase{
		{"all three", s, gm("xs", []int{1}, "s", "a", "d", gm("k", 2)), "0107" + "0100" + "01" + "021061" + "0100" + "02106b" + "02"},
		{"only the string", s, gm("s", "a"), "0102021061"},
		{"an empty list and an empty dict", s, gm("xs", []int{}, "d", map[string]int{}), "0105" + "0000" + "0000"},
	})
}

type octets struct{ Data []byte }

// A typed list of u8 binds a []byte: the member type says it is a list, not a byte run.
func TestTypedListOfU8CanBeABytesMember(t *testing.T) {
	// Arrange
	s := mustScheme(t, 1, Bind(List("data", U8(0, "b")), func(r *octets) []byte { return r.Data }, func(r *octets, v []byte) { r.Data = v }))

	// Act
	packed := mustPack(t, s, &octets{Data: []byte{1, 2}})
	back, err := Unpack(mustHex(t, "0102000102"), s)

	// Assert
	if packed != "0102000102" || err != nil || !reflect.DeepEqual(back, &octets{Data: []byte{1, 2}}) {
		t.Fatalf("packed %s back %#v %v", packed, back, err)
	}
}
