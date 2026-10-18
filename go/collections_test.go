package packbin

import (
	"reflect"
	"strings"
	"testing"
)

func dictOfNumbers(t testing.TB) *Scheme {
	return mustScheme(t, 1, U8(0, "a"), Dict("m", U8(0, "v")))
}

func dictOfDicts(t testing.TB) *Scheme {
	return mustScheme(t, 1, U8(0, "a"), Dict("m", Dict("n", U8(0, "v"))))
}

func dictOfGroups(t testing.TB) *Scheme {
	return mustScheme(t, 1, U8(0, "a"), Dict("m", Nested("p", U8(0, "a"), U8(1, "b"))))
}

const protoWire = "010101000a105f5f70726f746f5f5f010002106109"

// AC-2 (dict-keys-not-flattened): a dict key is a key, never a member of the row, whatever its name.
func TestAC2DictEntriesAreNotMembersOfTheRow(t *testing.T) {
	runPacks(t, []packCase{
		{"a key named like the dictionary keeps its entry", dictOfNumbers, gm("a", 1, "m", gm("m", 9)), "0101010002106d09"},
		{"a key named like the element", dictOfNumbers, gm("a", 1, "m", gm("v", 9)), "0101010002107609"},
		{"nested dictionaries keep to themselves", dictOfDicts, gm("a", 1, "m", gm("x", gm("a", 9))), "01010100021078010002106109"},
		{"a dict of groups beside a member of the same name", dictOfGroups, gm("a", 9, "m", gm("x", gm("a", 1, "b", 2))), "010901000210780102"},
		{"a __proto__ entry packs as an entry", dictOfDicts, gm("a", 1, "m", gm("__proto__", gm("a", 9))), protoWire},
	})
	runRefusals(t, []refusalCase{
		{"a key does not supply a missing member", dictOfNumbers, gm("m", gm("a", 9)), 0, "a", "missing a"},
		{"another key does not either", dictOfNumbers, gm("m", gm("b", 9)), 0, "a", "missing a"},
	})
}

func TestAC2DictInsideAnElementKeepsItsEntriesApart(t *testing.T) {
	inGroup := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, List("xs", Nested("g", U8(0, "a"), Dict("m", Nested("p", U8(0, "a"), U8(1, "b"))))))
	}
	inDict := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, Dict("outer", Nested("g", U8(0, "a"), Dict("m", Nested("p", U8(0, "a"))))))
	}
	runPacks(t, []packCase{
		{"a dict group in a list group", inGroup,
			gm("xs", []any{gm("a", 9, "m", gm("x", gm("a", 1, "b", 2)))}), "0101000901000210780102"},
		{"a dict group in a dict group", inDict,
			gm("outer", gm("k", gm("a", 7, "m", gm("x", gm("a", 1))))), "01010002106b07010002107801"},
	})
	// Arrange
	s := dictOfGroups(t)
	const wire = "010901000210780102"

	// Act
	row := mustUnpackMap(t, s, wire)

	// Assert
	if !reflect.DeepEqual(row, gm("a", uint8(9), "m", gm("x", gm("a", uint8(1), "b", uint8(2))))) {
		t.Fatalf("got %#v", row)
	}
	if again := mustPack(t, s, row); again != wire {
		t.Fatalf("repack %s", again)
	}
}

func TestAC2DecodedProtoEntryRepacksIdentically(t *testing.T) {
	// Act
	row := mustUnpackMap(t, dictOfDicts(t), protoWire)
	entries := row["m"].(map[string]any)

	// Assert
	if _, ok := entries["__proto__"]; !ok || len(entries) != 1 || row["a"] != uint8(1) {
		t.Fatalf("got %#v", row)
	}
	if again := mustPack(t, dictOfDicts(t), row); again != protoWire {
		t.Fatalf("repack %s", again)
	}
}

// AC-2 (dict-non-plain-object): a value that is no map with string keys is no dictionary.
func TestAC2ANonDictionaryIsRefused(t *testing.T) {
	type rowish struct{ A string }
	outside := func(t testing.TB) *Scheme { return mustScheme(t, 1, Dict("d", Utf8(0, "e"))) }
	cases := map[string]any{
		"a slice": []string{"a"}, "an empty slice": []string{}, "a string": "a", "a struct": rowish{"x"},
		"a pointer to a struct": &rowish{"x"}, "a map with int keys": map[int]string{1: "x"}, "a number": 5,
	}
	for name, v := range cases {
		t.Run(name, func(t *testing.T) {
			runRefusals(t, []refusalCase{{name, outside, gm("d", v), -1, "d", "expected a dictionary"}})
		})
	}
	runRefusals(t, []refusalCase{
		{"a nil map is no value", outside, gm("d", map[string]any(nil)), -1, "d", "expected a dictionary, got nil"},
		{"absent", outside, gm(), -1, "d", "expected a dictionary"},
		{"an entry without a value", outside, gm("d", map[string]any{"k": nil}), 0, "d", "no value"},
		{"an entry that is not a string", outside, gm("d", map[string]any{"k": 5}), 0, "e", "expected a string"},
	})
	runPacks(t, []packCase{
		{"a map with string keys of any value type", outside, gm("d", map[string]string{"a": "x"}), "010100021061021078"},
		{"a map with a named key type", outside, gm("d", map[namedString]string{"a": "x"}), "010100021061021078"},
	})
}

func TestDictKeysAreWrittenInByteOrder(t *testing.T) {
	// Arrange
	s := mustScheme(t, 1, Dict("m", U8(0, "v")))
	row := gm("m", map[string]any{"é": 4, "b": 2, "a": 1, "Z": 3, "": 0})

	// Act
	wire := mustPack(t, s, row)

	// Assert
	want := "01" + "0500" + "00" + "00" + "02105a" + "03" + "021061" + "01" + "021062" + "02" + "0310c3a9" + "04"
	if wire != want {
		t.Fatalf("got %s, want %s", wire, want)
	}
}

func TestDictRefusals(t *testing.T) {
	s := mustScheme(t, 1, Dict("m", U8(0, "v")))
	runRefusals(t, []refusalCase{
		{"a key that is not valid UTF-8", func(t testing.TB) *Scheme { return s }, gm("m", map[string]any{"\xff": 1}), -1, "m", "not valid UTF-8"},
		{"an item out of range", func(t testing.TB) *Scheme { return s }, gm("m", map[string]any{"k": 256}), 0, "v", "256 does not fit in u8"},
	})
	huge2 := make(map[string]any, 65536)
	for i := range 65536 {
		huge2[strings.Repeat("k", 1+i/256)+string(rune('a'+i%256))] = 1
	}
	if len(huge2) != 65536 {
		t.Fatalf("test map has %d entries", len(huge2))
	}
	raw, err := Pack(s, gm("m", huge2))
	if e := asError(t, err, PackRefused); raw != nil || !strings.Contains(e.Reason, "length 65536") {
		t.Fatalf("raw %d err %v", len(raw), e)
	}
}

func TestListCounts(t *testing.T) {
	// Arrange
	s := mustScheme(t, 1, List("xs", U8(0, "x")))
	full := make([]any, 65535)
	for i := range full {
		full[i] = 1
	}

	// Act
	packed, err := Pack(s, gm("xs", full))
	_, refused := Pack(s, gm("xs", append(full, 1)))
	back := mustUnpackMap(t, s, hexOf(packed))

	// Assert
	if err != nil || len(packed) != 1+2+65535 || packed[1] != 0xff || packed[2] != 0xff {
		t.Fatalf("packed %d bytes: %v", len(packed), err)
	}
	if e := asError(t, refused, PackRefused); !strings.Contains(e.Reason, "length 65536") || e.Name != "xs" {
		t.Fatalf("refused %v", e)
	}
	if len(back["xs"].([]any)) != 65535 {
		t.Fatalf("items %d", len(back["xs"].([]any)))
	}
}

func TestListItemsOfAnyGoSliceType(t *testing.T) {
	s := mustScheme(t, 1, List("xs", U16(0, "x")))
	runPacks(t, []packCase{
		{"[]any", func(testing.TB) *Scheme { return s }, gm("xs", []any{1, uint16(2)}), "01020001000200"},
		{"[]int", func(testing.TB) *Scheme { return s }, gm("xs", []int{1, 2}), "01020001000200"},
		{"[]uint16", func(testing.TB) *Scheme { return s }, gm("xs", []uint16{1, 2}), "01020001000200"},
		{"pointers", func(testing.TB) *Scheme { return s }, gm("xs", []*int{new(int)}), "010100" + "0000"},
	})
	runRefusals(t, []refusalCase{
		{"not a list", func(testing.TB) *Scheme { return s }, gm("xs", 5), -1, "xs", "expected a list"},
		{"a []byte is a byte run, never a list", func(testing.TB) *Scheme { return s }, gm("xs", []byte{1, 2}), -1, "xs", "expected a list"},
		{"an item out of range", func(testing.TB) *Scheme { return s }, gm("xs", []any{1, 70000}), 0, "x", "70000 does not fit in u16"},
		{"an item that is not an integer", func(testing.TB) *Scheme { return s }, gm("xs", []any{"a"}), 0, "x", "expected an integer"},
		{"a whole float for an integer item (Go-2)", func(testing.TB) *Scheme { return s }, gm("xs", []any{1.0}), 0, "x", "expected an integer"},
	})
}

// A nil slice is no value, an empty slice a value with 0 items (Go-5): under flags the bit is clear
// for the first and set, with a count of 0, for the second.
func TestListNilSliceIsNoValueEmptySliceIsAValue(t *testing.T) {
	s := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, Flags(0, List("xs", U8(0, "x")), Dict("m", U8(0, "v"))))
	}
	runPacks(t, []packCase{
		{"nil slice and nil map", s, gm("xs", []int(nil), "m", map[string]int(nil)), "0100"},
		{"absent", s, gm(), "0100"},
		{"empty slice", s, gm("xs", []int{}), "01010000"},
		{"empty map", s, gm("m", map[string]int{}), "01020000"},
		{"both", s, gm("xs", []int{1}, "m", map[string]int{"a": 2}), "0103" + "0100" + "01" + "0100" + "021061" + "02"},
	})
	back := mustUnpackMap(t, s(t), "01010000")
	if v, ok := back["xs"].([]any); !ok || len(v) != 0 || back["m"] != nil {
		t.Fatalf("got %#v", back)
	}
}

// AC-2 (binding AC-4, fields): a list has no id of its own, restarts the ids inside, and leaves the next
// field readable.
func TestListHasNoIdAndLeavesTheNextFieldReadable(t *testing.T) {
	counted := func(t testing.TB) *Scheme { return mustScheme(t, 0x20, U16(0, "sid"), List("items", U16(0, "id"))) }
	followed := func(t testing.TB) *Scheme { return mustScheme(t, 1, List("xs", U8(0, "n")), U8(0, "y")) }
	empties := func(t testing.TB) *Scheme {
		return mustScheme(t, 1, Utf8(0, "name"), List("xs", Utf8(0, "x")), Dict("d", Utf8(0, "v")))
	}
	runPacks(t, []packCase{
		{"a list of ids", counted, gm("sid", 1, "items", []any{9, 10}), "200100020009000a00"},
		{"a field after the list", followed, gm("xs", []any{1}, "y", 2), "0101000102"},
		{"empty collections", empties, gm("name", "", "xs", []string{}, "d", map[string]string{}), "010000000000"},
	})
	if back := mustUnpackMap(t, followed(t), "0101000102"); !reflect.DeepEqual(back, gm("xs", []any{uint8(1)}, "y", uint8(2))) {
		t.Fatalf("got %#v", back)
	}
	e := buildRefusal(t, U8(0, "n"), List("xs", U8(0, "x")), U8(2, "y"))
	if e.Field != 2 || !strings.Contains(e.Reason, "expected 1, got 2") {
		t.Fatalf("got %+v", e)
	}
	if e := buildRefusal(t, Utf8(0, "s"), When(1, Eq(0, "a"), U8(1, "v"))); !strings.Contains(e.Reason, "not an integer or a bool") {
		t.Fatalf("got %v", e)
	}
}
