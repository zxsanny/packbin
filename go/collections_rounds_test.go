package packbin

import (
	"reflect"
	"strings"
	"testing"
)

const loneDict = "a dictionary in a repeat or times round needs a list with one dictionary per round"

func dictInTimes(t testing.TB) *Scheme {
	return mustScheme(t, 1, U8(0, "n"), Times(1, 0, Dict("d", Utf8(0, "e"))))
}

func dictInRepeat(t testing.TB) *Scheme { return mustScheme(t, 1, Repeat(0, Dict("d", Utf8(0, "e")))) }

func dictInFlagsTimes(t testing.TB) *Scheme {
	return mustScheme(t, 1, U8(0, "n"), Flags(1, Times(1, 0, Dict("d", Utf8(0, "e"))), U16(1, "h")))
}

// AC-2 (lone-dict-in-round): one dictionary given for a dict name of a round would reach every round,
// so it is refused naming the member; a list with one dictionary per round packs.
func TestAC2LoneDictInARoundIsRefused(t *testing.T) {
	whenGroup := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, U8(0, "n"), Times(1, 0, U8(1, "k"),
			When(2, Eq(1, 1), Group(2, "g", Dict("d", Utf8(0, "e"))))))
	}
	runRefusals(t, []refusalCase{
		{"in a times", dictInTimes, gm("n", 2, "d", gm("a", "x")), -1, "d", "d: " + loneDict},
		{"in a repeat", dictInRepeat, gm("d", gm("a", "x")), -1, "d", loneDict},
		{"a typed lone map", dictInTimes, gm("n", 2, "d", map[string]string{"a": "x"}), -1, "d", loneDict},
		{"in a group map given once, under a when", whenGroup, gm("n", 1, "k", []any{1}, "g", gm("d", gm("a", "x"))), -1, "d", loneDict},
		{"a times with count 0 in flags", dictInFlagsTimes, gm("n", 0, "d", gm("a", "x"), "h", 5), -1, "d", loneDict},
		{"a times with count 0 outside flags", dictInTimes, gm("n", 0, "d", gm("a", "x")), -1, "d", loneDict},
		{"a dictionary that is no list, given for the group member flat", whenGroup,
			gm("n", 1, "k", []any{1}, "d", gm("a", "x")), -1, "d", "member of group g"},
	})
	rows := []any{gm("a", "x"), gm("b", "y")}
	runPacks(t, []packCase{
		{"a list with one dictionary per round, times", dictInTimes, gm("n", 2, "d", rows), "010201000100610100780100010062010079"},
		{"a list with one dictionary per round, repeat", dictInRepeat, gm("d", rows), "0101000100610100780100010062010079"},
		{"a typed slice of maps", dictInTimes, gm("n", 2, "d", []map[string]string{{"a": "x"}, {"b": "y"}}),
			"010201000100610100780100010062010079"},
		{"a dictionary outside a round", func(t testing.TB) *Scheme { return mustScheme(t, 1, Dict("d", Utf8(0, "e"))) },
			gm("d", gm("a", "x")), "010100010061010078"},
		{"a times with count 0 in flags and no dictionary", dictInFlagsTimes, gm("n", 0, "h", 5), "0100020500"},
	})
}

// A list of a round is a list per round: entry i is the list of round i; a lone list is the lists of
// the rounds, so an entry that is no list is refused.
func TestListInARound(t *testing.T) {
	inRepeat := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, Repeat(0, U8(0, "k"), List("tags", U8(0, "t"))))
	}
	optional := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, Repeat(0, U8(0, "k"), Flags(1, List("tags", U8(0, "t")))))
	}
	runPacks(t, []packCase{
		{"a list a round", inRepeat, gm("k", []any{1, 2}, "tags", [][]int{{7, 8}, {}}), "01" + "01" + "0200" + "0708" + "02" + "0000"},
		{"a nil entry leaves the list out of its round", optional, gm("k", []any{1, 2}, "tags", []any{[]int{5}, nil}),
			"01" + "01" + "01" + "0100" + "05" + "02" + "00"},
	})
	runRefusals(t, []refusalCase{
		{"an entry that is no list", inRepeat, gm("k", []any{1}, "tags", []any{7}), -1, "tags", "expected a list"},
		{"a list given once for the rounds", inRepeat, gm("k", []any{1, 2}, "tags", []int{7, 8}), -1, "tags", "expected a list"},
	})
	wire := "01" + "01" + "0200" + "0708" + "02" + "0000"
	back := mustUnpackMap(t, inRepeat(t), wire)
	want := gm("k", []any{uint8(1), uint8(2)}, "tags", []any{[]any{uint8(7), uint8(8)}, []any{}})
	if !reflect.DeepEqual(back, want) || mustPack(t, inRepeat(t), back) != wire {
		t.Fatalf("back %#v", back)
	}
	opt := mustUnpackMap(t, optional(t), "0101010100050200")
	if !reflect.DeepEqual(opt["tags"], []any{[]any{uint8(5)}, nil}) {
		t.Fatalf("optional %#v", opt)
	}
}

// A list or dict inside a group map given once for every round is refused, as a buffer is.
func TestListInALoneGroupOfARoundIsRefused(t *testing.T) {
	s := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, U8(0, "n"), Times(1, 0, U8(1, "k"), Nested("g", List("tags", U8(0, "t")))))
	}
	runRefusals(t, []refusalCase{
		{"a lone group map holding a list", s, gm("n", 1, "k", []any{1}, "g", gm("tags", []any{1})), -1, "tags", "needs a list"},
	})
	runPacks(t, []packCase{
		{"a group map a round", s, gm("n", 2, "k", []any{1, 2}, "g", []any{gm("tags", []any{5}), gm("tags", []any{})}),
			"0102" + "01" + "0100" + "05" + "02" + "0000"},
	})
}

// AC-2 (empty-round-body): an empty round in a list item is refused when the scheme is built.
func TestAC2EmptyRoundInAListItemIsRefused(t *testing.T) {
	cases := map[string][]Field{
		"repeat": {List("xs", Nested("item", Repeat(0)))},
		"times":  {List("items", Nested("item", U32(0, "n"), Times(1, 0)))},
	}
	for name, fields := range cases {
		t.Run(name, func(t *testing.T) {
			if e := buildRefusal(t, fields...); !strings.Contains(e.Reason, "the body holds no member") {
				t.Fatalf("got %v", e)
			}
		})
	}
}

// A split flag byte or a flag bit of the row around is no part of an element, and an element's own
// flag byte is no part of the row.
func TestElementFlagScopeIsItsOwn(t *testing.T) {
	m := FlagByte("m")
	e := buildRefusal(t, m, List("xs", m.Bit(U8(0, "a"))))
	if !strings.Contains(e.Reason, "its flag byte is not read earlier in the same scope") {
		t.Fatalf("got %v", e)
	}
	fb := FlagByte("fb")
	s := mustScheme(t, 1, List("xs", Nested("g", fb, fb.Bit(U8(0, "a")), fb.Bit(U8(1, "b")))))
	runPacks(t, []packCase{
		{"a split flag byte in an element", func(testing.TB) *Scheme { return s },
			gm("xs", []any{gm("a", 1), gm("b", 2), gm()}), "01" + "0300" + "01" + "01" + "02" + "02" + "00"},
	})
}
