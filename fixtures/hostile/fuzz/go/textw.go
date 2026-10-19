package main

import (
	"os"
	"sort"
	"strconv"
	"strings"
)

// A compact text writer built from the frozen code lengths of go/text_tables.go.

// ---------------------------------------------------------------- compact text writer (from the frozen lengths)

type code struct {
	bits uint32
	len  uint8
}

type codes [4][]code

func parseLengths(src, name string) []uint8 {
	i := strings.Index(src, "var "+name+" = [")
	if i < 0 {
		panic(name)
	}
	rest := src[i:]
	open := strings.Index(rest, "{") + 1
	end := strings.Index(rest, "}")
	var out []uint8
	for _, f := range strings.Split(rest[open:end], ",") {
		if v, err := strconv.Atoi(strings.TrimSpace(f)); err == nil {
			out = append(out, uint8(v))
		}
	}
	return out
}

func canonical(lengths []uint8) []code {
	order := make([]int, len(lengths))
	for i := range order {
		order[i] = i
	}
	sort.SliceStable(order, func(a, b int) bool { return lengths[order[a]] < lengths[order[b]] })
	out := make([]code, len(lengths))
	var c uint32
	prev := lengths[order[0]]
	for k, s := range order {
		l := lengths[s]
		if k > 0 {
			c = (c + 1) << (l - prev)
		}
		out[s] = code{c, l}
		prev = l
	}
	return out
}

func loadCodes(checkout string) codes {
	b, err := os.ReadFile(checkout + "/go/text_tables.go")
	if err != nil {
		panic(err)
	}
	var c codes
	for m, name := range []string{"textLengthsUa", "textLengthsRu", "textLengthsEn", "textLengthsNum"} {
		c[m] = canonical(parseLengths(string(b), name))
	}
	return c
}

const (
	ua  = 0
	ru  = 1
	en  = 2
	num = 3
)

var letters = [3]int{34, 33, 27}

func swBase(m int) int {
	if m == num {
		return 15
	}
	return letters[m] + 32
}

func sw(m, target int) int {
	s := swBase(m) + target
	if target > m {
		s--
	}
	return s
}
func capSym(m int) int  { return swBase(m) + 3 }
func lockSym(m int) int { return swBase(m) + 4 }
func escSym(m int) int {
	if m == num {
		return 18
	}
	return swBase(m) + 5
}
func shared(m, k int) int { return letters[m] + k }

type bitWriter struct {
	c *codes
	v []byte
	n int
}

func newBits(c *codes, start int) *bitWriter {
	b := &bitWriter{c: c}
	b.raw(0, 3)
	b.raw(uint32(start), 3)
	return b
}

func (b *bitWriter) raw(c uint32, l uint8) {
	for i := int(l) - 1; i >= 0; i-- {
		if b.n%8 == 0 {
			b.v = append(b.v, 0)
		}
		if (c>>uint(i))&1 == 1 {
			b.v[b.n/8] |= 0x80 >> uint(b.n%8)
		}
		b.n++
	}
}

func (b *bitWriter) sym(m, idx int) { c := b.c[m][idx]; b.raw(c.bits, c.len) }
func (b *bitWriter) byte8(x byte)   { b.raw(uint32(x), 8) }
func (b *bitWriter) finish() []byte {
	pad := (8 - b.n%8) % 8
	b.v[0] |= byte(pad) << 5
	return b.v
}
