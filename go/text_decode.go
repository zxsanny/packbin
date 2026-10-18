package packbin

import "unicode/utf8"

// textRefusal is why a string field was refused; the zero value is none. The kinds are the names of
// the contract; the error a caller sees names the field and carries the shape of a short packet.
type textRefusal uint8

const (
	textOK textRefusal = iota
	textShort
	textVarint
	textBadMode
	textPad
	textCode
	textCap
	textEsc
	textUtf8
	textRaw
	textLength
)

// textRead is the outcome of decoding one field: the refusal (none when it worked), and for a short
// buffer the bytes needed and the bytes left.
type textRead struct {
	kind         textRefusal
	needed, left int
}

// decodeText decodes the string field at buf[off:]. Time and memory follow the payload length: every
// symbol is at least one bit and writes at most 4 UTF-8 bytes, and the text stops growing at 65,535
// UTF-8 bytes. It returns the text and the offset after the field.
func decodeText(buf []byte, off int) (string, int, textRead) {
	left := len(buf) - off
	p, count := off, 0
	for k := 0; ; k++ {
		if k == 3 {
			return "", 0, textRead{kind: textVarint, left: left}
		}
		if p >= len(buf) {
			return "", 0, textRead{kind: textShort, needed: k + 1, left: left}
		}
		b := buf[p]
		p++
		count |= int(b&0x7f) << (7 * k)
		if b&0x80 == 0 {
			if k > 0 && b == 0 {
				return "", 0, textRead{kind: textVarint, left: left}
			}
			break
		}
	}
	if count == 0 {
		return "", p, textRead{}
	}
	if count > len(buf)-p {
		return "", 0, textRead{kind: textShort, needed: count, left: len(buf) - p}
	}
	payload := buf[p : p+count]
	end := p + count
	first := payload[0]
	start := int(first>>2) & 7
	if start == 4 {
		if first != rawPrefix {
			return "", 0, textRead{kind: textRaw, left: left}
		}
		if count-1 > maxTextBytes {
			return "", 0, textRead{kind: textLength, left: left}
		}
		if !utf8.Valid(payload[1:]) {
			return "", 0, textRead{kind: textUtf8, left: left}
		}
		return string(payload[1:]), end, textRead{}
	}
	if start > 4 {
		return "", 0, textRead{kind: textBadMode, left: left}
	}
	pad := int(first >> 5)
	total := 8*count - pad
	if total < 6 || payload[count-1]&(1<<pad-1) != 0 {
		return "", 0, textRead{kind: textPad, left: left}
	}
	var small [128]byte
	text, kind := decodeSymbols(payload, start, total, small[:0])
	if kind != textOK {
		return "", 0, textRead{kind: kind, left: left}
	}
	return string(text), end, textRead{}
}

// window is the 16 bits of payload at bit position pos, zero past the end of the payload.
func window(payload []byte, pos int) uint32 {
	i := pos >> 3
	w := uint32(payload[i]) << 16
	if i+1 < len(payload) {
		w |= uint32(payload[i+1]) << 8
	}
	if i+2 < len(payload) {
		w |= uint32(payload[i+2])
	}
	return w >> (8 - pos&7) & 0xffff
}

// nextSymbol reads the code at bit pos with the canonical decoder: the symbol index and the length.
func (t *textMode) nextSymbol(payload []byte, pos int) (sym, length int) {
	w := window(payload, pos)
	for l := 1; l <= maxCodeLen; l++ {
		if d := w>>(maxCodeLen-l) - uint32(t.first[l]); d < uint32(t.count[l]) {
			return int(t.sorted[uint32(t.base[l])+d]), l
		}
	}
	return 0, maxCodeLen + 1
}

// decodeSymbols reads the symbols of payload from bit 6 to bit total, appending the text to out.
func decodeSymbols(payload []byte, start, total int, out []byte) ([]byte, textRefusal) {
	mode, lock, capital := start, false, false
	for pos := 6; pos < total; {
		t := textModes[mode]
		sym, l := t.nextSymbol(payload, pos)
		pos += l
		if pos > total {
			return nil, textCode
		}
		var r rune
		switch {
		case sym < t.charAt:
			up := t.upper[sym]
			switch {
			case capital:
				if up == 0 {
					return nil, textCap
				}
				r, capital = up, false
			case lock && up != 0:
				r = up
			default:
				r = t.letters[sym]
			}
		case sym < t.switchAt:
			if capital {
				return nil, textCap
			}
			r = t.chars[sym-t.charAt]
		case sym < t.switchAt+3:
			if capital {
				return nil, textCap
			}
			if to := sym - t.switchAt; to < mode {
				mode = to
			} else {
				mode = to + 1
			}
			continue
		case sym == t.capAt:
			if lock || capital {
				return nil, textCap
			}
			capital = true
			continue
		case sym == t.lockAt:
			if capital {
				return nil, textCap
			}
			lock = !lock
			continue
		default:
			if capital {
				return nil, textCap
			}
			if pos+8 > total {
				return nil, textEsc
			}
			b0 := bitsByte(payload, pos)
			n := 0
			switch {
			case b0 < 0x80:
				n = 1
			case b0>>5 == 6:
				n = 2
			case b0>>4 == 14:
				n = 3
			case b0>>3 == 30:
				n = 4
			default:
				return nil, textUtf8
			}
			if pos+8*n > total {
				return nil, textEsc
			}
			var raw [4]byte
			for j := 0; j < n; j++ {
				raw[j] = bitsByte(payload, pos+8*j)
			}
			if c, size := utf8.DecodeRune(raw[:n]); c == utf8.RuneError && size <= 1 {
				return nil, textUtf8
			}
			pos += 8 * n
			if len(out)+n > maxTextBytes {
				return nil, textLength
			}
			out = append(out, raw[:n]...)
			continue
		}
		if len(out)+runeLen(r) > maxTextBytes {
			return nil, textLength
		}
		out = utf8.AppendRune(out, r)
	}
	if capital {
		return nil, textCap
	}
	return out, textOK
}

// bitsByte is the 8 bits of payload at bit position pos (the caller checked they exist).
func bitsByte(payload []byte, pos int) byte {
	i, shift := pos>>3, pos&7
	if shift == 0 {
		return payload[i]
	}
	return payload[i]<<shift | payload[i+1]>>(8-shift)
}
