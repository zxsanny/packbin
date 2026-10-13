package packbin

import (
	"strings"
	"testing"
)

// AC-3: the U11 no-value count (loop22-novalue-count, loop23-novalue-nested) and the U6/U7 rows of
// loop21-parity-probes: a bits, packed or sized member (or a times) whose count the row gives above 0
// behind a clear when is refused, naming the member and the count.

const u11Text = "v: the count c is 3 in the row, but no field wrote it (the when that holds it is clear), so the member reads nothing"

type u11Kind struct {
	name   string
	member func(id, countID int) Field
	value  any
	set    string // the member's bytes for count 3
}

func u11Kinds() []u11Kind {
	return []u11Kind{
		{"bits", func(id, c int) Field { return Bits(id, "v", c) }, []int{1, 0, 1}, "05"},
		{"packed", func(id, c int) Field { return Packed(1, id, "v", c, 0) }, []int{1, 0, 1}, "05"},
		{"sized", func(id, c int) Field { return Sized(id, "v", c) }, []byte{1, 2, 3}, "010203"},
	}
}

// behind puts inner behind a split flag byte's bit or as the one member of a combined flags at id.
func behind(split bool, id int, inner Field) []Field {
	if !split {
		return []Field{Flags(id, inner)}
	}
	fb := FlagByte("fb")
	return []Field{fb, fb.Bit(inner)}
}

// u11Body is row 56 with ids from b: mode b, c b+1, the member b+2.
func u11Body(k u11Kind, split bool, b int) []Field {
	head := []Field{U8(b, "mode"), When(b+1, Eq(b, 1), U8(b+1, "c"))}
	return append(head, behind(split, b+2, k.member(b+2, b+1))...)
}

// AC-3 (loop22): the top-level row 56, split bit and combined flags.
func TestAC3U11TopLevel(t *testing.T) {
	for _, k := range u11Kinds() {
		for _, split := range []bool{true, false} {
			name := k.name + map[bool]string{true: " split", false: " flags"}[split]
			s := func(t testing.TB) *Scheme { return mustScheme(t, 1, u11Body(k, split, 0)...) }
			setHex := "01010301" + k.set // the flag byte, then the member
			t.Run(name, func(t *testing.T) {
				runRefusals(t, []refusalCase{
					{"count 3, no value", s, gm("mode", 0, "c", 3), 2, "v", u11Text},
					{"a uint64 count", s, gm("mode", 0, "c", uint64(3)), 2, "v", u11Text},
					{"a nil slice is no value", s, gm("mode", 0, "c", 3, "v", []int(nil)), 2, "v", u11Text},
					{"the value with the clear when", s, gm("mode", 0, "c", 3, "v", k.value), 2, "v", "v: count c was not written"},
				})
				runPacks(t, []packCase{
					{"count 0", s, gm("mode", 0, "c", 0), "010000"},
					{"count left out", s, gm("mode", 0), "010000"},
					{"a holding when, no value", s, gm("mode", 1, "c", 3), "01010300"},
					{"a holding when with the value", s, gm("mode", 1, "c", 3, "v", k.value), setHex},
				})
			})
		}
		t.Run(k.name+" plain", func(t *testing.T) {
			plain := func(t testing.TB) *Scheme {
				return mustScheme(t, 1, U8(0, "mode"), When(1, Eq(0, 1), U8(1, "c")), k.member(2, 1))
			}
			runRefusals(t, []refusalCase{
				{"no value", plain, gm("mode", 0, "c", 3), 2, "v", "v: count c was not written"},
				{"the value", plain, gm("mode", 0, "c", 3, "v", k.value), 2, "v", "v: count c was not written"},
			})
			runPacks(t, []packCase{{"a holding when", plain, gm("mode", 1, "c", 3, "v", k.value), "010103" + k.set}})
		})
	}
	// packed with bias -1: the count is looked at after the bias.
	biased := func(t testing.TB) *Scheme {
		fb := FlagByte("fb")
		return mustScheme(t, 1, U8(0, "mode"), When(1, Eq(0, 1), U8(1, "c")), fb, fb.Bit(Packed(1, 2, "v", 1, -1)))
	}
	runPacks(t, []packCase{{"bias -1, count 1", biased, gm("mode", 0, "c", 1), "010000"}})
	runRefusals(t, []refusalCase{{"bias -1, count 3", biased, gm("mode", 0, "c", 3), 2, "v", u11Text}})
}

type u11Position struct {
	name      string
	layout    func(k u11Kind, split bool) []Field
	refused   func(k u11Kind) []map[string]any
	unchanged func(k u11Kind) []map[string]any
	wires     func(k u11Kind) []string
}

func u11Positions() []u11Position {
	inner := func(k u11Kind) []string { return []string{"010000", "010000", "01010300", "01010301" + k.set} }
	outer := func(k u11Kind) []string { return []string{"01010000", "01010000", "0101010300", "0101010301" + k.set} }
	return []u11Position{
		{"the body inside a group", func(k u11Kind, split bool) []Field {
			return []Field{Group(0, "g", u11Body(k, split, 0)...)}
		}, func(u11Kind) []map[string]any { return []map[string]any{gm("g", gm("mode", 0, "c", 3))} },
			func(k u11Kind) []map[string]any {
				return []map[string]any{gm("g", gm("mode", 0, "c", 0)), gm("g", gm("mode", 0)), gm("g", gm("mode", 1, "c", 3)),
					gm("g", gm("mode", 1, "c", 3, "v", k.value))}
			}, inner},
		{"a bit holding a group holding the member", func(k u11Kind, split bool) []Field {
			head := []Field{U8(0, "mode"), When(1, Eq(0, 1), U8(1, "c"))}
			return append(head, behind(split, 2, Group(2, "g", k.member(2, 1)))...)
		}, func(u11Kind) []map[string]any { return []map[string]any{gm("mode", 0, "c", 3)} },
			func(k u11Kind) []map[string]any {
				return []map[string]any{gm("mode", 0, "c", 0), gm("mode", 0), gm("mode", 1, "c", 3), gm("mode", 1, "c", 3, "g", gm("v", k.value))}
			}, inner},
		{"the body inside an outer holding when", func(k u11Kind, split bool) []Field {
			return []Field{U8(0, "o"), When(1, Eq(0, 1), u11Body(k, split, 1)...)}
		}, func(u11Kind) []map[string]any { return []map[string]any{gm("o", 1, "mode", 0, "c", 3)} },
			func(k u11Kind) []map[string]any {
				return []map[string]any{gm("o", 1, "mode", 0, "c", 0), gm("o", 1, "mode", 0), gm("o", 1, "mode", 1, "c", 3),
					gm("o", 1, "mode", 1, "c", 3, "v", k.value)}
			}, outer},
		{"a bit holding a holding when around the member", func(k u11Kind, split bool) []Field {
			head := []Field{U8(0, "o"), U8(1, "mode"), When(2, Eq(1, 1), U8(2, "c"))}
			return append(head, behind(split, 3, When(3, Eq(0, 1), k.member(3, 2)))...)
		}, func(u11Kind) []map[string]any { return []map[string]any{gm("o", 1, "mode", 0, "c", 3)} },
			func(k u11Kind) []map[string]any {
				return []map[string]any{gm("o", 1, "mode", 0, "c", 0), gm("o", 1, "mode", 0), gm("o", 1, "mode", 1, "c", 3),
					gm("o", 1, "mode", 1, "c", 3, "v", k.value)}
			}, outer},
		{"a times round body", func(k u11Kind, split bool) []Field {
			return []Field{U8(0, "n"), Times(1, 0, u11Body(k, split, 1)...)}
		}, func(u11Kind) []map[string]any {
			return []map[string]any{gm("n", 1, "mode", []any{0}, "c", []any{3}), gm("n", 2, "mode", []any{1, 0}, "c", []any{0, 3})}
		}, func(k u11Kind) []map[string]any {
			return []map[string]any{gm("n", 2, "mode", []any{1, 0}, "c", []any{0, 0}), gm("n", 1, "mode", []any{0}),
				gm("n", 1, "mode", []any{1}, "c", []any{3}), gm("n", 1, "mode", []any{1}, "c", []any{3}, "v", []any{k.value})}
		}, func(k u11Kind) []string {
			return []string{"01020100000000", "01010000", "0101010300", "0101010301" + k.set}
		}},
		{"a repeat round body", func(k u11Kind, split bool) []Field {
			return []Field{Repeat(0, u11Body(k, split, 0)...)}
		}, func(u11Kind) []map[string]any {
			return []map[string]any{gm("mode", []any{0}, "c", []any{3}), gm("mode", []any{1, 0}, "c", []any{0, 3})}
		}, func(k u11Kind) []map[string]any {
			return []map[string]any{gm("mode", []any{1, 0}, "c", []any{0, 0}), gm("mode", []any{0}),
				gm("mode", []any{1}, "c", []any{3}), gm("mode", []any{1}, "c", []any{3}, "v", []any{k.value})}
		}, func(k u11Kind) []string { return []string{"010100000000", "010000", "01010300", "01010301" + k.set} }},
	}
}

// AC-3 (loop23): the U11 refusal in the six nested positions, for each kind, split bit and flags.
func TestAC3U11NestedPositions(t *testing.T) {
	for _, pos := range u11Positions() {
		for _, k := range u11Kinds() {
			for _, split := range []bool{true, false} {
				t.Run(pos.name+" "+k.name+map[bool]string{true: " split", false: " flags"}[split], func(t *testing.T) {
					// Arrange
					s := mustScheme(t, 1, pos.layout(k, split)...)

					// Act and Assert
					for _, row := range pos.refused(k) {
						raw, err := Pack(s, row)
						e := asError(t, err, PackRefused)
						if raw != nil || e.Name != "v" || !strings.HasPrefix(e.Reason, u11Text) {
							t.Fatalf("%v: %x %v", row, raw, e)
						}
					}
					for i, row := range pos.unchanged(k) {
						if wire := mustPack(t, s, row); wire != pos.wires(k)[i] {
							t.Fatalf("%v: %s, want %s", row, wire, pos.wires(k)[i])
						}
					}
				})
			}
		}
	}
}

// A member inside the clear inner when itself is a silent skip, not U11.
func TestAC3U11MemberInsideTheClearWhenIsSilent(t *testing.T) {
	for _, k := range u11Kinds() {
		for _, split := range []bool{true, false} {
			// Arrange
			body := append([]Field{U8(2, "c")}, behind(split, 3, k.member(3, 2))...)
			s := mustScheme(t, 1, U8(0, "o"), When(1, Eq(0, 1), U8(1, "mode"), When(2, Eq(1, 1), body...)))

			// Act
			wire := mustPack(t, s, gm("o", 1, "mode", 0, "c", 3))

			// Assert
			if wire != "010100" {
				t.Fatalf("%s %v: %s", k.name, split, wire)
			}
		}
	}
}

// U6 (loop21): a times count above 0 behind a clear when, with no rounds, is refused naming the member.
func TestAC3U6TimesCountBehindAClearWhen(t *testing.T) {
	split := func(t testing.TB) *Scheme {
		fb := FlagByte("fb")
		return mustScheme(t, 1, U8(0, "mode"), When(1, Eq(0, 1), U8(1, "c")), fb, fb.Bit(Times(2, 1, U8(2, "pt"))),
			fb.Bit(U16(3, "heading")))
	}
	combined := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, U8(0, "mode"), When(1, Eq(0, 1), U8(1, "c")), Flags(2, Times(2, 1, U8(2, "pt")), U16(3, "heading")))
	}
	plain := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, U8(0, "mode"), When(1, Eq(0, 1), U8(1, "c")), Times(2, 1, U8(2, "pt")), U16(3, "heading"))
	}
	const reads = "in the row, but no field wrote it (the when that holds it is clear), so its times reads no round"
	runRefusals(t, []refusalCase{
		{"count 1, body absent", split, gm("mode", 0, "c", 1, "heading", 90), 2, "pt", "pt: the count c is 1 " + reads},
		{"count 1, body empty", split, gm("mode", 0, "c", 1, "pt", []any{}, "heading", 90), 2, "pt", "the count c is 1 " + reads},
		{"count 2, combined flags", combined, gm("mode", 0, "c", 2, "heading", 90), 2, "pt", "the count c is 2 " + reads},
		{"a uint64 count", split, gm("mode", 0, "c", uint64(3), "heading", 90), 2, "pt", "the count c is 3 " + reads},
		{"values given keep their own error", split, gm("mode", 0, "c", 2, "pt", []any{5, 6}, "heading", 90), 2, "pt", droppedBeforeByte},
		{"plain times, count 1", plain, gm("mode", 0, "c", 1, "heading", 90), 2, "pt", "times: count c was not written"},
		{"plain times, count 0", plain, gm("mode", 0, "c", 0, "heading", 90), 2, "pt", "times: count c was not written"},
	})
	runPacks(t, []packCase{
		{"count 0", split, gm("mode", 0, "c", 0, "heading", 90), "0100025a00"},
		{"count left out", split, gm("mode", 0, "heading", 90), "0100025a00"},
		{"a holding when", split, gm("mode", 1, "c", 1, "pt", []any{5}, "heading", 90), "01010103055a00"},
	})
}

// G-5 with a count: an empty slice is a value of 0 items (the bit is set and count 0 written), a nil
// slice is no value (the bit is clear).
func TestAC3EmptySliceIsZeroItemsNilIsNoValue(t *testing.T) {
	s := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, U8(0, "n"), Flags(1, Bits(1, "v", 0), Sized(2, "p", 0)))
	}
	runPacks(t, []packCase{
		{"empty slices", s, gm("n", 0, "v", []int{}, "p", []byte{}), "010003"},
		{"nil slices", s, gm("n", 0, "v", []int(nil), "p", []byte(nil)), "010000"},
	})
}
