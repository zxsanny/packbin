package packbin

import (
	"fmt"
	"strings"
	"testing"
)

// AC-1: the reference rows of _docs/03_implementation/flags_member_reference_cases_loop18.md (times and
// repeat as a flags member, TA TS TG T2 RA R2) and reference_loop22.md section 3 (3a short times lists,
// 3b the repeat shapes, 3c per-name repeat lists), as TypeScript pins them. A group's values are in a
// nested map (Go-4); the bytes are TypeScript's.

// refRow is one reference row. wire "" means the row is refused; field is the member it names.
type refRow struct {
	name   string
	row    map[string]any // nil: only unpacked
	wire   string
	field  string
	reason string
	unpack map[string]any // nil: the row itself
}

// runRefRows packs each row to its wire and unpacks the wire. With strict the unpacked row must equal the
// reference row; the loop 22 probe rows pin only the packed bytes, so there the unpacked row must repack
// to the same bytes.
func runRefRows(t *testing.T, build func(testing.TB) *Scheme, rows []refRow, strict ...bool) {
	t.Helper()
	for _, r := range rows {
		t.Run(r.name, func(t *testing.T) {
			// Arrange
			s := build(t)

			// Act and Assert
			if r.row != nil && r.wire == "" {
				raw, err := Pack(s, r.row)
				e := asError(t, err, PackRefused)
				if raw != nil || e.Name != r.field || !strings.Contains(e.Reason, r.reason) {
					t.Fatalf("raw %x err %v, want a refusal naming %s (%s)", raw, e, r.field, r.reason)
				}
				return
			}
			if r.row != nil {
				if wire := mustPack(t, s, r.row); wire != r.wire {
					t.Fatalf("packs %s, want %s", wire, r.wire)
				}
			}
			if len(strict) > 0 && !strict[0] {
				back := mustUnpackMap(t, s, r.wire)
				if again := mustPack(t, s, back); again != r.wire {
					t.Fatalf("unpacked row %v repacks to %s, want %s", back, again, r.wire)
				}
				return
			}
			want := r.unpack
			if want == nil {
				want = r.row
			}
			if got := fmt.Sprint(mustUnpackMap(t, s, r.wire)); got != fmt.Sprint(want) {
				t.Fatalf("unpacks %s, want %v", got, want)
			}
		})
	}
}

func timesRows(group bool) []refRow {
	row := func(n int, items []any, heading bool) map[string]any {
		m := gm("n", n)
		if items != nil {
			if group {
				m["g"] = gm("pt", items)
			} else {
				m["pt"] = items
			}
		}
		if heading {
			m["heading"] = 90
		}
		return m
	}
	return []refRow{
		{name: "T-0-rounds", row: row(0, nil, true), wire: "0100025a00"},
		{name: "T-1-round", row: row(1, []any{5}, true), wire: "010103055a00"},
		{name: "T-2-rounds", row: row(2, []any{5, 6}, true), wire: "01020305065a00"},
		{name: "T-only-times", row: row(2, []any{5, 6}, false), wire: "0102010506"},
		{name: "T-only-n", row: row(0, nil, false), wire: "010000"},
		{name: "T-old-packet (unpack only)", wire: "0100025a00", unpack: row(0, nil, true)},
		{name: "T-new-packet (unpack only)", wire: "01020305065a00", unpack: row(2, []any{5, 6}, true)},
		{name: "T-list-too-short", row: row(2, []any{5}, true), field: "pt", reason: ""},
		{name: "T-values-missing", row: row(1, nil, true), field: "pt", reason: ""},
		{name: "T-count-0-values-given", row: row(0, []any{5}, true), field: "pt", reason: "1 items, times count 0"},
		{name: "T-list-too-long", row: row(1, []any{5, 6}, true), field: "pt", reason: "2 items, times count 1"},
	}
}

func TestAC1ReferenceLoop18TimesAsAFlagsMember(t *testing.T) {
	ta := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, U8(0, "n"), Flags(1, Times(1, 0, U8(1, "pt")), U16(2, "heading")))
	}
	split := func(t testing.TB) *Scheme {
		fb := FlagByte("m")
		return mustScheme(t, 1, U8(0, "n"), fb, fb.Bit(Times(1, 0, U8(1, "pt"))), fb.Bit(U16(2, "heading")))
	}
	tg := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, U8(0, "n"), Flags(1, Group(1, "g", Times(1, 0, U8(1, "pt"))), U16(2, "heading")))
	}
	t2 := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, U8(0, "n"), Flags(1, Times(1, 0, U8(1, "pt"), U8(2, "pu")), U16(3, "heading")))
	}
	t.Run("TA", func(t *testing.T) { runRefRows(t, ta, timesRows(false)) })
	t.Run("TS", func(t *testing.T) { runRefRows(t, split, timesRows(false)) })
	t.Run("TG", func(t *testing.T) { runRefRows(t, tg, timesRows(true)) })
	t.Run("T2", func(t *testing.T) {
		runRefRows(t, t2, []refRow{
			{name: "T-two-values-missing", row: gm("n", 1, "pt", []any{5}, "heading", 90), field: "pu"},
			{name: "T-two-values-1", row: gm("n", 1, "pt", []any{5}, "pu", []any{6}, "heading", 90), wire: "01010305065a00"},
			{name: "T-two-values-2", row: gm("n", 2, "pt", []any{5, 6}, "pu", []any{7, 8}, "heading", 90), wire: "010203050706085a00"},
		})
	})
}

func TestAC1ReferenceLoop18RepeatAsAFlagsMember(t *testing.T) {
	ra := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, U8(0, "mode"), Flags(1, U16(1, "heading"), Repeat(2, U8(2, "pt"))))
	}
	r2 := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, U8(0, "mode"), Flags(1, U16(1, "heading"), Repeat(2, U8(2, "pt"), U8(3, "pu"))))
	}
	t.Run("RA", func(t *testing.T) {
		runRefRows(t, ra, []refRow{
			{name: "R-0-rounds", row: gm("mode", 1, "heading", 90), wire: "0101015a00"},
			{name: "R-1-round", row: gm("mode", 1, "pt", []any{5}, "heading", 90), wire: "0101035a0005"},
			{name: "R-2-rounds", row: gm("mode", 1, "pt", []any{5, 6}, "heading", 90), wire: "0101035a000506"},
			{name: "R-only-repeat", row: gm("mode", 1, "pt", []any{5, 6}), wire: "0101020506"},
			{name: "R-only-mode", row: gm("mode", 1), wire: "010100"},
			{name: "R-old-packet (unpack only)", wire: "0101015a00", unpack: gm("mode", 1, "heading", 90)},
			{name: "R-new-packet (unpack only)", wire: "0101035a000506", unpack: gm("mode", 1, "pt", []any{5, 6}, "heading", 90)},
		})
	})
	t.Run("R2", func(t *testing.T) {
		runRefRows(t, r2, []refRow{
			{name: "R-missing-body-value", row: gm("mode", 1, "pt", []any{5}, "heading", 90), field: "pu"},
			{name: "R-two-values-1", row: gm("mode", 1, "pt", []any{5}, "pu", []any{6}, "heading", 90), wire: "0101035a000506"},
			{name: "R-two-values-2", row: gm("mode", 1, "pt", []any{5, 6}, "pu", []any{7, 8}, "heading", 90),
				wire: "0101035a0005070608"},
			{name: "R-two-values-unpack", wire: "0101035a0005060708",
				unpack: gm("mode", 1, "pt", []any{5, 7}, "pu", []any{6, 8}, "heading", 90)},
		})
	})
}

// reference_loop22.md 3a: a short times list under flags (shape A: flags inside the body) and the
// shape B refusals (times as a flags member, and as a split bit).
func TestAC1ReferenceLoop22ShortTimesLists(t *testing.T) {
	a := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, U8(0, "c"), Times(1, 0, Flags(1, U8(1, "v"))))
	}
	withW := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, U8(0, "c"), Times(1, 0, U8(1, "w"), Flags(2, U8(2, "v"))))
	}
	t.Run("shape A", func(t *testing.T) {
		runRefRows(t, a, []refRow{
			{name: "A1 short", row: gm("c", 2, "v", []any{5}), wire: "0102010500"},
			{name: "A2 empty", row: gm("c", 2, "v", []any{}), wire: "01020000", unpack: gm("c", 2)},
			{name: "A3 absent", row: gm("c", 2), wire: "01020000"},
			{name: "A4 full", row: gm("c", 2, "v", []any{5, 6}), wire: "010201050106"},
			{name: "A5 an absent entry", row: gm("c", 2, "v", []any{5, nil}), wire: "0102010500", unpack: gm("c", 2, "v", []any{5, nil})},
			{name: "A6 lone", row: gm("c", 2, "v", 5), wire: "010201050105", unpack: gm("c", 2, "v", []any{5, 5})},
			{name: "A7 count 0", row: gm("c", 0), wire: "0100"},
		}, false)
	})
	t.Run("shape A with a required member", func(t *testing.T) {
		runRefRows(t, withW, []refRow{
			{name: "A8", row: gm("c", 2, "w", []any{1, 2}, "v", []any{5}), wire: "01020101050200",
				unpack: gm("c", 2, "w", []any{1, 2}, "v", []any{5, nil})},
			{name: "A9", row: gm("c", 2, "w", []any{1, 2}, "v", []any{}), wire: "010201000200", unpack: gm("c", 2, "w", []any{1, 2})},
			{name: "A10", row: gm("c", 2, "w", []any{1, 2}, "v", []any{5, 6}), wire: "0102010105020106"},
			{name: "A11", row: gm("c", 3, "w", []any{1, 2, 3}, "v", []any{5}), wire: "010301010502000300",
				unpack: gm("c", 3, "w", []any{1, 2, 3}, "v", []any{5, nil, nil})},
		}, false)
	})
	b1 := func(t testing.TB) *Scheme { return mustScheme(t, 1, Flags(0, U8(0, "n"), Times(1, 0, U8(1, "pt")))) }
	b4 := func(t testing.TB) *Scheme { return mustScheme(t, 1, U8(0, "n"), Flags(1, Times(1, 0, U8(1, "pt")))) }
	b6 := func(t testing.TB) *Scheme {
		fb := FlagByte("fb")
		return mustScheme(t, 1, U8(0, "n"), fb, fb.Bit(Times(1, 0, U8(1, "pt"))))
	}
	t.Run("B1 combined flags with the count", func(t *testing.T) {
		runRefRows(t, b1, []refRow{
			{name: "short", row: gm("n", 2, "pt", []any{5}), field: "pt", reason: "missing pt"},
			{name: "empty", row: gm("n", 2, "pt", []any{}), field: "pt", reason: "missing pt"},
			{name: "absent", row: gm("n", 2), field: "pt", reason: "missing pt"},
			{name: "B2 full", row: gm("n", 2, "pt", []any{5, 6}), wire: "0103020506"},
			{name: "B2 lone", row: gm("n", 2, "pt", 5), wire: "0103020505", unpack: gm("n", 2, "pt", []any{5, 5})},
			{name: "B3 too long", row: gm("n", 1, "pt", []any{5, 6}), field: "pt", reason: "pt: 2 items, times count 1"},
		}, false)
	})
	t.Run("B4 times in flags after the count", func(t *testing.T) {
		runRefRows(t, b4, []refRow{
			{name: "short", row: gm("n", 2, "pt", []any{5}), field: "pt", reason: "missing pt"},
			{name: "empty", row: gm("n", 2, "pt", []any{}), field: "pt", reason: "missing pt"},
			{name: "absent", row: gm("n", 2), field: "pt", reason: "missing pt"},
			{name: "B5 full", row: gm("n", 2, "pt", []any{5, 6}), wire: "0102010506"},
			{name: "B5 count 0", row: gm("n", 0), wire: "010000"},
		}, false)
	})
	t.Run("B6 split bit after the count", func(t *testing.T) {
		runRefRows(t, b6, []refRow{
			{name: "short", row: gm("n", 2, "pt", []any{5}), field: "pt", reason: "missing pt"},
			{name: "empty", row: gm("n", 2, "pt", []any{}), field: "pt", reason: "missing pt"},
			{name: "full", row: gm("n", 2, "pt", []any{5, 6}), wire: "0102010506"},
		}, false)
	})
}

// reference_loop22.md 3b and 3c: the repeat shapes and per-name repeat lists.
func TestAC1ReferenceLoop22RepeatShapes(t *testing.T) {
	one := func(t testing.TB) *Scheme { return mustScheme(t, 1, Repeat(0, U8(0, "k"))) }
	two := func(t testing.TB) *Scheme { return mustScheme(t, 1, Repeat(0, U8(0, "a"), U8(1, "b"))) }
	whenV := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, Repeat(0, U8(0, "k"), When(1, Eq(0, 1), U8(1, "v"))))
	}
	nx := func(t testing.TB) *Scheme { return mustScheme(t, 1, Repeat(0, U8(0, "n"), U8(1, "x"))) }
	t.Run("R1", func(t *testing.T) {
		runRefRows(t, one, []refRow{
			{name: "R1a lone value", row: gm("k", 7), wire: "0107", unpack: gm("k", []any{7})},
			{name: "R1b one", row: gm("k", []any{7}), wire: "0107"},
			{name: "R1b two", row: gm("k", []any{7, 8}), wire: "010708"},
		}, false)
	})
	t.Run("R2", func(t *testing.T) {
		runRefRows(t, two, []refRow{
			{name: "R2a lone b", row: gm("a", []any{1, 2}, "b", 7), wire: "0101070207", unpack: gm("a", []any{1, 2}, "b", []any{7, 7})},
			{name: "R2b lone a", row: gm("a", 1, "b", []any{5, 6}), wire: "0101050106", unpack: gm("a", []any{1, 1}, "b", []any{5, 6})},
			{name: "R2c both full", row: gm("a", []any{1, 2}, "b", []any{5, 6}), wire: "0101050206"},
			{name: "R2d short required b", row: gm("a", []any{1, 2, 3}, "b", []any{5}), field: "b", reason: "missing b"},
			{name: "R2e short required a", row: gm("a", []any{1}, "b", []any{5, 6, 7}), field: "a", reason: "missing a"},
			{name: "R2f empty required b", row: gm("a", []any{1, 2}, "b", []any{}), field: "b", reason: "missing b"},
			{name: "R2f absent required b", row: gm("a", []any{1, 2}), field: "b", reason: "missing b"},
		}, false)
	})
	t.Run("R3", func(t *testing.T) {
		runRefRows(t, whenV, []refRow{
			{name: "R3a", row: gm("k", []any{1, 2}, "v", []any{9}), wire: "01010902", unpack: gm("k", []any{1, 2}, "v", []any{9, nil})},
			{name: "R3b extra entry ignored", row: gm("k", []any{1, 2}, "v", []any{9, 8}), wire: "01010902",
				unpack: gm("k", []any{1, 2}, "v", []any{9, nil})},
			{name: "R3c", row: gm("k", []any{1, 1}, "v", []any{9, 8}), wire: "0101090108"},
			{name: "R3d short held when", row: gm("k", []any{1, 1}, "v", []any{9}), field: "v", reason: "missing v"},
			{name: "R3e lone", row: gm("k", []any{1, 1}, "v", 9), wire: "0101090109", unpack: gm("k", []any{1, 1}, "v", []any{9, 9})},
			{name: "R3f no value needed", row: gm("k", []any{2, 2}, "v", []any{9}), wire: "010202",
				unpack: gm("k", []any{2, 2}, "v", []any{nil, nil})},
			{name: "R3g absent but needed", row: gm("k", []any{1, 2}), field: "v", reason: "missing v"},
			{name: "R3g absent but needed, both", row: gm("k", []any{1, 1}), field: "v", reason: "missing v"},
		}, false)
	})
	t.Run("C", func(t *testing.T) {
		runRefRows(t, nx, []refRow{
			{name: "C1", row: gm("n", []any{1, 2}, "x", []any{5, 6}), wire: "0101050206"},
			{name: "C2 x missing", row: gm("n", []any{1, 2}), field: "x", reason: "missing x"},
			{name: "C2 n missing", row: gm("x", []any{5, 6}), field: "n", reason: "missing n"},
			{name: "C3 lone x", row: gm("n", []any{1, 2}, "x", 5), wire: "0101050205", unpack: gm("n", []any{1, 2}, "x", []any{5, 5})},
			{name: "C4 nothing", row: gm(), wire: "01", unpack: gm("n", []any{}, "x", []any{})},
		}, false)
	})
}

// reference_loop21_slots.md rows 11 to 14: times and one slot counter for the whole call.
func TestAC1ReferenceLoop21TimesAndOneCounter(t *testing.T) {
	timesS := func(t testing.TB) *Scheme {
		s := mustScheme(t, 1, U8(0, "n"), Times(1, 0, U8(1, "m"), When(2, Eq(1, 1), U8(2, "k")), When(3, Eq(1, 2), U8(3, "k"))))
		return withSlots(t, s, 4)
	}
	both := func(t testing.TB) *Scheme {
		s := mustScheme(t, 1, U8(0, "n"), Times(1, 0, U8(1, "a")), Repeat(2, U8(2, "b")))
		return withSlots(t, s, 3)
	}
	runPacks(t, []packCase{
		{"11 packs at the limit", timesS, gm("n", 2, "m", []any{1, 2}, "k", []any{7, 8}), "010201070208"},
		{"13 packs at the limit", both, gm("n", 1, "a", []any{1}, "b", []any{2, 3}), "0101010203"},
	})
	runRefusals(t, []refusalCase{
		{"12 the third round passes the limit", timesS, gm("n", 3, "m", []any{1, 2, 1}, "k", []any{7, 8, 9}), 1, "m",
			"the rounds would hold 6 slots, above the limit of 4 slots"},
		{"14 the shared counter passes the limit", both, gm("n", 1, "a", []any{1}, "b", []any{2, 3, 4}), 2, "b",
			"the rounds would hold 4 slots, above the limit of 3 slots"},
	})
}

func withSlots(t testing.TB, s *Scheme, slots int) *Scheme {
	t.Helper()
	l := s.Limits()
	l.MaxSlots = slots
	out, err := s.WithLimits(l)
	if err != nil {
		t.Fatalf("WithLimits: %v", err)
	}
	return out
}
