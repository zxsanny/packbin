package main

import (
	"encoding/hex"
	"fmt"
	"os"
	"runtime"
	"strconv"
	"strings"
	"syscall"
	"time"
)

// Probe tools: the seeded stream, CPU and peak RSS, hex and varint, guarded calls and the fixtures.

// ---------------------------------------------------------------- small tools

type rng struct{ s uint64 }

func (r *rng) next() uint64 {
	r.s += 0x9E3779B97F4A7C15
	z := r.s
	z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9
	z = (z ^ (z >> 27)) * 0x94D049BB133111EB
	return z ^ (z >> 31)
}

func (r *rng) below(n int) int {
	if n <= 0 {
		return 0
	}
	return int(r.next() % uint64(n))
}

func (r *rng) byte() byte { return byte(r.next()) }

func (r *rng) fill(n int) []byte {
	out := make([]byte, n)
	for i := range out {
		out[i] = r.byte()
	}
	return out
}

// usage is the CPU seconds and the peak RSS in MB (VmHWM on Linux, ru_maxrss elsewhere) of this process.
func usage() (float64, float64) {
	var ru syscall.Rusage
	_ = syscall.Getrusage(syscall.RUSAGE_SELF, &ru)
	cpu := float64(ru.Utime.Sec+ru.Stime.Sec) + float64(ru.Utime.Usec+ru.Stime.Usec)/1e6
	rss := float64(ru.Maxrss) * 1024 / 1e6
	if runtime.GOOS == "darwin" {
		rss = float64(ru.Maxrss) / 1e6
	}
	if status, err := os.ReadFile("/proc/self/status"); err == nil {
		for _, line := range strings.Split(string(status), "\n") {
			if strings.HasPrefix(line, "VmHWM:") {
				f := strings.Fields(line)
				if kb, err := strconv.Atoi(f[1]); err == nil {
					rss = float64(kb) * 1024 / 1e6
				}
			}
		}
	}
	return cpu, rss
}

func reportUsage(label string) {
	cpu, rss := usage()
	var ms runtime.MemStats
	runtime.ReadMemStats(&ms)
	fmt.Printf("usage %s: cpu %.2f s, peak RSS %.1f MB, Go heap sys %.1f MB, total allocated %.1f MB\n",
		label, cpu, rss, float64(ms.HeapSys)/1e6, float64(ms.TotalAlloc)/1e6)
}

func unhex(s string) []byte {
	if s == "-" {
		return nil
	}
	b, err := hex.DecodeString(s)
	if err != nil {
		panic(err)
	}
	return b
}

func head(b []byte) string {
	h := hex.EncodeToString(b[:min(len(b), 40)])
	if len(b) > 40 {
		return fmt.Sprintf("%s...(%d bytes)", h, len(b))
	}
	return h
}

func varint(c int) []byte {
	var out []byte
	for {
		b := byte(c & 0x7f)
		c >>= 7
		if c == 0 {
			return append(out, b)
		}
		out = append(out, b|0x80)
	}
}

func field(payload []byte) []byte { return append(varint(len(payload)), payload...) }

// guarded runs f, catching a panic; it reports whether f panicked and how long it took.
func guarded(f func()) (panicked bool, dt time.Duration) {
	start := time.Now()
	func() {
		defer func() {
			if r := recover(); r != nil {
				panicked = true
				msg := fmt.Sprint(r)
				fmt.Fprintf(os.Stderr, "panic: %s\n", msg[:min(len(msg), 300)])
			}
		}()
		f()
	}()
	return panicked, time.Since(start)
}

// ---------------------------------------------------------------- fixtures

type seeds struct {
	text   [][]byte
	ecc    []eccSeed
	corpus [][]byte
}

type eccSeed struct {
	n   int
	buf []byte
}

func loadSeeds(checkout string) seeds {
	read := func(p string) []string {
		b, err := os.ReadFile(checkout + "/" + p)
		if err != nil {
			panic(err)
		}
		return strings.Split(string(b), "\n")
	}
	var s seeds
	for _, line := range read("fixtures/text/vectors.txt") {
		w := strings.Fields(line)
		if len(w) == 4 && (w[0] == "enc" || w[0] == "alt" || w[0] == "bad") {
			s.text = append(s.text, unhex(w[3]))
		}
	}
	for _, line := range read("fixtures/ecc/vectors.txt") {
		w := strings.Fields(line)
		switch {
		case len(w) == 5 && w[0] == "enc", len(w) == 7 && w[0] == "fix", len(w) == 6 && w[0] == "bad":
			n, _ := strconv.Atoi(w[2])
			s.ecc = append(s.ecc, eccSeed{n, unhex(w[4])})
		}
	}
	for _, line := range read("fixtures/hostile/fuzz/corpus.txt") {
		w := strings.Fields(line)
		if len(w) == 3 && !strings.HasPrefix(line, "#") {
			s.corpus = append(s.corpus, unhex(w[2]))
		}
	}
	return s
}
