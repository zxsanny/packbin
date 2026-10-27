package main

// Native Go fuzz targets of the AZ-2666 probe (loop 41). Run one with run.sh:
//   sh run.sh <checkout> <work dir> fuzz FuzzTextLone 90
// The seed corpus is read from the checkout named by PACKBIN_CHECKOUT (run.sh sets it): the text vectors,
// the ECC vectors and fixtures/hostile/fuzz/corpus.txt. Each target fails on a panic, on a call above 1 s,
// and on a broken invariant (decoded size above 6N + 8, a repair that is not a code word within the limit,
// a written input).

import (
	"bytes"
	"os"
	"testing"
	"time"

	pb "github.com/zxsanny/packbin/go"
)

func fuzzSeeds(f *testing.F) seeds {
	checkout := os.Getenv("PACKBIN_CHECKOUT")
	if checkout == "" {
		f.Skip("PACKBIN_CHECKOUT is not set")
	}
	return loadSeeds(checkout)
}

func within(t *testing.T, start time.Time, input []byte) {
	if d := time.Since(start); d > time.Second {
		t.Fatalf("call took %v: %s", d, head(input))
	}
}

func FuzzTextLone(f *testing.F) {
	s := fuzzSeeds(f)
	for _, b := range append(append([][]byte{}, s.text...), s.corpus...) {
		f.Add(b)
	}
	f.Fuzz(func(t *testing.T, fieldBytes []byte) {
		packet := append([]byte{1}, fieldBytes...)
		start := time.Now()
		row, err := pb.UnpackMap(packet, sScheme)
		within(t, start, packet)
		if err == nil {
			text, _ := row["s"].(string)
			if n := payloadLen(fieldBytes); len(text) > 65535 || len(text) > 6*n+8 {
				t.Fatalf("decoded %d bytes from a %d-byte payload", len(text), n)
			}
		}
	})
}

func FuzzTextList(f *testing.F) {
	s := fuzzSeeds(f)
	for _, b := range s.text {
		f.Add(append([]byte{2, 0}, append(append([]byte{}, b...), b...)...))
		f.Add(append([]byte{1, 0}, append(append([]byte{}, b...), 7)...))
	}
	f.Fuzz(func(t *testing.T, body []byte) {
		packet := append([]byte{1}, body...)
		for _, sc := range []*pb.Scheme{lScheme, dScheme} {
			start := time.Now()
			_, _ = pb.UnpackMap(packet, sc)
			within(t, start, packet)
		}
	})
}

func FuzzEccRepair(f *testing.F) {
	s := fuzzSeeds(f)
	for _, e := range s.ecc {
		f.Add(uint8(max(e.n, 1)-1), uint8(e.n/2), e.buf)
	}
	f.Fuzz(func(t *testing.T, nByte, limitByte uint8, buf []byte) {
		n := 1 + int(nByte)%32
		limit := int(limitByte) % (n/2 + 1)
		before := clone(buf)
		start := time.Now()
		clear, rep, err := repairBytes(buf, n, limit)
		within(t, start, buf)
		if !bytes.Equal(before, buf) {
			t.Fatal("input written")
		}
		if err == nil {
			again := protect(clear, n)
			if rep > limit || len(again) != len(buf) || hamming(again, buf) != rep {
				t.Fatalf("repair not a code word within the limit: n %d t %d repaired %d", n, limit, rep)
			}
		}
	})
}
