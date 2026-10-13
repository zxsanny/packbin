package packbin

import (
	"reflect"
	"strconv"
	"testing"
)

// widthShape is a repeat whose round holds width names; the limit is two rounds' worth, so two rounds pack
// exactly at MaxSlots and a third round would hold MaxSlots + width.
type widthShape struct {
	name       string
	width      int
	body       func() []Field
	row        func(n int) map[string]any
	first      string
	atLimit    string
	oneMore    string
	unpackLeft int
}

func rounds(n int, entry func(i int) any) []any {
	out := make([]any, n)
	for i := range out {
		out[i] = entry(i)
	}
	return out
}

func widthShapes() []widthShape {
	fb := FlagByte("m")
	return []widthShape{
		{name: "empty group under flags: a, g", width: 2,
			body: func() []Field { return []Field{U8(0, "a"), Flags(1, Group(1, "g"))} },
			row: func(n int) map[string]any {
				return map[string]any{"a": rounds(n, func(i int) any { return i + 1 }),
					"g": rounds(n, func(i int) any {
						if i%2 == 0 {
							return true
						}
						return nil
					})}
			},
			first: "a", atLimit: "0101010200", oneMore: "01010102000301", unpackLeft: 2},
		{name: "duplicate leaf names in two when branches: m, k", width: 2,
			body: func() []Field {
				return []Field{U8(0, "m"), When(1, Eq(0, 1), U8(1, "k")), When(2, Eq(0, 2), U8(2, "k"))}
			},
			row: func(n int) map[string]any {
				return map[string]any{"m": rounds(n, func(i int) any { return i%2 + 1 }), "k": rounds(n, func(i int) any { return 7 + i })}
			},
			first: "m", atLimit: "0101070208", oneMore: "01010702080109", unpackLeft: 2},
		{name: "combined flags: on, v", width: 2,
			body: func() []Field { return []Field{Flags(0, Bool(0, "on"), U8(1, "v"))} },
			row: func(n int) map[string]any {
				return map[string]any{"on": rounds(n, func(int) any { return true }), "v": rounds(n, func(i int) any { return 5 + i })}
			},
			first: "on", atLimit: "0103050306", oneMore: "01030503060307", unpackLeft: 2},
		{name: "split bits with flag byte m: a, b", width: 2,
			body: func() []Field { return []Field{fb, fb.Bit(U8(0, "a")), fb.Bit(U8(1, "b"))} },
			row: func(n int) map[string]any {
				return map[string]any{"a": rounds(n, func(i int) any { return 1 + i }), "b": rounds(n, func(i int) any { return 4 + i })}
			},
			first: "a", atLimit: "01030104030205", oneMore: "01030104030205030306", unpackLeft: 3},
		{name: "when that is clear in every round: m, k", width: 2,
			body: func() []Field { return []Field{U8(0, "m"), When(1, Eq(0, 1), U8(1, "k"))} },
			row: func(n int) map[string]any {
				return map[string]any{"m": rounds(n, func(int) any { return 0 })}
			},
			first: "m", atLimit: "010000", oneMore: "01000000", unpackLeft: 1},
		{name: "nested anchored groups: a, b, c", width: 3,
			body: func() []Field {
				return []Field{U8(0, "a"), Group(1, "g", U8(1, "b"), Group(2, "h", U8(2, "c")))}
			},
			row: func(n int) map[string]any {
				return map[string]any{"a": rounds(n, func(i int) any { return 1 + i }),
					"g": rounds(n, func(i int) any {
						return map[string]any{"b": 4 + i, "h": map[string]any{"c": 7 + i}}
					})}
			},
			first: "a", atLimit: "01010407020508", oneMore: "01010407020508030609", unpackLeft: 3},
		{name: "group: a, b", width: 2,
			body: func() []Field { return []Field{U8(0, "a"), Group(1, "g", U8(1, "b"))} },
			row: func(n int) map[string]any {
				return map[string]any{"a": rounds(n, func(i int) any { return 1 + i }),
					"g": rounds(n, func(i int) any { return map[string]any{"b": 4 + i} })}
			},
			first: "a", atLimit: "0101040205", oneMore: "01010402050306", unpackLeft: 2},
		{name: "u2 with three slots: a, p, q, r", width: 4,
			body: func() []Field {
				return []Field{U8(0, "a"), U2(Slot(1, "p"), Slot(2, "q"), Slot(3, "r"))}
			},
			row: func(n int) map[string]any {
				return map[string]any{"a": rounds(n, func(i int) any { return 1 + i }),
					"p": rounds(n, func(int) any { return 1 }), "q": rounds(n, func(int) any { return 2 }),
					"r": rounds(n, func(int) any { return 3 })}
			},
			first: "a", atLimit: "0101390239", oneMore: "01013902390339", unpackLeft: 2},
		{name: "list and dict names: n, l, d", width: 3,
			body: func() []Field {
				return []Field{U8(0, "n"), List("l", U8(0, "e")), Dict("d", U8(0, "e"))}
			},
			row: func(n int) map[string]any {
				return map[string]any{"n": rounds(n, func(i int) any { return 1 + i }),
					"l": rounds(n, func(i int) any { return []any{i, i + 1} }),
					"d": rounds(n, func(i int) any { return map[string]any{"k": i} })}
			},
			first: "n", atLimit: "010102000001010001006b000202000102010001006b01",
			oneMore:    "010102000001010001006b000202000102010001006b010302000203010001006b02",
			unpackLeft: 11},
		{name: "bytes and sized names: n, b, s", width: 3,
			body: func() []Field {
				return []Field{U8(0, "n"), Bytes(1, "b", 2), Sized(2, "s", 0)}
			},
			row: func(n int) map[string]any {
				return map[string]any{"n": rounds(n, func(int) any { return 1 }),
					"b": rounds(n, func(i int) any { return []byte{byte(i), byte(i)} }),
					"s": rounds(n, func(int) any { return []byte{9} })}
			},
			first: "n", atLimit: "010100000901010109", oneMore: "01010000090101010901020209", unpackLeft: 4},
	}
}

func TestAC1RepeatRoundIsChargedTheNamesItHoldsOnPackAndUnpack(t *testing.T) {
	for _, shape := range widthShapes() {
		limit := 2 * shape.width
		at := func(maxSlots int) *Scheme {
			return limited(t, mustScheme(t, 1, Repeat(0, shape.body()...)), func(l *Limits) { l.MaxSlots = maxSlots })
		}
		t.Run(shape.name, func(t *testing.T) {
			// Act
			atLimit := mustPack(t, at(limit), shape.row(2))
			oneMore := mustPack(t, at(limit+shape.width), shape.row(3))
			wide := at(limit)
			row, unpackErr := UnpackMap(mustHex(t, atLimit), wide)
			_, refusedUnpack := UnpackMap(mustHex(t, oneMore), wide)

			// Assert
			if atLimit != shape.atLimit || oneMore != shape.oneMore {
				t.Fatalf("two rounds %s want %s, three rounds %s want %s", atLimit, shape.atLimit, oneMore, shape.oneMore)
			}
			refusedPack(t, wide, shape.row(3), shape.first+": the rounds would hold "+strconv.Itoa(limit+shape.width)+
				" slots, above the limit of "+strconv.Itoa(limit)+" slots")
			if unpackErr != nil {
				t.Fatal(unpackErr)
			}
			if again := mustPack(t, wide, row); again != shape.atLimit {
				t.Fatalf("repack %s want %s", again, shape.atLimit)
			}
			refusedAt(t, refusedUnpack, shape.unpackLeft)
		})
	}
}

func TestAC1TimesChargesTheSameWidthAsRepeat(t *testing.T) {
	// Arrange: u8 n; times(n) { u8 m; when m == 1 { u8 k }; when m == 2 { u8 k } }, width 2 (m, k)
	layout := func(maxSlots int) *Scheme {
		return limited(t, mustScheme(t, 1, U8(0, "n"),
			Times(1, 0, U8(1, "m"), When(2, Eq(1, 1), U8(2, "k")), When(3, Eq(1, 2), U8(3, "k")))),
			func(l *Limits) { l.MaxSlots = maxSlots })
	}

	// Act
	two := mustPack(t, layout(4), map[string]any{"n": 2, "m": []any{1, 2}, "k": []any{7, 8}})

	// Assert
	if two != "01020107"+"0208" {
		t.Fatalf("got %s", two)
	}
	refusedPack(t, layout(4), map[string]any{"n": 3, "m": []any{1, 2, 1}, "k": []any{7, 8, 9}},
		"m: the rounds would hold 6 slots, above the limit of 4 slots")
}

func TestAC1TwoRoundFieldsInOneCallShareOneCounter(t *testing.T) {
	// Arrange: each of the three rounds holds one name
	shared := limited(t, mustScheme(t, 1, U8(0, "n"), Times(1, 0, U8(1, "a")), Repeat(2, U8(2, "b"))),
		func(l *Limits) { l.MaxSlots = 3 })

	// Act
	packs := mustPack(t, shared, map[string]any{"n": 1, "a": []any{1}, "b": []any{2, 3}})

	// Assert
	if packs != "0101010203" {
		t.Fatalf("got %s", packs)
	}
	refusedPack(t, shared, map[string]any{"n": 1, "a": []any{1}, "b": []any{2, 3, 4}},
		"b: the rounds would hold 4 slots, above the limit of 3 slots")
}

func TestAC1ANestedRowInARoundChargesItsOwnMembers(t *testing.T) {
	// Arrange: a Nested row is a scope of its own: a, then x and y inside it, even where it repeats a name
	nested := func(maxSlots int) *Scheme {
		return limited(t, mustScheme(t, 1, Repeat(0, U8(0, "a"), Nested("g", U8(0, "a"), U8(1, "y")))),
			func(l *Limits) { l.MaxSlots = maxSlots })
	}
	row := func(n int) map[string]any {
		return map[string]any{"a": rounds(n, func(i int) any { return i }),
			"g": rounds(n, func(i int) any { return map[string]any{"a": i, "y": i} })}
	}

	// Act
	two := mustPack(t, nested(6), row(2))
	back, err := UnpackMap(mustHex(t, two), nested(6))

	// Assert
	if err != nil || !reflect.DeepEqual(back["a"], []any{uint8(0), uint8(1)}) {
		t.Fatalf("%v, %v", back, err)
	}
	refusedPack(t, nested(6), row(3), "a: the rounds would hold 9 slots, above the limit of 6 slots")
}
