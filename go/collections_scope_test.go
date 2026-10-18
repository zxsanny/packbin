package packbin

import (
	"reflect"
	"strings"
	"testing"
)

// AC-2 (duplicate-names): a list or dict element has a member namespace of its own, with the same rules.
func TestAC2ElementsHaveANamespaceOfTheirOwn(t *testing.T) {
	runPacks(t, []packCase{
		{"an element named like a top-level field", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, U8(0, "a"), List("xs", U8(0, "a")))
		}, gm("a", 7, "xs", []any{1, 2}), "010702000102"},
		{"a group element member named like a top-level field", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, U8(0, "a"), List("pts", Nested("p", U8(0, "a"), U8(1, "b"))))
		}, gm("a", 7, "pts", []any{gm("a", 1, "b", 2)}), "010701000102"},
		{"two elements may use the same member names", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, List("xs", Nested("p", U8(0, "a"))), Dict("ys", Nested("q", U8(0, "a"))))
		}, gm("xs", []any{gm("a", 1)}, "ys", gm("k", gm("a", 2))), "01010001" + "010002106b02"},
		{"a group element inside a group element has a scope of its own", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, List("outer", Nested("g", U8(0, "a"), List("inner", Nested("h", U8(0, "a"))))))
		}, gm("outer", []any{gm("a", 1, "inner", []any{gm("a", 2)})}), "010100" + "01" + "0100" + "02"},
	})
	for name, fields := range map[string][]Field{
		"a name twice at the top of a group element": {List("pts", Nested("g", U8(0, "a"), U8(1, "a")))},
		"a name twice in a dict group element":       {Dict("m", Nested("g", U8(0, "a"), U8(1, "a")))},
		"a name twice in a flags element":            {List("xs", Flags(0, U8(0, "a"), U8(1, "a")))},
	} {
		t.Run(name, func(t *testing.T) {
			if e := buildRefusal(t, fields...); !strings.Contains(e.Reason, "declared twice") {
				t.Fatalf("got %v", e)
			}
		})
	}
}

// AC-2 (eq-source-kinds, reference-scope, flag-scope): what a when, a count and a flag bit may name.
func TestAC2ReferencesAndFlagBitsStopAtTheElement(t *testing.T) {
	cases := map[string]struct {
		fields []Field
		reason string
	}{
		"a when naming a utf8 field": {[]Field{Utf8(0, "x"), When(1, Eq(0, 1), U8(1, "v"))},
			"when 1: eq names field id 0 (x), which is not an integer or a bool"},
		"a times count naming a utf8 field": {[]Field{Utf8(0, "n"), Times(1, 0, U8(1, "v"))},
			"times 1: count names field id 0 (n), which is not an integer"},
		"a sized count naming a utf8 field": {[]Field{Utf8(0, "n"), Sized(1, "p", 0)},
			"sized 1: count names field id 0 (n), which is not an integer"},
		"a count naming itself in a list element": {[]Field{U8(0, "n"), List("xs", Sized(0, "p", 0))},
			"sized 0: count names field id 0, which is not declared earlier in the same scope"},
		"a count naming itself in a dict element": {[]Field{U8(0, "n"), Dict("d", Sized(0, "p", 0))},
			"sized 0: count names field id 0, which is not declared earlier in the same scope"},
	}
	for name, c := range cases {
		t.Run(name, func(t *testing.T) {
			if e := buildRefusal(t, c.fields...); !strings.Contains(e.Reason, c.reason) {
				t.Fatalf("got %v, want %q", e, c.reason)
			}
		})
	}
	outer := FlagByte("fb")
	if e := buildRefusal(t, outer, Dict("d", outer.Bit(U8(0, "beta")))); !strings.Contains(e.Reason, "flag bit 0 (beta)") {
		t.Fatalf("got %v", e)
	}
}

// AC-2 (nested-round): a round cannot hold a round, also in a nested row of the round; a list or dict
// element starts outside any round, so a round in an element builds, also inside a round.
func TestAC2RoundsInElements(t *testing.T) {
	const nested = "is inside a repeat or times round; a round cannot hold another repeat or times"
	refused := map[string][]Field{
		"a repeat in a repeat inside a list element": {List("rows", Nested("row", Repeat(0, U8(0, "a"), Repeat(1, U8(1, "b")))))},
		"a repeat in a repeat inside a dict element": {Dict("rows", Nested("row", Repeat(0, U8(0, "a"), Repeat(1, U8(1, "b")))))},
		"a times in a nested row in a repeat":        {Repeat(0, Nested("g", U8(0, "n"), Times(1, 0, U8(1, "v"))))},
	}
	for name, fields := range refused {
		t.Run(name, func(t *testing.T) {
			if e := buildRefusal(t, fields...); !strings.Contains(e.Reason, nested) {
				t.Fatalf("got %v", e)
			}
		})
	}
	inRepeat := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, Repeat(0, U8(0, "k"), List("rows", Nested("row", Repeat(0, U8(0, "v"))))))
	}
	inTimes := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, U8(0, "n"), Times(1, 0, U8(1, "k"),
			Dict("rows", Nested("row", U8(0, "c"), Times(1, 0, U8(1, "v"))))))
	}
	before := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, List("rows", Nested("row", Repeat(0, U8(0, "v")))), Repeat(0, U8(0, "k")))
	}
	cases := []struct {
		name   string
		scheme func(t testing.TB) *Scheme
		row    map[string]any
		wire   string
	}{
		{"a repeat in a list element inside a repeat round", inRepeat, gm("k", []any{1, 2}, "rows", []any{[]any{}, []any{}}), "01010000020000"},
		{"a times in a dict element inside a times round", inTimes, gm("n", 2, "k", []any{1, 2}, "rows", []any{gm(), gm()}), "0102010000020000"},
		{"a repeat in a list element before a round", before, gm("rows", []any{}, "k", []any{3, 4}), "0100000304"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			wire, _, again := repack(t, c.scheme(t), c.row)
			if wire != c.wire || again != c.wire {
				t.Fatalf("wire %s again %s, want %s", wire, again, c.wire)
			}
		})
	}
	filled := gm("k", []any{1}, "rows", []any{[]any{gm("v", []any{5, 6})}})
	// An item of the element holds its own round: its values are lists of its rounds.
	if got := mustPack(t, inRepeat(t), filled); got != "0101"+"0100"+"0506" {
		t.Fatalf("a round in an item packs as %s", got)
	}
	if back := mustUnpackMap(t, inRepeat(t), "0101"+"0100"+"0506"); !reflect.DeepEqual(back["rows"], []any{[]any{gm("v", []any{uint8(5), uint8(6)})}}) {
		t.Fatalf("back %#v", back)
	}
}
