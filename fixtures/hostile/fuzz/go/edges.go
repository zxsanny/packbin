package main

import (
	"bytes"
	"errors"
	"fmt"
	"runtime"
	"strings"
	"time"

	pb "github.com/zxsanny/packbin/go"
)

// (d) the AC-1 / AC-2 edge cases.

// ---------------------------------------------------------------- (d) edges

type edgeRun struct{ rows, fails int }

func (e *edgeRun) check(name string, expectOK *bool, limit time.Duration, f func() (string, error)) {
	e.rows++
	var out string
	var err error
	p, dt := guarded(func() { out, err = f() })
	got, pass := "", true
	switch {
	case p:
		got, pass = "PANIC", false
	case err == nil:
		got, pass = "ok "+out, expectOK == nil || *expectOK
	default:
		got, pass = "refused "+err.Error(), expectOK == nil || !*expectOK
	}
	if dt > limit {
		pass = false
	}
	if !pass {
		e.fails++
	}
	status := "PASS"
	if !pass {
		status = "FAIL"
	}
	fmt.Printf("%s %-58s %9.1f us  %s\n", status, name, float64(dt.Nanoseconds())/1e3, got[:min(len(got), 120)])
}

var (
	yes = func() *bool { b := true; return &b }()
	no  = func() *bool { b := false; return &b }()
)

func (e *edgeRun) text(name string, expect *bool, payload []byte) {
	f := field(payload)
	e.check(name, expect, time.Second, func() (string, error) {
		s, err := readText(f)
		return fmt.Sprintf("%d bytes", len(s)), err
	})
}

func edges(checkout string) bool {
	c := loadCodes(checkout)
	e := &edgeRun{}
	fmt.Printf("edges: %s\n", runtime.Version())

	// ---- AC-1 text
	raw := append([]byte{0x10}, bytes.Repeat([]byte{'a'}, 65535)...)
	e.text("raw 65,535 bytes", yes, raw)
	raw = append(raw, 'a')
	e.text("raw 65,536 bytes (length)", no, raw)
	raw[len(raw)-1] = 0xff
	e.text("raw 65,536 bytes, last invalid (length/utf8)", no, raw)
	for _, bc := range []struct {
		name string
		b    []byte
	}{
		{"raw bad continuation c3 28", []byte{0xc3, 0x28}},
		{"raw overlong c0 80", []byte{0xc0, 0x80}},
		{"raw surrogate ed a0 80", []byte{0xed, 0xa0, 0x80}},
		{"raw above U+10FFFF f4 90 80 80", []byte{0xf4, 0x90, 0x80, 0x80}},
		{"raw cut lead e2 82", []byte{0xe2, 0x82}},
	} {
		e.text(bc.name, no, append([]byte{0x10}, bc.b...))
	}
	e.text("raw prefix alone (empty raw text)", yes, []byte{0x10})
	for _, first := range []byte{0x11, 0x12, 0x13, 0x30, 0xf0} {
		e.text(fmt.Sprintf("mode 4 with first byte %02x (raw)", first), no, []byte{first, 0x61})
	}
	for mode := byte(5); mode < 8; mode++ {
		e.text(fmt.Sprintf("start mode %d (mode)", mode), no, []byte{mode << 2, 0})
	}
	e.text("1-byte payload pad 2 (empty text)", yes, []byte{0x40})
	e.text("1-byte payload pad 3 (pad: total 5)", no, []byte{0x60})
	e.text("1-byte payload pad 7 (pad)", no, []byte{0xe0})
	e.text("pad bit set (pad)", no, []byte{0x41})
	{
		b := newBits(&c, ua)
		b.raw(0x3ff, 10)
		e.text("2-byte payload pad 0, 10 symbol bits, cut code", no, b.finish())
	}
	maxP := maxTextPayload(&c)
	e.text(fmt.Sprintf("compact 65,535 bytes (%d-byte payload)", len(maxP)), yes, maxP)
	{
		b := newBits(&c, ru)
		for range 32768 {
			b.sym(ru, 15)
		}
		e.text("compact 65,536 bytes (length)", no, b.finish())
	}
	{
		b := newBits(&c, ru)
		for range 32767 {
			b.sym(ru, 15)
		}
		b.sym(ru, escSym(ru))
		for _, x := range []byte{0xf0, 0x9f, 0x98, 0x80} {
			b.byte8(x)
		}
		e.text("compact 65,534 + ESC 4-byte char (length)", no, b.finish())
	}
	e.check("expansion: о x 1..4000, О under LOCK, <= 6N+8 (batch)", yes, 120*time.Second, func() (string, error) {
		worst := 0.0
		for k := 1; k < 4000; k++ {
			for _, locked := range []bool{false, true} {
				b := newBits(&c, ru)
				if locked {
					b.sym(ru, lockSym(ru))
				}
				for range k {
					b.sym(ru, 15)
				}
				p := b.finish()
				s, err := readText(field(p))
				if err != nil {
					return "", err
				}
				if len(s) > 6*len(p)+8 {
					return "", fmt.Errorf("%d bytes from %d", len(s), len(p))
				}
				worst = max(worst, float64(len(s))/float64(len(p)))
			}
		}
		return fmt.Sprintf("worst %.3f bytes per payload byte", worst), nil
	})
	e.check("ESC 4-byte char cut at 0..3 bytes, 8 bit offsets (esc)", no, time.Second, func() (string, error) {
		refused := 0
		for shift := range 8 {
			for keep := range 4 {
				b := newBits(&c, ua)
				for range shift {
					b.sym(ua, shared(ua, 0))
				}
				b.sym(ua, escSym(ua))
				for _, x := range []byte{0xf0, 0x9f, 0x98, 0x80}[:keep] {
					b.byte8(x)
				}
				if _, err := readText(field(b.finish())); err != nil {
					refused++
				}
			}
		}
		if refused == 32 {
			return "", errors.New("32 of 32 refused")
		}
		return fmt.Sprintf("%d of 32 refused", refused), nil
	})
	invalid := [][]byte{{0x80}, {0xbf}, {0xc0, 0x80}, {0xc1, 0xbf}, {0xc3, 0x28}, {0xe0, 0x80, 0x80}, {0xe0, 0x9f, 0xbf},
		{0xed, 0xa0, 0x80}, {0xed, 0xbf, 0xbf}, {0xf0, 0x80, 0x80, 0x80}, {0xf4, 0x90, 0x80, 0x80},
		{0xf5, 0x80, 0x80, 0x80}, {0xf8, 0x80, 0x80, 0x80}, {0xff, 0x80, 0x80, 0x80}}
	for _, bad := range invalid {
		for _, shift := range []int{0, 3} {
			b := newBits(&c, en)
			for range shift {
				b.sym(en, shared(en, 0))
			}
			b.sym(en, escSym(en))
			for _, x := range bad {
				b.byte8(x)
			}
			e.text(fmt.Sprintf("ESC %x shift %d (utf8)", bad, shift), no, b.finish())
		}
	}
	for _, g := range []struct {
		name string
		b    []byte
	}{
		{"ESC U+0000", []byte{0}}, {"ESC U+FFFD ef bf bd", []byte{0xef, 0xbf, 0xbd}},
		{"ESC U+10FFFF f4 8f bf bf", []byte{0xf4, 0x8f, 0xbf, 0xbf}}, {"ESC U+D7FF ed 9f bf", []byte{0xed, 0x9f, 0xbf}},
	} {
		b := newBits(&c, num)
		b.sym(num, escSym(num))
		for _, x := range g.b {
			b.byte8(x)
		}
		e.text(g.name, yes, b.finish())
	}
	type sy struct{ m, s int }
	for _, cc := range []struct {
		name string
		syms []sy
	}{
		{"CAP at the end (cap)", []sy{{ua, capSym(ua)}}},
		{"CAP then apostrophe (cap)", []sy{{ua, capSym(ua)}, {ua, 33}}},
		{"CAP CAP (cap)", []sy{{ua, capSym(ua)}, {ua, capSym(ua)}}},
		{"LOCK then CAP (cap)", []sy{{ua, lockSym(ua)}, {ua, capSym(ua)}}},
		{"CAP then LOCK (cap)", []sy{{ua, capSym(ua)}, {ua, lockSym(ua)}}},
		{"CAP then SW (cap)", []sy{{ua, capSym(ua)}, {ua, sw(ua, en)}}},
		{"CAP then shared (cap)", []sy{{ua, capSym(ua)}, {ua, shared(ua, 0)}}},
		{"CAP then ESC (cap)", []sy{{ua, capSym(ua)}, {ua, escSym(ua)}}},
		{"CAP at the end in EN (cap)", []sy{{en, capSym(en)}}},
	} {
		b := newBits(&c, cc.syms[0].m)
		for _, x := range cc.syms {
			b.sym(x.m, x.s)
		}
		if strings.HasPrefix(cc.name, "CAP then ESC") {
			b.byte8('a')
		}
		e.text(cc.name, no, b.finish())
	}
	{
		b := newBits(&c, en)
		b.sym(en, lockSym(en))
		b.sym(en, sw(en, num))
		b.sym(num, sw(num, en))
		b.sym(en, 0)
		e.text("LOCK survives num mode: LOCK, SW num, SW en, a = A", yes, b.finish())
	}
	for _, vc := range []struct {
		name string
		f    []byte
		ok   *bool
	}{
		{"varint 4 bytes (varint)", []byte{0x80, 0x80, 0x80, 0x01, 0x10}, no},
		{"varint non-minimal 80 00 (varint)", []byte{0x80, 0x00}, no},
		{"varint non-minimal ff 80 00 (varint)", []byte{0xff, 0x80, 0x00}, no},
		{"varint cut 80 (short)", []byte{0x80}, no},
		{"count 2,097,151 with 10 bytes (short)", []byte{0xff, 0xff, 0x7f, 0x10, 1, 2, 3, 4, 5, 6, 7, 8, 9}, no},
		{"count 0 (empty)", []byte{0x00}, yes},
	} {
		f := vc.f
		e.check(vc.name, vc.ok, time.Second, func() (string, error) {
			s, err := readText(f)
			return fmt.Sprintf("%d bytes", len(s)), err
		})
	}
	e.text("2,097,151-byte payload of mode switches (empty)", yes, controlsPayload(&c, 2_097_151))
	keyOf := func(start int, f func(b *bitWriter)) []byte {
		b := newBits(&c, start)
		f(b)
		return field(b.finish())
	}
	keyRawA := field([]byte{0x10, 'a'})
	keyEnA := keyOf(en, func(b *bitWriter) { b.sym(en, 0) })
	keyUaA := keyOf(ua, func(b *bitWriter) { b.sym(ua, 0) })
	keyRuA := keyOf(ru, func(b *bitWriter) { b.sym(ru, 0) })
	keyEscA := keyOf(num, func(b *bitWriter) { b.sym(num, escSym(num)); b.byte8('a') })
	for _, dc := range []struct {
		name string
		keys [][]byte
		ok   *bool
	}{
		{"dict keys 'a' raw + 'a' EN code (duplicate)", [][]byte{keyRawA, keyEnA}, no},
		{"dict keys 'a' EN code + 'a' ESC in num (duplicate)", [][]byte{keyEnA, keyEscA}, no},
		{"dict keys 'а' UA + 'а' RU (duplicate)", [][]byte{keyUaA, keyRuA}, no},
		{"dict keys 'a' + 'а' (distinct)", [][]byte{keyEnA, keyUaA}, yes},
	} {
		p := []byte{1, byte(len(dc.keys)), 0}
		for i, k := range dc.keys {
			p = append(append(p, k...), byte(i))
		}
		e.check(dc.name, dc.ok, time.Second, func() (string, error) {
			_, err := pb.UnpackMap(p, dScheme)
			return "", err
		})
	}

	// ---- AC-2 ECC
	e.check("all n 1..32 x N 0..256 x 7 fills x t {0, n/2} (batch)", nil, 120*time.Second, func() (string, error) {
		r := &rng{0xA11}
		calls, repaired, wrong := 0, 0, 0
		for n := 1; n <= 32; n++ {
			for l := 0; l <= 256; l++ {
				fills := [][]byte{make([]byte, l), bytes.Repeat([]byte{0xff}, l), r.fill(l), r.fill(l)}
				if l > n && l <= 254 {
					clear := r.fill(l - n)
					clear[0] = 1
					w := protect(clear, n)
					for _, k := range []int{n / 2, n/2 + 1, n} {
						cw := clone(w)
						corrupt(cw, k, r)
						fills = append(fills, cw)
					}
				}
				for i, buf := range fills {
					before := clone(buf)
					for _, t := range []int{0, n / 2} {
						calls++
						var got []byte
						var rep int
						var err error
						if i >= 4 {
							got, rep, err = repairTyped(buf, n, t, 1)
						} else {
							got, rep, err = repairBytes(buf, n, t)
						}
						var pe *pb.Error
						switch {
						case err == nil:
							if rep > 0 {
								repaired++
							}
							again := protect(got, n)
							if l > 254 || l < n || len(again) != l || hamming(again, buf) != rep {
								wrong++
							}
						case errors.As(err, &pe) && l < n:
							if pe.Kind != pb.ShortPacket || pe.Name != "parity" || pe.Needed != n || pe.Left != l {
								wrong++
							}
						case errors.As(err, &pe) && l > 254:
							if pe.Kind != pb.TooLong {
								wrong++
							}
						}
					}
					if !bytes.Equal(before, buf) {
						wrong++
					}
				}
			}
		}
		if wrong > 0 {
			return "", fmt.Errorf("%d wrong of %d", wrong, calls)
		}
		return fmt.Sprintf("%d calls, %d repairs, 0 wrong, input never written", calls, repaired), nil
	})
	e.check("16 MiB buffer at n 32 (too_long, no arithmetic)", no, time.Second, func() (string, error) {
		_, _, err := repairBytes(make([]byte, 16<<20), 32, 16)
		return "", err
	})
	e.check("empty buffer at n 4 (short naming parity)", no, time.Second, func() (string, error) {
		_, _, err := repairBytes(nil, 4, 2)
		return "", err
	})
	{
		r := &rng{0xB0B}
		clear := r.fill(254 - 32)
		clear[0] = 1
		w := protect(clear, 32)
		seq := func(a, b int) []int {
			var out []int
			for i := a; i < b; i++ {
				out = append(out, i)
			}
			return out
		}
		for _, pc := range []struct {
			name string
			pos  []int
		}{
			{"16 wrong in the parity only, t 16", seq(238, 254)},
			{"wrong first and last byte, t 16", []int{0, 253}},
			{"16-byte burst in the middle, t 16", seq(100, 116)},
			{"type byte wrong, t 1", []int{0}},
		} {
			cw := clone(w)
			for _, p := range pc.pos {
				cw[p] ^= 0x5a
			}
			k := len(pc.pos)
			e.check(pc.name, yes, time.Second, func() (string, error) {
				got, rep, err := repairTyped(cw, 32, 16, 1)
				if err != nil {
					return "", err
				}
				if !bytes.Equal(got, clear) || rep != k {
					return "", fmt.Errorf("wrong repair (%d)", rep)
				}
				return fmt.Sprintf("repaired %d", rep), nil
			})
		}
	}
	e.check("WithParity(33), WithParity(-1) refused", no, time.Second, func() (string, error) {
		_, err1 := sScheme.WithParity(33)
		_, err2 := sScheme.WithParity(-1)
		if err1 == nil || err2 == nil {
			return "accepted", nil
		}
		return "", fmt.Errorf("%v; %v", err1, err2)
	})
	s4 := rawScheme(1, 3, 4)
	s4b := rawScheme(2, 3, 4)
	s2 := rawScheme(2, 3, 2)
	e.check("dispatch: no schemes", no, time.Second, func() (string, error) {
		_, _, err := pb.UnpackMapRepair([]byte{1, 2, 3}, 99)
		return "", err
	})
	e.check("dispatch: nil scheme", no, time.Second, func() (string, error) {
		_, _, err := pb.UnpackMapRepair([]byte{1, 2, 3}, 0, nil)
		return "", err
	})
	e.check("dispatch: duplicate type before mix and limit", no, time.Second, func() (string, error) {
		_, _, err := pb.UnpackMapRepair([]byte{1, 2, 3}, 99, s4, rawScheme(1, 3, 2))
		return "", err
	})
	e.check("dispatch: mixed parity before limit", no, time.Second, func() (string, error) {
		_, _, err := pb.UnpackMapRepair([]byte{1, 2, 3}, 99, s4, s2)
		return "", err
	})
	e.check("dispatch: limit above n/2", no, time.Second, func() (string, error) {
		_, _, err := pb.UnpackMapRepair([]byte{1, 2, 3}, 3, s4)
		return "", err
	})
	e.check("dispatch: unknown type after repair", no, time.Second, func() (string, error) {
		_, _, err := pb.UnpackMapRepair(protect([]byte{7, 1, 2, 3}, 4), 2, s4, s4b)
		return "", err
	})
	e.check("session: check order and receive index", yes, time.Second, sessionOrder)
	reportUsage("edges")
	fmt.Printf("edges: %d rows, %d FAIL\n", e.rows, e.fails)
	return e.fails == 0
}
