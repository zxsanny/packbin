package packbin

import "sort"

// The compact text format (contract compact-text 1.0.0): the four modes, their symbols and their
// canonical prefix codes, built once from the frozen lengths of text_tables.go.

const (
	modeUa  = 0
	modeRu  = 1
	modeEn  = 2
	modeNum = 3

	// tableChars bounds the letter lookups: every letter of the three alphabets is below U+0500.
	tableChars = 0x500
	// maxCodeLen is the longest code of any table; every table is a complete code.
	maxCodeLen = 16
	// rawPrefix is the first payload byte of a raw UTF-8 payload: pad 0, mode 4, two zero bits.
	rawPrefix = 0x10
	// maxTextBytes is the most UTF-8 bytes of one string.
	maxTextBytes = 65535
)

// textMode is one mode: its letters and shared characters, the positions of its control symbols, the
// code of each symbol, and the canonical decoder.
type textMode struct {
	letters  []rune
	upper    []rune // the capital of each letter, 0 for none
	chars    []rune // the shared characters (modes 0 to 2) or the number characters (mode 3)
	charAt   int    // symbol index of the first character
	switchAt int    // symbol index of the first switch; the three switches go to the other modes in order
	capAt    int    // -1 in the number mode
	lockAt   int    // -1 in the number mode
	escAt    int

	length []uint8
	code   []uint16

	// Canonical decoder: for a code length l, first[l] is the first code of that length, count[l] how
	// many codes it has and base[l] the position of the first of them in sorted.
	first  [maxCodeLen + 1]uint16
	count  [maxCodeLen + 1]uint16
	base   [maxCodeLen + 1]uint16
	sorted []uint8

	// lower and capital map a letter to its symbol index, or -1; character does it for the shared or
	// number characters of ASCII.
	lower     [tableChars]int8
	capital   [tableChars]int8
	character [128]int8
}

var textModes = buildTextModes()

func buildTextModes() [4]*textMode {
	var modes [4]*textMode
	letters := [3][]rune{textUa[:], textRu[:], textEn[:]}
	uppers := [3][]rune{textUaUpper[:], textRuUpper[:], textEnUpper[:]}
	lengths := [4][]uint8{textLengthsUa[:], textLengthsRu[:], textLengthsEn[:], textLengthsNum[:]}
	for m := range modes {
		t := &textMode{length: lengths[m]}
		if m == modeNum {
			t.chars = textNumset[:]
			t.charAt = 0
			t.switchAt = len(t.chars)
			t.capAt, t.lockAt = -1, -1
			t.escAt = t.switchAt + 3
		} else {
			t.letters, t.upper, t.chars = letters[m], uppers[m], textShared[:]
			t.charAt = len(t.letters)
			t.switchAt = t.charAt + len(t.chars)
			t.capAt = t.switchAt + 3
			t.lockAt = t.capAt + 1
			t.escAt = t.lockAt + 1
		}
		t.buildCodes()
		t.buildLookups()
		modes[m] = t
	}
	return modes
}

// buildCodes assigns the canonical codes: symbols sorted by (length, index), the first all zero, the
// next one the previous plus 1 shifted by the growth in length.
func (t *textMode) buildCodes() {
	n := len(t.length)
	t.sorted = make([]uint8, n)
	for i := range t.sorted {
		t.sorted[i] = uint8(i)
	}
	sort.SliceStable(t.sorted, func(a, b int) bool { return t.length[t.sorted[a]] < t.length[t.sorted[b]] })
	t.code = make([]uint16, n)
	code, prev := 0, 0
	for k, sym := range t.sorted {
		l := int(t.length[sym])
		code <<= l - prev
		if t.count[l] == 0 {
			t.first[l] = uint16(code)
			t.base[l] = uint16(k)
		}
		t.count[l]++
		t.code[sym] = uint16(code)
		code++
		prev = l
	}
}

func (t *textMode) buildLookups() {
	for i := range t.lower {
		t.lower[i], t.capital[i] = -1, -1
	}
	for i := range t.character {
		t.character[i] = -1
	}
	for i, r := range t.letters {
		t.lower[r] = int8(i)
		if t.upper[i] != 0 {
			t.capital[t.upper[i]] = int8(i)
		}
	}
	for i, r := range t.chars {
		t.character[r] = int8(i)
	}
}
