package main

import (
	"bytes"
	"fmt"
	"runtime"
	"time"

	pb "github.com/zxsanny/packbin/go"
)

// (a) seeded random and mutated inputs.

// ---------------------------------------------------------------- (a) random

type tally struct {
	calls, ok, refused, panics, violations int
	slowest                                time.Duration
	slowestInput                           string
}

func (t *tally) record(panicked, ok bool, dt time.Duration, input []byte) {
	t.calls++
	switch {
	case panicked:
		t.panics++
	case ok:
		t.ok++
	default:
		t.refused++
	}
	if dt > t.slowest {
		t.slowest, t.slowestInput = dt, head(input)
	}
	if dt > time.Second {
		t.violations++
		fmt.Printf("VIOLATION over 1 s: %v for %s\n", dt, head(input))
	}
}

func (t *tally) violation(format string, args ...any) {
	t.violations++
	fmt.Printf("VIOLATION: "+format+"\n", args...)
}

func (t *tally) print(name string) {
	fmt.Printf("%-22s calls %8d  accepted %8d  refused %8d  panics %d  violations %d  slowest %.1f us (%s)\n",
		name, t.calls, t.ok, t.refused, t.panics, t.violations, float64(t.slowest.Nanoseconds())/1e3, t.slowestInput)
}

func payloadLen(f []byte) int {
	used := 0
	for used < len(f) && f[used]&0x80 != 0 {
		used++
	}
	return len(f) - min(used+1, len(f))
}

func random(checkout string, seed uint64, calls int) bool {
	s := loadSeeds(checkout)
	r := &rng{seed}
	fmt.Printf("random: seed %#x, calls per target %d, %s\n", seed, calls, runtime.Version())
	textPool := append(append([][]byte{}, s.text...), s.corpus...)
	var all []*tally

	ts := &tally{}
	for range calls {
		var f []byte
		if r.below(10) == 0 {
			f = r.fill(r.below(64))
		} else {
			f = clone(s.text[r.below(len(s.text))])
		}
		f = mutate(r, f, textPool)
		packet := append([]byte{1}, f...)
		var row map[string]any
		var err error
		p, dt := guarded(func() { row, err = pb.UnpackMap(packet, sScheme) })
		if !p && err == nil {
			text, _ := row["s"].(string)
			n := payloadLen(f)
			if len(text) > 65535 || len(text) > 6*n+8 {
				ts.violation("decoded %d bytes from a %d-byte payload: %s", len(text), n, head(f))
			}
		}
		ts.record(p, err == nil, dt, packet)
	}
	ts.print("text lone string")
	all = append(all, ts)

	tl, td := &tally{}, &tally{}
	for i := range calls {
		items := 1 + r.below(4)
		var body []byte
		for range items {
			f := clone(s.text[r.below(len(s.text))])
			if r.below(2) == 0 {
				f = mutate(r, f, textPool)
			}
			body = append(body, f...)
			if i%2 == 1 {
				body = append(body, r.byte())
			}
		}
		count := items
		if r.below(8) == 0 {
			count = r.below(65536)
		}
		packet := append([]byte{1, byte(count), byte(count >> 8)}, body...)
		if r.below(4) == 0 {
			packet = mutate(r, packet, textPool)
		}
		var err error
		if i%2 == 0 {
			p, dt := guarded(func() { _, err = pb.UnpackMap(packet, lScheme) })
			tl.record(p, err == nil, dt, packet)
		} else {
			p, dt := guarded(func() { _, err = pb.UnpackMap(packet, dScheme) })
			td.record(p, err == nil, dt, packet)
		}
	}
	tl.print("text list")
	td.print("text dict")
	all = append(all, tl, td)

	er := &tally{}
	for range calls {
		n := 1 + r.below(32)
		t := r.below(n/2 + 1)
		l := r.below(255)
		if r.below(16) == 0 {
			l = 255 + r.below(64)
		}
		var buf []byte
		switch r.below(4) {
		case 0:
			buf = make([]byte, l)
		case 1:
			buf = bytes.Repeat([]byte{0xff}, l)
		default:
			buf = r.fill(l)
		}
		before := clone(buf)
		var clear []byte
		var rep int
		var err error
		p, dt := guarded(func() { clear, rep, err = repairBytes(buf, n, t) })
		if !bytes.Equal(buf, before) {
			er.violation("input written: %s", head(before))
		}
		if !p && err == nil {
			again := protect(clear, n)
			if rep > t || len(again) != len(buf) || hamming(again, buf) != rep {
				er.violation("repair not a code word within t: n %d t %d rep %d %s", n, t, rep, head(buf))
			}
		}
		er.record(p, err == nil, dt, buf)
	}
	er.print("ecc random buffers")
	all = append(all, er)

	ec := &tally{}
	for range calls {
		n := 1 + r.below(32)
		t := r.below(n/2 + 1)
		clear := r.fill(1 + r.below(254-n))
		clear[0] = 1
		sent := protect(clear, n)
		k := r.below(n + 1)
		word := clone(sent)
		corrupt(word, k, r)
		var got []byte
		var rep int
		var err error
		p, dt := guarded(func() { got, rep, err = repairTyped(word, n, t, 1) })
		if !p {
			switch {
			case err == nil && k <= t && (!bytes.Equal(got, clear) || rep != k):
				ec.violation("k %d <= t %d repaired wrong: n %d", k, t, n)
			case err == nil && k > t && k <= n-t:
				ec.violation("k %d in t+1..n-t accepted: n %d t %d", k, n, t)
			case err != nil && k <= t:
				ec.violation("k %d <= t %d refused: n %d len %d: %v", k, t, n, len(word), err)
			}
		}
		ec.record(p, err == nil, dt, word)
	}
	ec.print("ecc code words + k")
	all = append(all, ec)

	ev := &tally{}
	var eccPool [][]byte
	for _, e := range s.ecc {
		eccPool = append(eccPool, e.buf)
	}
	for range calls {
		e := s.ecc[r.below(len(s.ecc))]
		n := max(e.n, 1)
		t := r.below(n/2 + 1)
		buf := mutate(r, clone(e.buf), eccPool)
		var err error
		p, dt := guarded(func() { _, _, err = repairBytes(buf, n, t) })
		ev.record(p, err == nil, dt, buf)
	}
	ev.print("ecc vector seeds")
	all = append(all, ev)

	ep := &tally{}
	for range calls {
		n := 1 + r.below(32)
		t := r.below(n/2 + 1)
		f := clone(s.text[r.below(len(s.text))])
		if r.below(2) == 0 {
			f = mutate(r, f, textPool)
		}
		if len(f)+1 > 254-n {
			continue
		}
		word := protect(append([]byte{1}, f...), n)
		k := r.below(t + 2)
		corrupt(word, k, r)
		scheme := must(sScheme.WithParity(n))
		var err error
		p, dt := guarded(func() { _, _, err = pb.UnpackMapRepair(word, t, scheme) })
		if !p && k <= t {
			_, direct := readText(f)
			if (err == nil) != (direct == nil) {
				ep.violation("protected read %v vs clear read %v", err, direct)
			}
		}
		ep.record(p, err == nil, dt, word)
	}
	ep.print("text in protected msg")
	all = append(all, ep)

	reportUsage("random")
	for _, t := range all {
		if t.panics > 0 || t.violations > 0 {
			return false
		}
	}
	return true
}
