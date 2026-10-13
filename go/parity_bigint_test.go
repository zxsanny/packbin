package packbin

import (
	"fmt"
	"math"
	"strings"
	"testing"
)

// AC-1 and AC-2 (loop23-bigint-count, U23, AZ-2434): in the U11 shape (a bits, packed or sized member
// behind a split bit or a combined flags, its count in the row behind a clear when, no value) a count
// above 2^53 is a count above 0 and is refused with the U11 text, naming the member and the number.
// Go integers are exact, so a uint64 or int64 above 2^53 is a real count, as in Python.

const notWrittenTail = " in the row, but no field wrote it (the when that holds it is clear), so the member reads nothing; " +
	"give the count 0, leave it out, or make the when hold"

type bigintMember struct {
	name   string
	member func() Field
}

func bigintMembers() []bigintMember {
	return []bigintMember{
		{"bits", func() Field { return Bits(2, "v", 1) }},
		{"packed", func() Field { return Packed(1, 2, "v", 1, 0) }},
		{"packed bias -1", func() Field { return Packed(1, 2, "v", 1, -1) }},
		{"sized", func() Field { return Sized(2, "v", 1) }},
	}
}

// bigintLayouts: the member behind a split bit and as the one member of a combined flags.
func bigintLayouts(t testing.TB, member func() Field) []*Scheme {
	head := func() []Field { return []Field{U8(0, "mode"), When(1, Eq(0, 1), U8(1, "c"))} }
	fb := FlagByte("fb")
	split := mustScheme(t, 1, append(head(), fb, fb.Bit(member()))...)
	combined := mustScheme(t, 1, append(head(), Flags(2, member()))...)
	return []*Scheme{split, combined}
}

// packOutcome is the hex of a packed row, or the refusal text.
func packOutcome(s *Scheme, row map[string]any) string {
	raw, err := Pack(s, row)
	if err != nil {
		return "refused: " + err.Error()
	}
	return hexOf(raw)
}

func TestAC1BigintCountAbove2Pow53IsRefusedNamingMemberAndCount(t *testing.T) {
	counts := []struct {
		label string
		value any
		shown string
	}{
		{"2^60 as uint64", uint64(1) << 60, "1152921504606846976"},
		{"2^60 as int64", int64(1) << 60, "1152921504606846976"},
		{"2^53+1 as uint64", uint64(1)<<53 + 1, "9007199254740993"},
		{"2^53 as uint64", uint64(1) << 53, "9007199254740992"},
	}
	for _, m := range bigintMembers() {
		for i, s := range bigintLayouts(t, m.member) {
			for _, c := range counts {
				t.Run(fmt.Sprintf("%s %d %s", m.name, i, c.label), func(t *testing.T) {
					// Act
					raw, err := Pack(s, gm("mode", 0, "c", c.value))

					// Assert
					e := asError(t, err, PackRefused)
					want := "v: the count c is " + c.shown + notWrittenTail
					if raw != nil || e.Name != "v" || e.Field != 2 || !strings.HasPrefix(e.Reason, want) {
						t.Fatalf("raw %x err %v", raw, e)
					}
				})
			}
		}
	}
}

func TestAC2CountsThatAreNotAboveZeroOrNotACountPackTheClearBit(t *testing.T) {
	counts := []struct {
		label string
		value any
	}{
		{"0", uint64(0)}, {"3.5", 3.5}, {"-1", -1}, {`"3"`, "3"}, {"NaN", math.NaN()}, {"true", true}, {"nil", nil},
		{"-2^60", -(int64(1) << 60)},
	}
	for _, m := range bigintMembers() {
		for i, s := range bigintLayouts(t, m.member) {
			for _, c := range counts {
				t.Run(fmt.Sprintf("%s %d %s", m.name, i, c.label), func(t *testing.T) {
					if got := packOutcome(s, gm("mode", 0, "c", c.value)); got != "010000" {
						t.Fatalf("got %s, TypeScript packs 010000", got)
					}
				})
			}
			t.Run(fmt.Sprintf("%s %d left out", m.name, i), func(t *testing.T) {
				if got := packOutcome(s, gm("mode", 0)); got != "010000" {
					t.Fatalf("got %s", got)
				}
			})
		}
	}
}

func TestAC2SafeCountsAboveZeroKeepTheirRefusal(t *testing.T) {
	counts := []struct {
		value any
		shown string
	}{{uint64(3), "3"}, {3, "3"}, {uint64(1)<<53 - 1, "9007199254740991"}}
	for _, m := range bigintMembers() {
		for i, s := range bigintLayouts(t, m.member) {
			for _, c := range counts {
				t.Run(fmt.Sprintf("%s %d %v", m.name, i, c.shown), func(t *testing.T) {
					// Act
					raw, err := Pack(s, gm("mode", 0, "c", c.value))

					// Assert
					e := asError(t, err, PackRefused)
					if raw != nil || e.Name != "v" || !strings.HasPrefix(e.Reason, "v: the count c is "+c.shown+notWrittenTail) {
						t.Fatalf("raw %x err %v", raw, e)
					}
				})
			}
		}
	}
}

// AC-2 of AZ-2447 (U6): a times count above 2^53 behind a clear when. TypeScript packs the clear bit
// ("010000", a documented TypeScript-only split, README U6); C#, Python, Rust and Java refuse it as
// they refuse any count above 0 that no field wrote (Python's text and number checked: the count 2^60,
// 2^53+1, 2^53 and 3 are each refused, naming pt and the number). Go follows the five.
func TestAC2U6TimesCountAbove2Pow53FollowsTheFiveNotTypeScript(t *testing.T) {
	const reads = " in the row, but no field wrote it (the when that holds it is clear), so its times reads no round; " +
		"give the count 0, leave it out, or make the when hold"
	head := func() []Field { return []Field{U8(0, "mode"), When(1, Eq(0, 1), U8(1, "c"))} }
	fb := FlagByte("fb")
	split := mustScheme(t, 1, append(head(), fb, fb.Bit(Times(2, 1, U8(2, "pt"))))...)
	combined := mustScheme(t, 1, append(head(), Flags(2, Times(2, 1, U8(2, "pt"))))...)
	counts := []struct {
		value any
		shown string
	}{
		{uint64(1) << 60, "1152921504606846976"},
		{int64(1) << 60, "1152921504606846976"},
		{uint64(1)<<53 + 1, "9007199254740993"},
		{uint64(1) << 53, "9007199254740992"},
		{uint64(3), "3"},
	}
	for name, s := range map[string]*Scheme{"split bit": split, "combined flags": combined} {
		for _, c := range counts {
			t.Run(fmt.Sprintf("%s %s", name, c.shown), func(t *testing.T) {
				// Act
				raw, err := Pack(s, gm("mode", 0, "c", c.value))

				// Assert
				e := asError(t, err, PackRefused)
				if raw != nil || e.Name != "pt" || e.Field != 2 || !strings.HasPrefix(e.Reason, "pt: the count c is "+c.shown+reads) {
					t.Fatalf("raw %x err %v", raw, e)
				}
			})
		}
		t.Run(name+" count 0 and left out pack the clear bit", func(t *testing.T) {
			if a, b := packOutcome(s, gm("mode", 0, "c", 0)), packOutcome(s, gm("mode", 0)); a != "010000" || b != "010000" {
				t.Fatalf("count 0 %s left out %s", a, b)
			}
		})
	}
}
