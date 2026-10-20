package packbin

import (
	"bytes"
	"fmt"
	"math/rand"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// AZ-2735 AC-1 (the reference bytes and the workers' own texts under concurrency) and AC-2 (the load-aware bound):
// the tables of the compact text codec are constants and its buffers are per call (CS-18), so workers sharing one
// built scheme must each get the same bytes and the same text as a single thread does.

const (
	textWorkers         = 8
	textRandomPerWorker = 200
	// textJoinLimit only stops a hang; the speed of the section is asserted by assertWithin.
	textJoinLimit = 60 * time.Second
)

// nominalTextBound is 1 s, 10 s under the race detector, which slows the codec down about 5 times (as in
// fuzz_unpack_test.go); the 1 s bound is the build without it.
func nominalTextBound() time.Duration {
	if raceEnabled {
		return 10 * time.Second
	}
	return time.Second
}

// textCase is a text and the packet of a one-field scheme that packs it, from a single-threaded reference.
type textCase struct {
	text string
	want []byte
}

// textFailures counts what the workers saw wrong and keeps the first few descriptions; a worker goroutine
// cannot call t.Fatal.
type textFailures struct {
	mismatches, errs, checked atomic.Int64
	mu                        sync.Mutex
	first                     []string
}

func (f *textFailures) note(format string, args ...any) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if len(f.first) < 5 {
		f.first = append(f.first, fmt.Sprintf(format, args...))
	}
}

// check packs and unpacks one case and compares both with the single-threaded reference.
func (f *textFailures) check(s *Scheme, worker int, c textCase) {
	f.checked.Add(1)
	raw, err := Pack(s, map[string]any{"s": c.text})
	if err != nil {
		f.errs.Add(1)
		f.note("worker %d: pack of %q: %v", worker, c.text, err)
		return
	}
	if !bytes.Equal(raw, c.want) {
		f.mismatches.Add(1)
		f.note("worker %d: %q packed to %x, want %x", worker, c.text, raw, c.want)
	}
	row, err := UnpackMap(raw, s)
	if err != nil {
		f.errs.Add(1)
		f.note("worker %d: unpack of %x: %v", worker, raw, err)
		return
	}
	if got, ok := row["s"].(string); !ok || got != c.text {
		f.mismatches.Add(1)
		f.note("worker %d: %x unpacked to %q, want %q", worker, raw, row["s"], c.text)
	}
}

// textWorkerCases is the vector rows, starting at a different row for each worker so that the workers
// pack different texts at the same moment, then the worker's own random texts (a long one every tenth).
func textWorkerCases(vectors []textCase, randoms []textCase, worker int) []textCase {
	start := worker * len(vectors) / textWorkers
	cases := make([]textCase, 0, len(vectors)+len(randoms))
	cases = append(cases, vectors[start:]...)
	cases = append(cases, vectors[:start]...)
	return append(cases, randoms...)
}

func TestACTextConcurrentWorkersGetTheReferenceBytesAndTheirOwnText(t *testing.T) {
	// Arrange
	s := mustScheme(t, 1, Utf8(0, "s"))
	reference := func(text string) textCase {
		raw, err := Pack(s, map[string]any{"s": text})
		if err != nil {
			t.Fatalf("pack of %q: %v", text, err)
		}
		return textCase{text, raw}
	}
	var vectors []textCase
	for _, r := range textRowsOf(t, "enc") {
		c := reference(rowText(t, r.cols[0]))
		if want := mustHex(t, "01"+r.cols[1]); !bytes.Equal(c.want, want) {
			t.Fatalf("%s: the single-threaded pack is %x, the vector says %x", r.id, c.want, want)
		}
		vectors = append(vectors, c)
	}
	perWorker := make([][]textCase, textWorkers)
	for w := range perWorker {
		rng := rand.New(rand.NewSource(int64(2735 + w)))
		randoms := make([]textCase, textRandomPerWorker)
		for i := range randoms {
			text := randomText(rng)
			if i%10 == 9 {
				text = strings.Join([]string{text, randomText(rng), randomText(rng), randomText(rng), randomText(rng)}, "")
			}
			randoms[i] = reference(text)
		}
		perWorker[w] = textWorkerCases(vectors, randoms, w)
	}
	var f textFailures
	var ready, finished sync.WaitGroup
	begin := make(chan struct{})
	done := make(chan struct{})
	for w := range textWorkers {
		ready.Add(1)
		finished.Add(1)
		go func() {
			defer finished.Done()
			ready.Done()
			<-begin
			for _, c := range perWorker[w] {
				f.check(s, w, c)
			}
		}()
	}
	go func() {
		finished.Wait()
		close(done)
	}()
	ready.Wait()
	factor := loadFactor()

	// Act
	start := time.Now()
	close(begin)
	select {
	case <-done:
	case <-time.After(textJoinLimit):
		t.Fatalf("the %d workers did not finish within %v: a hang", textWorkers, textJoinLimit)
	}
	took := time.Since(start)

	// Assert
	want := int64(textWorkers * (len(vectors) + textRandomPerWorker))
	if f.checked.Load() != want || f.mismatches.Load() != 0 || f.errs.Load() != 0 {
		t.Fatalf("checked %d of %d texts, mismatches %d, errors %d; first: %v",
			f.checked.Load(), want, f.mismatches.Load(), f.errs.Load(), f.first)
	}
	t.Logf("%d workers x %d texts (%d vector rows each): %v at load factor %.2f (race detector: %v)",
		textWorkers, len(vectors)+textRandomPerWorker, len(vectors), took, factor, raceEnabled)
	assertWithin(t, fmt.Sprintf("%d workers x %d texts", textWorkers, len(vectors)+textRandomPerWorker), took, nominalTextBound(), factor)
}
