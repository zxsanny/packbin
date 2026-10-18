package packbin

import "unicode/utf8"

// The encoder: the optimal parse of a text over the states (mode, capital lock), found by dynamic
// programming from the end, then written forward. Ties go to the smallest first-symbol index at every
// step, and the start mode to the smaller mode number, so every package writes the same bytes.

// textInf is larger than the bits of any text (at most 65,535 characters of 28 bits each).
const textInf = 1 << 30

// textEdge is one way to consume a character in a state: the first symbol, the bits of everything it
// writes, the second symbol (-1 for none) and the UTF-8 length written after an ESC (0 for none).
type textEdge struct {
	first, second int
	bits          int32
	esc           int
}

// textControl is an edge that consumes no character: the symbol, its bits and the state it leads to.
type textControl struct {
	sym    int
	bits   int32
	target int
}

// textControls[state] lists the switches to the other modes and the lock toggle, by symbol index.
var textControls = buildTextControls()

func buildTextControls() (out [8][]textControl) {
	for st := range out {
		m, k := st>>1, st&1
		t := textModes[m]
		for to := 0; to < 4; to++ {
			if to != m {
				sym := t.switchAt + to
				if to > m {
					sym--
				}
				out[st] = append(out[st], textControl{sym, int32(t.length[sym]), to*2 + k})
			}
		}
		if m != modeNum {
			out[st] = append(out[st], textControl{t.lockAt, int32(t.length[t.lockAt]), m*2 + 1 - k})
		}
	}
	return out
}

func runeLen(r rune) int {
	switch {
	case r < 0x80:
		return 1
	case r < 0x800:
		return 2
	case r < 0x10000:
		return 3
	}
	return 4
}

// edges fills out with the edges of c in this mode with capital lock `lock` and returns how many.
func (t *textMode) edges(c rune, lock int, out *[2]textEdge) int {
	n := 0
	if c < tableChars {
		if i := int(t.lower[c]); i >= 0 {
			if lock == 0 || t.upper[i] == 0 {
				out[n] = textEdge{first: i, second: -1, bits: int32(t.length[i])}
				n++
			}
		} else if i := int(t.capital[c]); i >= 0 {
			if lock == 1 {
				out[n] = textEdge{first: i, second: -1, bits: int32(t.length[i])}
			} else {
				out[n] = textEdge{first: t.capAt, second: i, bits: int32(t.length[t.capAt]) + int32(t.length[i])}
			}
			n++
		} else if c < 128 && t.character[c] >= 0 {
			i := t.charAt + int(t.character[c])
			out[n] = textEdge{first: i, second: -1, bits: int32(t.length[i])}
			n++
		}
	}
	e := runeLen(c)
	out[n] = textEdge{first: t.escAt, second: -1, bits: int32(t.length[t.escAt]) + int32(8*e), esc: e}
	return n + 1
}

// textPlan is the decision for one text: the start mode and the size of the payload.
type textPlan struct {
	chars   int
	start   int
	bits    int  // the symbol bits plus the 6 bits of the prefix
	payload int  // payload bytes of the compact form
	raw     bool // the raw form is not larger
	rawLen  int  // payload bytes of the raw form
}

// planText runs the dynamic program for s (valid UTF-8, at most 65,535 bytes, not empty). costs is
// scratch for (chars+1)*8 values; it is returned, grown if it was too small, and holds f(i, state).
func planText(s string, costs []int32) (textPlan, []int32) {
	n := utf8.RuneCountInString(s)
	if need := (n + 1) * 8; len(costs) < need {
		costs = make([]int32, need)
	}
	f := costs[:(n+1)*8]
	for st := 0; st < 8; st++ {
		f[n*8+st] = 0
	}
	var es [2]textEdge
	end := len(s)
	for i := n - 1; i >= 0; i-- {
		c, size := utf8.DecodeLastRuneInString(s[:end])
		end -= size
		cur, next := f[i*8:i*8+8], f[i*8+8:i*8+16]
		for st := 0; st < 8; st++ {
			ne := textModes[st>>1].edges(c, st&1, &es)
			best := int32(textInf)
			for e := 0; e < ne; e++ {
				if v := es[e].bits + next[st]; v < best {
					best = v
				}
			}
			cur[st] = best
		}
		for changed := true; changed; {
			changed = false
			for st := 0; st < 8; st++ {
				for _, ct := range textControls[st] {
					if v := ct.bits + cur[ct.target]; v < cur[st] {
						cur[st] = v
						changed = true
					}
				}
			}
		}
	}
	start := 0
	for m := 1; m < 4; m++ {
		if f[m*2] < f[start*2] {
			start = m
		}
	}
	bits := 6 + int(f[start*2])
	plan := textPlan{chars: n, start: start, bits: bits, payload: (bits + 7) / 8, rawLen: 1 + len(s)}
	plan.raw = plan.payload >= plan.rawLen
	return plan, f
}

func varintLen(n int) int {
	switch {
	case n < 0x80:
		return 1
	case n < 0x4000:
		return 2
	}
	return 3
}

func appendVarint(dst []byte, n int) []byte {
	for n >= 0x80 {
		dst = append(dst, byte(n)|0x80)
		n >>= 7
	}
	return append(dst, byte(n))
}

// size is the bytes of the field: the count, then the payload.
func (p textPlan) size() int {
	if p.raw {
		return varintLen(p.rawLen) + p.rawLen
	}
	return varintLen(p.payload) + p.payload
}

// bitWriter appends codes to a byte slice, most significant bit first.
type bitWriter struct {
	out  []byte
	acc  uint32
	bits int
}

func (w *bitWriter) put(code uint32, n int) {
	w.acc = w.acc<<n | code
	w.bits += n
	for w.bits >= 8 {
		w.out = append(w.out, byte(w.acc>>(w.bits-8)))
		w.bits -= 8
	}
	w.acc &= 1<<w.bits - 1
}

func (w *bitWriter) putSymbol(t *textMode, sym int) { w.put(uint32(t.code[sym]), int(t.length[sym])) }

// appendTextField appends the field of s as plan decided it, from the costs planText left in f.
func appendTextField(dst []byte, s string, plan textPlan, f []int32) []byte {
	if plan.raw {
		dst = appendVarint(dst, plan.rawLen)
		dst = append(dst, rawPrefix)
		return append(dst, s...)
	}
	w := bitWriter{out: appendVarint(dst, plan.payload)}
	w.put(uint32(8*plan.payload-plan.bits), 3)
	w.put(uint32(plan.start), 3)
	state, pos := plan.start*2, 0
	var es [2]textEdge
	for i := 0; i < plan.chars; {
		c, size := utf8.DecodeRuneInString(s[pos:])
		want := f[i*8+state]
		bestFirst, bestControl, bestEdge := textInf, -1, -1
		for j, ct := range textControls[state] {
			if ct.sym < bestFirst && ct.bits+f[i*8+ct.target] == want {
				bestFirst, bestControl = ct.sym, j
			}
		}
		t := textModes[state>>1]
		ne := t.edges(c, state&1, &es)
		for e := 0; e < ne; e++ {
			if es[e].first < bestFirst && es[e].bits+f[i*8+8+state] == want {
				bestFirst, bestControl, bestEdge = es[e].first, -1, e
			}
		}
		w.putSymbol(t, bestFirst)
		if bestControl >= 0 {
			state = textControls[state][bestControl].target
			continue
		}
		edge := es[bestEdge]
		if edge.second >= 0 {
			w.putSymbol(t, edge.second)
		}
		if edge.esc > 0 {
			for j := 0; j < size; j++ {
				w.put(uint32(s[pos+j]), 8)
			}
		}
		pos += size
		i++
	}
	if w.bits > 0 {
		w.out = append(w.out, byte(w.acc<<(8-w.bits)))
	}
	return w.out
}
