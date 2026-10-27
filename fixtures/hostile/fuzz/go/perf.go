package main

import (
	"bytes"
	"fmt"
	"runtime"
	"sort"
	"testing"
	"time"

	pb "github.com/zxsanny/packbin/go"
)

// (b) ECC repair time and allocations, (c) text amplification.

// ---------------------------------------------------------------- (b) ecc time

func ecctime(calls int) bool {
	const n = 32
	r := &rng{0xECC71E}
	words := make([][]byte, 64)
	for i := range words {
		clear := r.fill(254 - n)
		clear[0] = 1
		words[i] = protect(clear, n)
	}
	scheme := bScheme(1, 254-n, n)
	fmt.Printf("ecctime: n %d, N 254, %d calls per case, %s, GOMAXPROCS %d\n", n, calls, runtime.Version(), runtime.GOMAXPROCS(0))
	wrongK := func(k int) func(*rng, []byte) []byte {
		return func(r *rng, w []byte) []byte { v := clone(w); corrupt(v, k, r); return v }
	}
	cases := []struct {
		name string
		t    int
		make func(*rng, []byte) []byte
	}{
		{"intact, t=0 (default)", 0, func(_ *rng, w []byte) []byte { return clone(w) }},
		{"intact, t=16", 16, func(_ *rng, w []byte) []byte { return clone(w) }},
		{"1 wrong, t=0 (default)", 0, wrongK(1)},
		{"16 wrong, t=0 (default)", 0, wrongK(16)},
		{"8 wrong, t=16", 16, wrongK(8)},
		{"16 wrong, t=16 (max repair)", 16, wrongK(16)},
		{"16 wrong at the end, t=16", 16, func(r *rng, w []byte) []byte {
			v := clone(w)
			for p := len(v) - 16; p < len(v); p++ {
				v[p] ^= r.byte() | 1
			}
			return v
		}},
		{"16 wrong at the start, t=16", 16, func(r *rng, w []byte) []byte {
			v := clone(w)
			for p := range 16 {
				v[p] ^= r.byte() | 1
			}
			return v
		}},
		{"17 wrong, t=16", 16, wrongK(17)},
		{"32 wrong, t=16", 16, wrongK(32)},
		{"random 254 bytes, t=16", 16, func(r *rng, _ []byte) []byte { return r.fill(254) }},
		{"all 0xff, t=16", 16, func(_ *rng, _ []byte) []byte { return bytes.Repeat([]byte{0xff}, 254) }},
	}
	ok := true
	for _, c := range cases {
		inputs := make([][]byte, 64)
		for i := range inputs {
			inputs[i] = c.make(r, words[i])
		}
		times := make([]int64, calls)
		accepted, refused := 0, 0
		for i := range calls {
			in := inputs[i%64]
			var err error
			p, dt := guarded(func() { _, _, err = pb.UnpackMapRepair(in, c.t, scheme) })
			times[i] = dt.Nanoseconds()
			switch {
			case p:
				ok = false
			case err == nil:
				accepted++
			default:
				refused++
			}
		}
		sort.Slice(times, func(a, b int) bool { return times[a] < times[b] })
		med, p99, mx := times[calls/2], times[calls*99/100], times[calls-1]
		fmt.Printf("%-30s accepted %6d refused %6d  median %7.1f us  p99 %7.1f us  max %8.1f us\n",
			c.name, accepted, refused, float64(med)/1e3, float64(p99)/1e3, float64(mx)/1e3)
		if mx > int64(time.Second) {
			ok = false
		}
	}
	big := make([]byte, 16<<20)
	start := time.Now()
	_, _, err := pb.UnpackMapRepair(big, 16, scheme)
	fmt.Printf("16 MiB buffer, n 32: %v in %.1f us\n", err, float64(time.Since(start).Nanoseconds())/1e3)
	reportUsage("ecctime")
	return ok
}

// allocs reports allocations per call on the ECC paths (testing.AllocsPerRun, MemStats bytes).
func allocs() bool {
	r := &rng{0xA110C}
	fmt.Printf("allocs: %s\n", runtime.Version())
	for _, n := range []int{4, 16, 32} {
		clear := r.fill(254 - n)
		clear[0] = 1
		word := protect(clear, n)
		scheme := bScheme(1, 254-n, n)
		bad1 := clone(word)
		corrupt(bad1, 1, r)
		badT := clone(word)
		corrupt(badT, n/2, r)
		garbage := r.fill(254)
		for _, c := range []struct {
			name string
			buf  []byte
			t    int
		}{
			{"intact", word, n / 2},
			{"1 wrong, t=0", bad1, 0},
			{"n/2 wrong, t=n/2", badT, n / 2},
			{"random bytes, t=n/2", garbage, n / 2},
		} {
			var ms0, ms1 runtime.MemStats
			runtime.GC()
			runtime.ReadMemStats(&ms0)
			a := testing.AllocsPerRun(200, func() { _, _, _ = pb.UnpackMapRepair(c.buf, c.t, scheme) })
			runtime.ReadMemStats(&ms1)
			fmt.Printf("n %2d %-22s %5.0f allocs/call  %7.0f bytes/call (whole unpack, row map included)\n",
				n, c.name, a, float64(ms1.TotalAlloc-ms0.TotalAlloc)/201)
		}
	}
	reportUsage("allocs")
	return true
}

// ---------------------------------------------------------------- (c) text amplification

func maxTextPayload(c *codes) []byte {
	b := newBits(c, ru)
	for range 32767 {
		b.sym(ru, 15)
	}
	b.sym(ru, shared(ru, 0))
	return b.finish()
}

func controlsPayload(c *codes, size int) []byte {
	b := newBits(c, ua)
	pair := int(c[ua][sw(ua, num)].len) + int(c[num][sw(num, ua)].len)
	for b.n+pair <= size*8 {
		b.sym(ua, sw(ua, num))
		b.sym(num, sw(num, ua))
	}
	v := b.finish()
	return v[:min(len(v), size)]
}

func textamp(checkout, which string) bool {
	c := loadCodes(checkout)
	_, rss0 := usage()
	var packet []byte
	var scheme *pb.Scheme
	reps := 3
	label := ""
	switch which {
	case "one":
		p := maxTextPayload(&c)
		packet, scheme, reps = append([]byte{1}, field(p)...), sScheme, 200
		label = fmt.Sprintf("one compact text, payload %d bytes", len(p))
	case "list1m", "list8m":
		p := field(maxTextPayload(&c))
		size := 1 << 20
		if which == "list8m" {
			size = 8 << 20
		}
		k := (size - 3) / len(p)
		packet = []byte{1, byte(k), byte(k >> 8)}
		for range k {
			packet = append(packet, p...)
		}
		scheme, label = lScheme, fmt.Sprintf("list of %d max texts", k)
	case "controls":
		p := controlsPayload(&c, 2_097_151)
		packet, scheme, reps = append([]byte{1}, field(p)...), sScheme, 5
		label = "one 2,097,151-byte payload of mode switches"
	case "short":
		b := newBits(&c, ru)
		for range 3 {
			b.sym(ru, 15)
		}
		f := field(b.finish())
		packet = []byte{1, 0xff, 0xff}
		for range 65535 {
			packet = append(packet, f...)
		}
		scheme, label = lScheme, fmt.Sprintf("list of 65,535 fields %x", f)
	case "dictpre":
		// A dict count of 65,535 over 65,535 bytes of 00: the second empty key is a duplicate.
		packet = append([]byte{1, 0xff, 0xff}, make([]byte, 65535)...)
		scheme, reps, label = dScheme, 50, "dict count 65,535, keys \"\" then a duplicate"
	default:
		panic("textamp case: one | list1m | list8m | controls | short | dictpre")
	}
	runtime.GC()
	cpu1, rss1 := usage()
	var ms0, ms1 runtime.MemStats
	runtime.ReadMemStats(&ms0)
	var row map[string]any
	var err error
	start := time.Now()
	for range reps {
		row = nil
		row, err = pb.UnpackMap(packet, scheme)
	}
	per := time.Since(start).Seconds() / float64(reps)
	runtime.ReadMemStats(&ms1)
	cpu2, rss2 := usage()
	total := 0
	switch v := row["s"].(type) {
	case string:
		total = len(v)
	}
	if items, okList := row["l"].([]any); okList {
		for _, it := range items {
			if s, isStr := it.(string); isStr {
				total += len(s)
			}
		}
	}
	fmt.Printf("textamp %s: %s; packet %d bytes; accepted %v; decoded %d UTF-8 bytes (%.3f per packet byte); %.2f ms per unpack (%d reps); allocated %.1f MB per unpack\n",
		which, label, len(packet), err == nil, total, float64(total)/float64(len(packet)), per*1e3, reps,
		float64(ms1.TotalAlloc-ms0.TotalAlloc)/float64(reps)/1e6)
	fmt.Printf("  peak RSS: start %.1f MB, after building the packet %.1f MB, after unpack %.1f MB (+%.1f MB); cpu unpack %.2f s\n",
		rss0, rss1, rss2, rss2-rss1, cpu2-cpu1)
	runtime.KeepAlive(row)
	return per < 1
}
