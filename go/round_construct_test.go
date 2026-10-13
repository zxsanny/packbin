package packbin

import (
	"strings"
	"testing"
)

type buildCase struct {
	name   string
	fields func() []Field
	field  int
	reason string // a part of the reason
}

func runBuildRefusals(t *testing.T, cases []buildCase) {
	t.Helper()
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Act
			s, err := NewScheme(1, c.fields()...)

			// Assert
			e := asError(t, err, InvalidScheme)
			if s != nil || e.Field != c.field || !strings.Contains(e.Reason, c.reason) {
				t.Fatalf("got field %d reason %q", e.Field, e.Reason)
			}
		})
	}
}

const emptyBody = "the body holds no member; a round of it would charge no slot and write nothing"

// AC-2 (empty-round-body, AZ-2390): a repeat or times whose body holds no member is refused when the
// scheme is built, wherever it stands.
func TestAC2EmptyRoundBodyIsRefused(t *testing.T) {
	fb := FlagByte("m")
	runBuildRefusals(t, []buildCase{
		{"repeat with no member", func() []Field { return []Field{Repeat(0)} }, 0, "repeat 0: " + emptyBody},
		{"times with no member", func() []Field { return []Field{U8(0, "n"), Times(1, 0)} }, 1, "times 1: " + emptyBody},
		{"only an empty when", func() []Field { return []Field{Repeat(0, When(0, Eq(0, 1)))} }, 0, "repeat 0: " + emptyBody},
		{"an empty when in an empty when", func() []Field {
			return []Field{Repeat(0, When(0, Eq(0, 1), When(0, Eq(0, 2))))}
		}, 0, "repeat 0: " + emptyBody},
		{"only an empty group", func() []Field { return []Field{Repeat(0, Group(0, "g"))} }, 0,
			"empty group g: allowed only directly inside flags or a flag bit"},
		{"in flags", func() []Field { return []Field{Flags(0, Repeat(0))} }, 0, "repeat 0: " + emptyBody},
		{"in a flag bit", func() []Field { return []Field{fb, fb.Bit(Repeat(0))} }, 0, "repeat 0: " + emptyBody},
		{"in a when", func() []Field { return []Field{U8(0, "m"), When(1, Eq(0, 1), Repeat(1))} }, 1, "repeat 1: " + emptyBody},
		{"in a group", func() []Field { return []Field{Group(0, "g", Repeat(0))} }, 0, "repeat 0: " + emptyBody},
	})
}

// AC-2 (empty-round-body): a body whose members are all zero-width still builds.
func TestAC2ZeroWidthRoundBodyBuilds(t *testing.T) {
	fb := FlagByte("m")
	runPacks(t, []packCase{
		{"a flag byte alone", func(t testing.TB) *Scheme { return mustScheme(t, 1, Repeat(0, fb)) }, gm(), "01"},
		{"a flags with no member", func(t testing.TB) *Scheme { return mustScheme(t, 1, Repeat(0, Flags(0))) }, gm(), "01"},
		{"an empty group under flags", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, Repeat(0, Flags(0, Group(0, "g"))))
		}, gm("g", []any{true, nil}), "010100"},
		{"one u8", func(t testing.TB) *Scheme { return mustScheme(t, 1, Repeat(0, U8(0, "k"))) }, gm("k", []any{7, 8}), "010708"},
		{"one u8 counted", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, U8(0, "n"), Times(1, 0, U8(1, "k")))
		}, gm("n", 2, "k", []any{7, 8}), "01020708"},
	})
	// A zero-width bytes round that reads nothing ends the repeat; the byte left is trailing.
	s := mustScheme(t, 1, U8(0, "k"), Repeat(1, Bytes(1, "v", 0)))
	_, err := UnpackMap(mustHex(t, "01ff00"), s)
	if e := asError(t, err, TrailingBytes); e.Left != 1 {
		t.Fatalf("left %d", e.Left)
	}
}

const nestedRound = "is inside a repeat or times round; a round cannot hold another repeat or times"

// AC-2 (nested-round): a repeat or times inside a round is refused, wherever it sits in the round.
func TestAC2NestedRoundIsRefused(t *testing.T) {
	runBuildRefusals(t, []buildCase{
		{"repeat in repeat", func() []Field {
			return []Field{Repeat(0, U8(0, "m"), Repeat(1, U8(1, "v")))}
		}, 1, "repeat 1 " + nestedRound},
		{"times in repeat", func() []Field {
			return []Field{Repeat(0, U8(0, "c"), Times(1, 0, U8(1, "v")))}
		}, 1, "times 1 " + nestedRound},
		{"repeat in times", func() []Field {
			return []Field{U8(0, "n"), Times(1, 0, U8(1, "m"), Repeat(2, U8(2, "v")))}
		}, 2, "repeat 2 " + nestedRound},
		{"times in times", func() []Field {
			return []Field{U8(0, "n"), Times(1, 0, U8(1, "c"), Times(2, 1, U8(2, "v")))}
		}, 2, "times 2 " + nestedRound},
		{"repeat in a when in a repeat", func() []Field {
			return []Field{Repeat(0, U8(0, "k"), When(1, Eq(0, 1), Repeat(1, U8(1, "v"))))}
		}, 1, "repeat 1 " + nestedRound},
		{"repeat in flags in a repeat", func() []Field {
			return []Field{Repeat(0, Flags(0, Repeat(0, U8(0, "v"))))}
		}, 0, "repeat 0 " + nestedRound},
		{"repeat in flags in flags in a repeat", func() []Field {
			return []Field{Repeat(0, Flags(0, Flags(0, Repeat(0, U8(0, "v")))))}
		}, 0, "repeat 0 " + nestedRound},
		{"repeat in a split bit in a repeat", func() []Field {
			fb := FlagByte("m")
			return []Field{Repeat(0, fb, fb.Bit(Repeat(0, U8(0, "v"))), fb.Bit(Bool(1, "on")))}
		}, 0, "repeat 0 " + nestedRound},
		{"repeat in a group in a repeat", func() []Field {
			return []Field{Repeat(0, Group(0, "g", Repeat(0, U8(0, "v"))))}
		}, 0, "repeat 0 " + nestedRound},
		{"times in a group in a repeat", func() []Field {
			return []Field{Repeat(0, Group(0, "g", U8(0, "n"), Times(1, 0, U8(1, "v"))))}
		}, 1, "times 1 " + nestedRound},
		{"repeat in a group in a group in a times", func() []Field {
			return []Field{U8(0, "n"), Times(1, 0, Group(1, "a", Group(1, "b", Repeat(1, U8(1, "v")))))}
		}, 1, "repeat 1 " + nestedRound},
	})
}

// The counted kinds and slots are checked when the scheme is built: the count names an integer or a
// u2 slot declared earlier in the same scope; a slot stands only in U2; packed takes width 1 or 2
// and bias 0 or -1.
func TestRoundAndCountedConstructionRefusals(t *testing.T) {
	runBuildRefusals(t, []buildCase{
		{"count names a later field", func() []Field { return []Field{Sized(0, "p", 1), U8(1, "n")} }, 0,
			"sized 0: count names field id 1, which is not declared earlier in the same scope"},
		{"count names a float", func() []Field { return []Field{F32(0, "x"), Bits(1, "b", 0)} }, 1,
			"bits 1: count names field id 0 (x), which is not an integer"},
		{"count names a field outside the round", func() []Field {
			return []Field{U8(0, "n"), Repeat(1, Sized(1, "p", 0))}
		}, 1, "not declared earlier in the same scope"},
		{"times count names a field of the round", func() []Field {
			return []Field{U8(0, "n"), Repeat(1, U8(1, "c")), Times(2, 1, U8(2, "v"))}
		}, 2, "not declared earlier in the same scope"},
		{"a slot outside u2", func() []Field { return []Field{Slot(0, "a")} }, 0, "allowed only directly inside U2"},
		{"u2 with no slot", func() []Field { return []Field{U2()} }, NoField, "u2 needs at least one slot"},
		{"u2 with a u8", func() []Field { return []Field{U2(U8(0, "a"))} }, NoField, "u2 takes Slot fields, not u8"},
		{"u2 slot ids", func() []Field { return []Field{U2(Slot(0, "a"), Slot(2, "b"))} }, 2, "field id: expected 1, got 2"},
		{"packed width 3", func() []Field { return []Field{U8(0, "n"), Packed(3, 1, "p", 0, 0)} }, 1, "packed width must be 1 or 2"},
		{"packed bias 1", func() []Field { return []Field{U8(0, "n"), Packed(1, 1, "p", 0, 1)} }, 1, "packed bias must be 0 or -1"},
		{"repeat anchor", func() []Field { return []Field{U8(0, "n"), Repeat(2, U8(2, "v"))} }, 2, "repeat anchor: expected 1, got 2"},
		{"eq on a slot out of range", func() []Field {
			return []Field{U2(Slot(0, "a")), When(1, Eq(0, 4), U8(1, "v"))}
		}, 1, "the value must be a whole number from 0 to 3"},
		{"a slot named twice", func() []Field { return []Field{U8(0, "a"), U2(Slot(1, "a"))} }, 1, "declared twice"},
	})
	if _, err := NewScheme(1, U2(Slot(0, "a")), Bits(1, "b", 0), When(2, Eq(0, 3), U8(2, "v"))); err != nil {
		t.Fatalf("a slot as a count and an eq source: %v", err)
	}
}
