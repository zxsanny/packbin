package packbin

import (
	"strings"
	"testing"
)

// AC-1: the rows of bool-flag, fields and packbin that no earlier Go test pinned.

// bool-flag "bool outside flags is a scheme error", the round, list and dict spellings: a bool is
// allowed only directly inside flags or a flag bit; the refusal names the member.
func TestAC1BoolOutsideFlagsInRoundsListsAndDicts(t *testing.T) {
	cases := []struct {
		name   string
		member string
		fields []Field
	}{
		{"in a repeat", "inRepeat", []Field{Repeat(0, Bool(0, "inRepeat"))}},
		{"in a times", "inTimes", []Field{U8(0, "n"), Times(1, 0, U8(1, "v"), Bool(2, "inTimes"))}},
		{"in a list", "inList", []Field{List("xs", Bool(0, "inList"))}},
		{"in a dict", "inDict", []Field{Dict("d", Bool(0, "inDict"))}},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Act
			s, err := NewScheme(1, c.fields...)

			// Assert
			e := asError(t, err, InvalidScheme)
			if s != nil || !strings.Contains(e.Error(), c.member) || !strings.Contains(e.Error(), "flags") {
				t.Fatalf("scheme %v err %v", s, e)
			}
		})
	}
}

// fields.test.ts: a short buffer names the field with the bytes it needs and the bytes left; no row.
func TestAC1FieldsShortBuffersNameTheMember(t *testing.T) {
	sized := mustScheme(t, 1, U16(0, "n"), Sized(1, "payload", 0))
	bits := mustScheme(t, 1, U8(0, "n"), Bits(1, "segs", 0))
	cases := []struct {
		name         string
		scheme       *Scheme
		wire         string
		member       string
		needed, left int
	}{
		{"sized payload cut short", sized, "01030075", "payload", 3, 1},
		{"bits cut short", bits, "010901", "segs", 2, 1},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Act
			row, err := UnpackMap(mustHex(t, c.wire), c.scheme)

			// Assert
			e := asError(t, err, ShortPacket)
			if row != nil || e.Name != c.member || e.Needed != c.needed || e.Left != c.left {
				t.Fatalf("row %v err %+v", row, e)
			}
		})
	}
	empty := mustUnpackMap(t, sized, "010000")
	if p, ok := empty["payload"].([]byte); !ok || len(p) != 0 {
		t.Fatalf("empty payload: %#v", empty["payload"])
	}
}

// packbin.test.ts AC-5: a short buffer for a flags member names it, then the position pack still matches.
func TestAC1PackbinShortFlagsBufferThenPositionStillMatches(t *testing.T) {
	s := mustScheme(t, 1, Flags(0, U8(0, "b0"), U8(1, "b1"), U8(2, "b2"), U8(3, "b3"), U8(4, "b4"), U16(5, "extra")))

	// Act
	row, err := UnpackMap(mustHex(t, "012034"), s)

	// Assert
	e := asError(t, err, ShortPacket)
	if row != nil || e.Name != "extra" || e.Needed != 2 || e.Left != 1 {
		t.Fatalf("row %v err %+v", row, e)
	}
	if got := mustPack(t, positionMapScheme(t), goldenMap()); got != expectedHex {
		t.Fatalf("position packs %s", got)
	}
}

// packbin.test.ts IT-06 and IT-07.
func TestAC1PackbinWhenGroupWidthAndRepeatOnGroupBoundary(t *testing.T) {
	when := mustScheme(t, 1, U8(0, "profile"), When(1, Eq(0, 0), U8(1, "shape")))
	if miss, hit := mustPack(t, when, gm("profile", 1)), mustPack(t, when, gm("profile", 0, "shape", 9)); len(miss) != 4 || len(hit) != 6 {
		t.Fatalf("IT-06 miss %s hit %s", miss, hit)
	}
	repeat := mustScheme(t, 1, U8(0, "type"), Repeat(1, U8(1, "a"), U8(2, "b")))
	complete := mustUnpackMap(t, repeat, "01010203")
	if a, ok := complete["a"].([]any); !ok || len(a) != 1 {
		t.Fatalf("IT-07 a: %#v", complete["a"])
	}
	_, err := UnpackMap(mustHex(t, "0101020304"), repeat)
	if e := asError(t, err, ShortPacket); e.Name != "b" {
		t.Fatalf("IT-07 leftover byte: %+v", e)
	}
}

// packbin.test.ts: the session group (login, ts) under flags, in the nested map form (Go-4), and
// the same group bound to a struct; a group of u8 0 packs; a short read names the member.
type pSession struct {
	Login uint16
	Ts    uint32
}

type pHolder struct{ Session *pSession }

func TestAC1PackbinFlagSessionGroup(t *testing.T) {
	m := mustScheme(t, 1, Flags(0, Group(0, "session", U16(0, "login"), U32(1, "ts"))))
	typed := mustScheme(t, 1, Flags(0, Bind(Group(0, "session",
		Bind(U16(0, "login"), func(r *pSession) uint16 { return r.Login }, func(r *pSession, v uint16) { r.Login = v }),
		Bind(U32(1, "ts"), func(r *pSession) uint32 { return r.Ts }, func(r *pSession, v uint32) { r.Ts = v })),
		func(r *pHolder) *pSession { return r.Session }, func(r *pHolder, v *pSession) { r.Session = v })))

	// Act
	raw := mustPack(t, m, gm("session", gm("login", 7, "ts", 1000)))
	typedRaw := mustPack(t, typed, &pHolder{Session: &pSession{Login: 7, Ts: 1000}})
	absent := mustPack(t, m, gm())
	typedAbsent := mustPack(t, typed, &pHolder{})
	back, err := Unpack(mustHex(t, raw), typed)

	// Assert
	if raw != "01010700e8030000" || typedRaw != raw || absent != "0100" || typedAbsent != "0100" {
		t.Fatalf("raw %s typed %s absent %s typed absent %s", raw, typedRaw, absent, typedAbsent)
	}
	if got := back.(*pHolder); err != nil || got.Session == nil || got.Session.Login != 7 || got.Session.Ts != 1000 {
		t.Fatalf("typed back %+v err %v", back, err)
	}
	if clear := mustUnpackMap(t, m, "0100"); len(clear) != 0 {
		t.Fatalf("clear bit gave %v", clear)
	}
	if clear, err := Unpack(mustHex(t, "0100"), typed); err != nil || clear.(*pHolder).Session != nil {
		t.Fatalf("typed clear %+v err %v", clear, err)
	}
	_, shortErr := UnpackMap(mustHex(t, "010107"), m)
	if e := asError(t, shortErr, ShortPacket); e.Name != "login" || e.Needed != 2 || e.Left != 1 {
		t.Fatalf("short read: %+v", e)
	}
	zero := mustScheme(t, 1, Flags(0, Group(0, "g", U8(0, "b"))))
	if got := mustPack(t, zero, gm("g", gm("b", 0))); got != "010100" {
		t.Fatalf("group u8 zero packs %s", got)
	}
}
