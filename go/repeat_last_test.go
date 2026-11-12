package packbin

import (
	"fmt"
	"reflect"
	"testing"
)

// AZ-4215, contract repeat-last 1.0.1: a repeat is the last thing a packet reads. A scheme that breaks
// the rule is refused when it is built; a repeat that is last builds and packs the bytes it packed
// before the rule.

// The two texts of the contract, whole, as Error gives them: the error names the repeat by its anchor.
func repeatFollowed(anchor int, field string) string {
	return fmt.Sprintf("packbin: invalid scheme at field %d: repeat %d: %s follows it; "+
		"a repeat reads to the end of the packet, so nothing can follow it; use times", anchor, anchor, field)
}

func repeatInElement(anchor int) string {
	return fmt.Sprintf("packbin: invalid scheme at field %d: repeat %d is inside a list or dict element; "+
		"a repeat reads to the end of the packet, so another element cannot follow it; use times", anchor, anchor)
}

// The typed rows of the cases: a round is a lastRound, a nested row or an element a lastItem.
type lastRound struct{ V uint8 }

type lastItem struct {
	Mode uint8
	Vs   []lastRound
}

type lastRow struct {
	K, X  uint8
	On    bool
	Vs    []lastRound
	Ws    []lastRound
	M     *lastItem
	Items []lastItem
	D     map[string]lastItem
}

// lastForm is how a case writes its fields: by name for map rows, or bound with Bind for typed rows.
type lastForm bool

const (
	mapRows   lastForm = false
	typedRows lastForm = true
)

func (f lastForm) String() string {
	if f {
		return "typed rows"
	}
	return "map rows"
}

// lastBound is field as the form writes it: as it is for map rows, bound to a member for typed rows.
func lastBound[T, V any](f lastForm, field Field, get func(*T) V, set func(*T, V)) Field {
	if !f {
		return field
	}
	return Bind(field, get, set)
}

// v is the u8 of a round.
func (f lastForm) v(id int, name string) Field {
	return lastBound(f, U8(id, name), func(r *lastRound) uint8 { return r.V }, func(r *lastRound, v uint8) { r.V = v })
}

func (f lastForm) k(id int) Field {
	return lastBound(f, U8(id, "k"), func(r *lastRow) uint8 { return r.K }, func(r *lastRow, v uint8) { r.K = v })
}

func (f lastForm) x(id int) Field {
	return lastBound(f, U8(id, "x"), func(r *lastRow) uint8 { return r.X }, func(r *lastRow, v uint8) { r.X = v })
}

func (f lastForm) mode() Field {
	return lastBound(f, U8(0, "mode"), func(r *lastItem) uint8 { return r.Mode }, func(r *lastItem, v uint8) { r.Mode = v })
}

// rounds is repeat { u8 v } in the row; itemRounds is the same in a nested row or an element.
func (f lastForm) rounds(id int) Field { return f.rowRounds(Repeat(id, f.v(id, "v"))) }

func (f lastForm) rowRounds(round Field) Field {
	return lastBound(f, round, func(r *lastRow) []lastRound { return r.Vs }, func(r *lastRow, v []lastRound) { r.Vs = v })
}

func (f lastForm) itemRounds(id int) Field {
	return lastBound(f, Repeat(id, f.v(id, "v")),
		func(r *lastItem) []lastRound { return r.Vs }, func(r *lastItem, v []lastRound) { r.Vs = v })
}

// modeThenRepeat is the element row of the list and dict cases: u8 mode; repeat { u8 v }.
func (f lastForm) modeThenRepeat() Field { return Nested("item", f.mode(), f.itemRounds(1)) }

type lastRefusal struct {
	name   string
	fields func(f lastForm) []Field
	text   string
}

func runLastRefusals(t *testing.T, forms []lastForm, cases []lastRefusal) {
	t.Helper()
	for _, c := range cases {
		for _, form := range forms {
			t.Run(c.name+", "+form.String(), func(t *testing.T) {
				// Arrange
				fields := c.fields(form)

				// Act
				s, err := NewScheme(1, fields...)
				raw, packErr := Pack(s, gm())

				// Assert: the whole text, and nothing is packed.
				if e := asError(t, err, InvalidScheme); s != nil || e.Error() != c.text {
					t.Fatalf("scheme built: %v; got %q, want %q", s != nil, e.Error(), c.text)
				}
				if e := asError(t, packErr, PackRefused); raw != nil {
					t.Fatalf("packed %x (%v)", raw, e)
				}
			})
		}
	}
}

// AC-1: the refused cases R1 to R8 of the contract, with map rows and with typed rows.
func TestAC1ARepeatThatIsNotLastIsRefusedAtBuild(t *testing.T) {
	runLastRefusals(t, []lastForm{mapRows, typedRows}, []lastRefusal{
		{"R1 a field after the repeat", func(f lastForm) []Field {
			return []Field{f.rounds(0), f.x(1)}
		}, repeatFollowed(0, "field id 1 (x)")},
		{"R2 a field after the when that holds the repeat", func(f lastForm) []Field {
			return []Field{f.k(0), When(1, Eq(0, 1), f.rounds(1)), f.x(2)}
		}, repeatFollowed(1, "field id 2 (x)")},
		{"R3 a field after the flags that holds the repeat", func(f lastForm) []Field {
			return []Field{Flags(0, f.rounds(0)), f.x(1)}
		}, repeatFollowed(0, "field id 1 (x)")},
		{"R4 a field after the nested row that holds the repeat", func(f lastForm) []Field {
			m := lastBound(f, Nested("m", f.itemRounds(0)), func(r *lastRow) *lastItem { return r.M }, func(r *lastRow, v *lastItem) { r.M = v })
			return []Field{m, f.x(0)}
		}, repeatFollowed(0, "field id 0 (x)")},
		{"R5 a second repeat", func(f lastForm) []Field {
			second := lastBound(f, Repeat(1, f.v(1, "w")), func(r *lastRow) []lastRound { return r.Ws }, func(r *lastRow, v []lastRound) { r.Ws = v })
			return []Field{f.rounds(0), second}
		}, repeatFollowed(0, "repeat 1")},
		{"R6 a field under a when that cannot hold together with the repeat's when", func(f lastForm) []Field {
			return []Field{f.k(0), When(1, Eq(0, 1), f.rounds(1)), When(2, Eq(0, 2), f.x(2))}
		}, repeatFollowed(1, "field id 2 (x)")},
		{"R7 a repeat in a list element", func(f lastForm) []Field {
			return []Field{lastBound(f, List("items", f.modeThenRepeat()),
				func(r *lastRow) []lastItem { return r.Items }, func(r *lastRow, v []lastItem) { r.Items = v })}
		}, repeatInElement(1)},
		{"R8 a repeat in a dict element", func(f lastForm) []Field {
			return []Field{lastBound(f, Dict("d", f.modeThenRepeat()),
				func(r *lastRow) map[string]lastItem { return r.D }, func(r *lastRow, v map[string]lastItem) { r.D = v })}
		}, repeatInElement(1)},
	})
}

// AC-1: the rules that ran before this one keep their refusals and texts. R9 of the contract is refused
// by the nesting rule; Go refuses a repeat that is itself the element in the List and Dict constructors.
func TestAC1EarlierRulesKeepTheirTextsBeforeTheRepeatLastRule(t *testing.T) {
	const nested = "packbin: invalid scheme at field 1: repeat 1 is inside a repeat or times round; a round cannot hold another repeat or times"
	runLastRefusals(t, []lastForm{mapRows, typedRows}, []lastRefusal{
		{"R9 a repeat in a times round", func(f lastForm) []Field {
			return []Field{f.k(0), lastBound(f, Times(1, 0, f.itemRounds(1)),
				func(r *lastRow) []lastItem { return r.Items }, func(r *lastRow, v []lastItem) { r.Items = v })}
		}, nested},
	})
	runLastRefusals(t, []lastForm{mapRows}, []lastRefusal{
		{"a repeat in a repeat round, then a field", func(f lastForm) []Field {
			return []Field{Repeat(0, U8(0, "m"), f.rounds(1)), U8(2, "x")}
		}, nested},
		{"a repeat with no member, then a field", func(lastForm) []Field {
			return []Field{Repeat(0), U8(0, "x")}
		}, "packbin: invalid scheme at field 0: repeat 0: " + emptyBody},
		{"a repeat that is the list element", func(f lastForm) []Field {
			return []Field{List("items", f.rounds(0))}
		}, "packbin: invalid scheme at items: list element must be one field"},
		{"a repeat that is the dict element", func(f lastForm) []Field {
			return []Field{Dict("d", f.rounds(0))}
		}, "packbin: invalid scheme at d: repeat is not a dictionary element"},
	})
}

// AC-1: "after" is the repeat's own place and every place around it, nearest first, and the refusal
// names the first field there that can write a byte, in the words of the other scheme errors.
func TestAC1TheRefusalNamesTheFirstFieldAfterTheRepeatThatCanWriteAByte(t *testing.T) {
	runLastRefusals(t, []lastForm{mapRows}, []lastRefusal{
		{"a later field of the when that holds the repeat, before the field after the when", func(f lastForm) []Field {
			return []Field{U8(0, "k"), When(1, Eq(0, 1), f.rounds(1), U8(2, "y")), U8(3, "x")}
		}, repeatFollowed(1, "field id 2 (y)")},
		{"a field two places out: after the when that holds the flags that holds the repeat", func(f lastForm) []Field {
			return []Field{U8(0, "k"), When(1, Eq(0, 1), Flags(1, f.rounds(1))), U8(2, "x")}
		}, repeatFollowed(1, "field id 2 (x)")},
		{"a later member of the flags that holds the repeat", func(f lastForm) []Field {
			return []Field{Flags(0, f.rounds(0), U8(1, "x"))}
		}, repeatFollowed(0, "field id 1 (x)")},
		{"a later member of the flags around the flags that holds the repeat", func(f lastForm) []Field {
			return []Field{Flags(0, Flags(0, f.rounds(0)), U8(1, "x"))}
		}, repeatFollowed(0, "field id 1 (x)")},
		{"a later split flag bit", func(f lastForm) []Field {
			fb := FlagByte("fb")
			return []Field{fb, fb.Bit(f.rounds(0)), fb.Bit(U8(1, "x"))}
		}, repeatFollowed(0, "field id 1 (x)")},
		{"a field under a group is named, not the group", func(f lastForm) []Field {
			return []Field{f.rounds(0), Group(1, "g", U8(1, "x"))}
		}, repeatFollowed(0, "field id 1 (x)")},
		{"a field of a nested row is named by its id in that row", func(f lastForm) []Field {
			return []Field{U8(0, "k"), f.rounds(1), Nested("g", U8(0, "x"))}
		}, repeatFollowed(1, "field id 0 (x)")},
		{"a times is named by its anchor", func(f lastForm) []Field {
			return []Field{U8(0, "n"), f.rounds(1), Times(2, 0, U8(2, "w"))}
		}, repeatFollowed(1, "times 2")},
		{"a list", func(f lastForm) []Field {
			return []Field{f.rounds(0), List("items", U8(0, "e"))}
		}, repeatFollowed(0, "list items")},
		{"a dict", func(f lastForm) []Field {
			return []Field{f.rounds(0), Dict("d", U8(0, "e"))}
		}, repeatFollowed(0, "dict d")},
		{"a flags is named by its anchor", func(f lastForm) []Field {
			return []Field{f.rounds(0), Flags(1, U8(1, "x"))}
		}, repeatFollowed(0, "flags 1")},
		{"a flags that is a later member of the flags that holds the repeat", func(f lastForm) []Field {
			return []Field{Flags(0, f.rounds(0), Flags(1, U8(1, "x")))}
		}, repeatFollowed(0, "flags 1")},
		{"a split flag byte", func(f lastForm) []Field {
			fb := FlagByte("fb")
			return []Field{f.rounds(0), fb, fb.Bit(U8(1, "x"))}
		}, repeatFollowed(0, `flag byte "fb"`)},
		{"a u2 is named by its first slot", func(f lastForm) []Field {
			return []Field{f.rounds(0), U2(Slot(1, "a"), Slot(2, "b"))}
		}, repeatFollowed(0, "field id 1 (a)")},
		{"a sized", func(f lastForm) []Field {
			return []Field{U8(0, "n"), f.rounds(1), Sized(2, "p", 0)}
		}, repeatFollowed(1, "field id 2 (p)")},
		{"a utf8", func(f lastForm) []Field {
			return []Field{f.rounds(0), Utf8(1, "s")}
		}, repeatFollowed(0, "field id 1 (s)")},
		{"a zero-width bytes is passed over for the field after it", func(f lastForm) []Field {
			return []Field{f.rounds(0), Bytes(1, "z", 0), Bytes(2, "x", 1)}
		}, repeatFollowed(0, "field id 2 (x)")},
		{"a repeat whose round writes no byte is a repeat all the same", func(lastForm) []Field {
			return []Field{Repeat(0, Bytes(0, "v", 0)), U8(1, "tail")}
		}, repeatFollowed(0, "field id 1 (tail)")},
		{"the first repeat is named when a third field follows two repeats", func(f lastForm) []Field {
			return []Field{f.rounds(0), Repeat(1, U8(1, "w")), U8(2, "x")}
		}, repeatFollowed(0, "repeat 1")},
	})
}

// AC-1: contract rule 2, a repeat under a when, flags, group or nested row of an element, whatever
// stands after it.
func TestAC1ARepeatInsideAListOrDictElementIsRefused(t *testing.T) {
	runLastRefusals(t, []lastForm{mapRows}, []lastRefusal{
		{"under a when of the element", func(f lastForm) []Field {
			return []Field{List("items", Nested("item", U8(0, "mode"), When(1, Eq(0, 1), f.rounds(1))))}
		}, repeatInElement(1)},
		{"under a flags of the element", func(f lastForm) []Field {
			return []Field{Dict("d", Nested("item", Flags(0, f.rounds(0))))}
		}, repeatInElement(0)},
		{"in a flags element", func(f lastForm) []Field {
			return []Field{List("items", Flags(0, f.rounds(0)))}
		}, repeatInElement(0)},
		{"under a nested row of the element", func(f lastForm) []Field {
			return []Field{List("items", Nested("item", Nested("g", f.rounds(0))))}
		}, repeatInElement(0)},
		{"under an anchored group of the element", func(f lastForm) []Field {
			return []Field{List("items", Nested("item", Group(0, "g", f.rounds(0))))}
		}, repeatInElement(0)},
		{"in the element of a list inside a list element", func(f lastForm) []Field {
			return []Field{List("outer", List("inner", Nested("item", f.rounds(0))))}
		}, repeatInElement(0)},
		{"in the element of a list inside a repeat round", func(f lastForm) []Field {
			return []Field{Repeat(0, U8(0, "k"), List("rows", Nested("row", f.rounds(0))))}
		}, repeatInElement(0)},
		{"in the element of a list before a repeat", func(f lastForm) []Field {
			return []Field{List("rows", Nested("row", f.rounds(0))), Repeat(0, U8(0, "k"))}
		}, repeatInElement(0)},
		{"with a field after it in the element: the element text, not the follower text", func(f lastForm) []Field {
			return []Field{List("items", Nested("item", f.rounds(0), U8(1, "x")))}
		}, repeatInElement(0)},
	})
}

type lastKept struct {
	name   string
	fields func(f lastForm) []Field
	row    map[string]any
	back   map[string]any
	typed  *lastRow // nil: the case has map rows only
	packet string
}

func runLastKept(t *testing.T, cases []lastKept) {
	t.Helper()
	for _, c := range cases {
		for _, form := range []lastForm{mapRows, typedRows} {
			if form == typedRows && c.typed == nil {
				continue
			}
			t.Run(c.name+", "+form.String(), func(t *testing.T) {
				// Arrange
				s := mustScheme(t, 1, c.fields(form)...)
				var row, want any = c.row, c.back
				if form == typedRows {
					row, want = c.typed, c.typed
				}

				// Act
				wire := mustPack(t, s, row)
				var back any
				var err error
				if form == typedRows {
					back, err = Unpack(mustHex(t, wire), s)
				} else {
					back, err = UnpackMap(mustHex(t, wire), s)
				}

				// Assert
				if wire != c.packet || err != nil || !reflect.DeepEqual(back, want) {
					t.Fatalf("packed %s, want %s; back %#v, want %#v; %v", wire, c.packet, back, want, err)
				}
			})
		}
	}
}

func lastU8s(v ...uint8) []any {
	out := make([]any, len(v))
	for i, x := range v {
		out[i] = x
	}
	return out
}

// AC-2: the cases K1 to K5 of the contract build, pack the contract's packet and read the values back.
func TestAC2ARepeatThatIsLastBuildsAndPacksTheSameBytes(t *testing.T) {
	v56 := []lastRound{{5}, {6}}
	runLastKept(t, []lastKept{
		{"K1 a repeat after a field", func(f lastForm) []Field {
			return []Field{f.x(0), f.rounds(1)}
		}, gm("x", 9, "v", []any{5, 6}), gm("x", uint8(9), "v", lastU8s(5, 6)), &lastRow{X: 9, Vs: v56}, "01090506"},
		{"K2 a repeat that is the last thing in a when that nothing follows", func(f lastForm) []Field {
			return []Field{f.k(0), When(1, Eq(0, 1), f.rounds(1))}
		}, gm("k", 1, "v", []any{5, 6}), gm("k", uint8(1), "v", lastU8s(5, 6)), &lastRow{K: 1, Vs: v56}, "01010506"},
		{"K3 a repeat that is the last member of a flags that nothing follows", func(f lastForm) []Field {
			return []Field{Flags(0, f.x(0), f.rounds(1))}
		}, gm("x", 9, "v", []any{5, 6}), gm("x", uint8(9), "v", lastU8s(5, 6)), &lastRow{X: 9, Vs: v56}, "0103090506"},
		{"K4 a times with a field after it", func(f lastForm) []Field {
			return []Field{f.k(0), f.rowRounds(Times(1, 0, f.v(1, "v"))), f.x(2)}
		}, gm("k", 2, "v", []any{5, 6}, "x", 9), gm("k", uint8(2), "v", lastU8s(5, 6), "x", uint8(9)),
			&lastRow{K: 2, Vs: v56, X: 9}, "0102050609"},
		{"K5 a bool bit of an earlier flag byte after the repeat (split form)", func(f lastForm) []Field {
			fb := FlagByte("fb")
			on := lastBound(f, Bool(2, "on"), func(r *lastRow) bool { return r.On }, func(r *lastRow, v bool) { r.On = v })
			return []Field{fb, fb.Bit(f.x(0)), f.rounds(1), fb.Bit(on)}
		}, gm("x", 9, "v", []any{5, 6}, "on", true), gm("x", uint8(9), "v", lastU8s(5, 6), "on", true),
			&lastRow{X: 9, Vs: v56, On: true}, "0103090506"},
	})
}

// AC-1 (unit row 2): a field after the repeat that cannot write a byte does not refuse the scheme.
func TestAC1AFieldAfterTheRepeatThatWritesNoByteBuilds(t *testing.T) {
	runLastKept(t, []lastKept{
		{"a bool member of the flags after the repeat", func(f lastForm) []Field {
			return []Field{Flags(0, U8(0, "x"), f.rounds(1), Bool(2, "on"))}
		}, gm("x", 9, "v", []any{5, 6}, "on", true), gm("x", uint8(9), "v", lastU8s(5, 6), "on", true), nil, "0107090506"},
		{"an empty group under a later bit of an earlier flag byte", func(f lastForm) []Field {
			fb := FlagByte("fb")
			return []Field{fb, fb.Bit(U8(0, "x")), f.rounds(1), fb.Bit(Group(2, "mark"))}
		}, gm("x", 9, "v", []any{5, 6}, "mark", true), gm("x", uint8(9), "v", lastU8s(5, 6), "mark", true), nil, "0103090506"},
		{"a zero-width bytes", func(f lastForm) []Field {
			return []Field{f.rounds(0), Bytes(1, "z", 0)}
		}, gm("v", []any{5, 6}, "z", []byte{}), gm("v", lastU8s(5, 6), "z", []byte{}), nil, "010506"},
		{"a when that holds only a zero-width bytes", func(f lastForm) []Field {
			return []Field{U8(0, "k"), f.rounds(1), When(2, Eq(0, 1), Bytes(2, "z", 0))}
		}, gm("k", 1, "v", []any{5, 6}, "z", []byte{}), gm("k", uint8(1), "v", lastU8s(5, 6), "z", []byte{}), nil, "01010506"},
		{"a times whose body holds only a zero-width bytes, with no round", func(f lastForm) []Field {
			return []Field{U8(0, "n"), f.rounds(1), Times(2, 0, Bytes(2, "z", 0))}
		}, gm("n", 0, "v", []any{5, 6}), gm("n", uint8(0), "v", lastU8s(5, 6)), nil, "01000506"},
	})
}
