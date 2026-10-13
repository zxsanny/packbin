//go:build packbin_memtest

// Peak-memory measurement for the two shapes the loop 22 memory table pins across the other packages:
// the F10 hostile list of nested times rows at `MaxSlots` raised to 4 194 304, and the wide-round
// shape at the default limits. The result is a measurement, not a bound: each test prints one figure
// in MB and PASSes. The build tag `packbin_memtest` keeps the measurement out of the normal
// `go test ./...` run so CI runtime does not change. Run with:
//
//	go test -tags packbin_memtest -v -run TestMem -count=1 ./...
package packbin

import (
	"runtime"
	"strconv"
	"sync/atomic"
	"testing"
	"time"
)

// peakHeapAllocDuring runs fn, samples runtime.MemStats.HeapAlloc from a background goroutine, and
// returns the maximum HeapAlloc observed between an initial GC and when fn returns. The sampling
// interval is short enough that one allocation campaign of a few hundred MB is caught within ten
// percent (the acceptance figure); ReadMemStats stops the world briefly on each sample, which is the
// price of a Go-only measurement that needs no OS counter.
func peakHeapAllocDuring(fn func()) (peakHeap uint64, totalAlloc uint64) {
	runtime.GC()
	var before runtime.MemStats
	runtime.ReadMemStats(&before)
	var peak atomic.Uint64
	peak.Store(before.HeapAlloc)
	stop := make(chan struct{})
	done := make(chan struct{})
	go func() {
		defer close(done)
		ticker := time.NewTicker(500 * time.Microsecond)
		defer ticker.Stop()
		var ms runtime.MemStats
		for {
			select {
			case <-stop:
				runtime.ReadMemStats(&ms)
				if ms.HeapAlloc > peak.Load() {
					peak.Store(ms.HeapAlloc)
				}
				return
			case <-ticker.C:
				runtime.ReadMemStats(&ms)
				if ms.HeapAlloc > peak.Load() {
					peak.Store(ms.HeapAlloc)
				}
			}
		}
	}()
	fn()
	close(stop)
	<-done
	var after runtime.MemStats
	runtime.ReadMemStats(&after)
	return peak.Load(), after.TotalAlloc - before.TotalAlloc
}

// wideRoundNearOneMiB is `u32 n; times(n) { 65 u8 members m0..m64 }` with n chosen to put the packet
// just under 1 MiB and the slot total just under the default MaxSlots (1 048 576). With the body of
// 65 slots per round, n = 16 128 charges 1 048 320 slots and the packet is 1 048 324 bytes.
func wideRoundNearOneMiB(t testing.TB) (*Scheme, map[string]any) {
	t.Helper()
	const rounds = 16_128
	body := make([]Field, 65)
	row := map[string]any{"n": rounds}
	for i := range body {
		name := "m" + strconv.Itoa(i)
		body[i] = U8(i+1, name)
		row[name] = 1
	}
	return mustScheme(t, 1, append([]Field{U32(0, "n")}, Times(1, 0, body...))...), row
}

// AC-1: F10 shape at MaxSlots 4 194 304. The default (1 048 576) refuses this packet; raised, it
// unpacks to 65 535 nested rows of 64 u8 members each. The test prints the Go peak heap allocation
// in MB and PASSes (one figure per shape, within one run, per the spec's ± 10 % AC).
func TestMemF10PeakAtRaisedMaxSlots(t *testing.T) {
	// Arrange
	layout, packet := f10(t)
	raised := limited(t, layout, func(l *Limits) { l.MaxSlots = 4_194_304 })

	// Act
	peakHeap, totalAlloc := peakHeapAllocDuring(func() {
		row, err := UnpackMap(packet, raised)
		if err != nil {
			t.Fatalf("unpack: %v", err)
		}
		items, ok := row["items"].([]any)
		if !ok || len(items) != 65_535 {
			t.Fatalf("got %d items, want 65535", len(items))
		}
	})

	// Assert
	t.Logf("F10 (MaxSlots=4194304): peak HeapAlloc %d MB, TotalAlloc %d MB, packet %d bytes",
		peakHeap>>20, totalAlloc>>20, len(packet))
}

// AC-2: wide-round shape at the default limits, packet just under 1 MiB. Pack writes the packet, then
// one Unpack reads it; the test prints the Go peak heap allocation in MB and PASSes. This is the
// shape the F41 audit calls "a wide round" and the loop 22 memory table carries for every package.
func TestMemWideRoundPeakAtDefaults(t *testing.T) {
	// Arrange
	layout, row := wideRoundNearOneMiB(t)
	raw, err := Pack(layout, row)
	if err != nil {
		t.Fatalf("pack: %v", err)
	}

	// Act
	peakHeap, totalAlloc := peakHeapAllocDuring(func() {
		back, err := UnpackMap(raw, layout)
		if err != nil {
			t.Fatalf("unpack: %v", err)
		}
		list, ok := back["m64"].([]any)
		if !ok || len(list) != 16_128 {
			t.Fatalf("got m64 len=%d, want 16128", len(list))
		}
	})

	// Assert
	t.Logf("wide-round (default limits): peak HeapAlloc %d MB, TotalAlloc %d MB, packet %d bytes",
		peakHeap>>20, totalAlloc>>20, len(raw))
}
