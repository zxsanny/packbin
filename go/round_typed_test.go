package packbin

import (
	"reflect"
	"testing"
)

type point struct{ Lat, Lon int32 }

type route struct {
	N      uint8
	Points []point
	Tail   uint8
}

func routeScheme(t testing.TB) *Scheme {
	return mustScheme(t, 1,
		Bind(U8(0, "n"), func(r *route) uint8 { return r.N }, func(r *route, v uint8) { r.N = v }),
		Bind(Times(1, 0,
			Bind(I32(1, "lat"), func(p *point) int32 { return p.Lat }, func(p *point, v int32) { p.Lat = v }),
			Bind(I32(2, "lon"), func(p *point) int32 { return p.Lon }, func(p *point, v int32) { p.Lon = v })),
			func(r *route) []point { return r.Points }, func(r *route, v []point) { r.Points = v }),
		Bind(U8(3, "tail"), func(r *route) uint8 { return r.Tail }, func(r *route, v uint8) { r.Tail = v }),
	)
}

type mark struct{ V uint8 }

type sample struct {
	K    uint8
	On   *bool
	N    *uint8
	Mark *mark
	P, Q uint8
}

type samples struct{ Rounds []*sample }

// repeat { u8 k; flags { bool on; u8 n; group mark { u8 v } }; u2 { p; q } }
func samplesScheme(t testing.TB) *Scheme {
	return mustScheme(t, 1, Bind(Repeat(0,
		Bind(U8(0, "k"), func(s *sample) uint8 { return s.K }, func(s *sample, v uint8) { s.K = v }),
		Flags(1,
			Bind(Bool(1, "on"), func(s *sample) *bool { return s.On }, func(s *sample, v *bool) { s.On = v }),
			Bind(U8(2, "n"), func(s *sample) *uint8 { return s.N }, func(s *sample, v *uint8) { s.N = v }),
			Bind(Group(3, "mark", Bind(U8(3, "v"), func(m *mark) uint8 { return m.V }, func(m *mark, v uint8) { m.V = v })),
				func(s *sample) *mark { return s.Mark }, func(s *sample, v *mark) { s.Mark = v })),
		U2(Bind(Slot(4, "p"), func(s *sample) uint8 { return s.P }, func(s *sample, v uint8) { s.P = v }),
			Bind(Slot(5, "q"), func(s *sample) uint8 { return s.Q }, func(s *sample, v uint8) { s.Q = v }))),
		func(r *samples) []*sample { return r.Rounds }, func(r *samples, v []*sample) { r.Rounds = v }))
}

// AC-2, S8: a typed times binds a slice of a struct, one element a round; the README route packs to
// the README hex, unpacks to the same struct, and the map form gives the same bytes.
func TestAC2TypedTimesRoute(t *testing.T) {
	// Arrange
	s := routeScheme(t)
	row := &route{N: 2, Points: []point{{10, 20}, {30, 40}}, Tail: 7}
	const want = "01020a000000140000001e0000002800000007"

	// Act
	wire := mustPack(t, s, row)
	back, err := Unpack(mustHex(t, want), s)
	asMap := mustPack(t, s, gm("n", 2, "lat", []any{10, 30}, "lon", []any{20, 40}, "tail", 7))

	// Assert
	if wire != want || asMap != want || err != nil || !reflect.DeepEqual(back, row) {
		t.Fatalf("wire %s map %s back %+v %v", wire, asMap, back, err)
	}
}

// AC-2, S8: a typed repeat of pointers with optional members, a group and u2 slots per round packs the
// bytes of the same map row; a nil element is a round with no value; unpack gives one element a round.
func TestAC2TypedRepeatMatchesTheMapForm(t *testing.T) {
	// Arrange
	s := samplesScheme(t)
	on, n := true, uint8(9)
	row := &samples{Rounds: []*sample{{K: 1, On: &on, N: &n, P: 1, Q: 2}, {K: 2, Mark: &mark{V: 7}, P: 3}}}
	asMap := gm("k", []any{1, 2}, "on", []any{true, nil}, "n", []any{9, nil}, "mark", []any{nil, gm("v", 7)},
		"p", []any{1, 3}, "q", []any{2, 0})

	// Act
	wire := mustPack(t, s, row)
	mapWire := mustPack(t, s, asMap)
	back, err := Unpack(mustHex(t, wire), s)

	// Assert
	if wire != "010103090902040703" {
		t.Fatalf("wire %s", wire)
	}
	if mapWire != wire || err != nil || !reflect.DeepEqual(back, row) {
		t.Fatalf("map %s back %+v %v", mapWire, back.(*samples).Rounds, err)
	}
}

// G-5: a nil slice is no value and an empty slice 0 rounds; both write no round. Unpack gives an empty
// slice for a round read with 0 rounds, and nil for a round that was not read (a clear bit).
func TestAC3TypedRoundsNilAndEmpty(t *testing.T) {
	type opt struct {
		Mode   uint8
		Points []point
	}
	s := mustScheme(t, 1,
		Bind(U8(0, "mode"), func(r *opt) uint8 { return r.Mode }, func(r *opt, v uint8) { r.Mode = v }),
		Flags(1, Bind(Repeat(1,
			Bind(I32(1, "lat"), func(p *point) int32 { return p.Lat }, func(p *point, v int32) { p.Lat = v }),
			Bind(I32(2, "lon"), func(p *point) int32 { return p.Lon }, func(p *point, v int32) { p.Lon = v })),
			func(r *opt) []point { return r.Points }, func(r *opt, v []point) { r.Points = v })))
	top := routeScheme(t)

	// Act
	nilWire := mustPack(t, s, &opt{Mode: 1})
	emptyWire := mustPack(t, s, &opt{Mode: 1, Points: []point{}})
	clear, _ := Unpack(mustHex(t, "010100"), s)
	zero, _ := Unpack(mustHex(t, "010007"), top)

	// Assert
	if nilWire != "010100" || emptyWire != "010100" {
		t.Fatalf("nil %s empty %s", nilWire, emptyWire)
	}
	if clear.(*opt).Points != nil {
		t.Fatalf("a round not read: %#v", clear.(*opt).Points)
	}
	if p := zero.(*route).Points; p == nil || len(p) != 0 {
		t.Fatalf("0 rounds read: %#v", p)
	}
}

// A typed times holds one element a round, so a count other than the elements is refused naming the
// member (as C#); count 0 with a nil slice packs.
func TestTypedTimesCountMustMatchTheRows(t *testing.T) {
	// Arrange
	s := routeScheme(t)

	// Act
	_, short := Pack(s, &route{N: 3, Points: []point{{1, 2}, {3, 4}}})
	_, none := Pack(s, &route{N: 2})
	_, long := Pack(s, &route{N: 1, Points: []point{{1, 2}, {3, 4}}})
	zero := mustPack(t, s, &route{N: 0, Tail: 5})

	// Assert
	for _, err := range []error{short, none, long} {
		if e := asError(t, err, PackRefused); e.Field != 1 || e.Name != "lat" {
			t.Fatalf("%v", e)
		}
	}
	if zero != "010005" {
		t.Fatalf("zero %s", zero)
	}
}

// Counted kinds in a typed row: sized, bits and packed bind a []byte, a slot any integer type.
func TestTypedCountedKinds(t *testing.T) {
	type row struct {
		N    uint8
		Data []byte
		Segs []byte
		Legs []byte
		A    int
		B    uint8
	}
	s := mustScheme(t, 1,
		Bind(U8(0, "n"), func(r *row) uint8 { return r.N }, func(r *row, v uint8) { r.N = v }),
		Bind(Sized(1, "data", 0), func(r *row) []byte { return r.Data }, func(r *row, v []byte) { r.Data = v }),
		Bind(Bits(2, "segs", 0), func(r *row) []byte { return r.Segs }, func(r *row, v []byte) { r.Segs = v }),
		Bind(Packed(2, 3, "legs", 0, -1), func(r *row) []byte { return r.Legs }, func(r *row, v []byte) { r.Legs = v }),
		U2(Bind(Slot(4, "a"), func(r *row) int { return r.A }, func(r *row, v int) { r.A = v }),
			Bind(Slot(5, "b"), func(r *row) uint8 { return r.B }, func(r *row, v uint8) { r.B = v })))
	in := &row{N: 3, Data: []byte("uav"), Segs: []byte{1, 0, 1}, Legs: []byte{3, 2}, A: 2, B: 3}

	// Act
	wire := mustPack(t, s, in)
	asMap := mustPack(t, s, gm("n", 3, "data", []byte("uav"), "segs", []int{1, 0, 1}, "legs", []any{3, 2}, "a", 2, "b", 3))
	back, err := Unpack(mustHex(t, wire), s)

	// Assert
	if wire != "0103756176050b0e" || asMap != wire || err != nil || !reflect.DeepEqual(back, in) {
		t.Fatalf("wire %s map %s back %+v %v", wire, asMap, back, err)
	}
}

// A round is bound to a slice of a struct, and its members to that struct.
func TestTypedRoundBindingRefusals(t *testing.T) {
	type other struct{ X uint8 }
	lat := Bind(I32(1, "lat"), func(p *point) int32 { return p.Lat }, func(p *point, v int32) { p.Lat = v })
	n := Bind(U8(0, "n"), func(r *route) uint8 { return r.N }, func(r *route, v uint8) { r.N = v })
	runBuildRefusals(t, []buildCase{
		{"not a slice", func() []Field {
			return []Field{n, Bind(Times(1, 0, lat), func(r *route) point { return point{} }, func(*route, point) {})}
		}, 1, "cannot hold the rounds of times 1"},
		{"a slice of numbers", func() []Field {
			return []Field{n, Bind(Times(1, 0, lat), func(r *route) []int { return nil }, func(*route, []int) {})}
		}, 1, "bind a slice of a struct"},
		{"members unbound", func() []Field {
			return []Field{n, Bind(Times(1, 0, I32(1, "lat")), func(r *route) []point { return r.Points }, func(*route, []point) {})}
		}, 1, "the row of times 1"},
		{"members bound to another struct", func() []Field {
			return []Field{n, Bind(Times(1, 0, Bind(U8(1, "x"), func(o *other) uint8 { return o.X }, func(*other, uint8) {})),
				func(r *route) []point { return r.Points }, func(*route, []point) {})}
		}, 1, "but its times 1 is bound to packbin.point"},
		{"round unbound in a typed scheme", func() []Field { return []Field{n, Times(1, 0, lat)} }, 1, "not bound to row type packbin.route"},
		{"a u2 is not bound itself", func() []Field {
			return []Field{Bind(U2(Slot(0, "a")), func(r *route) uint8 { return 0 }, func(*route, uint8) {})}
		}, 0, "not u2"},
	})
}
