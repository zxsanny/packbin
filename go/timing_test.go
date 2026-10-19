package packbin

import (
	"sync"
	"testing"
	"time"
)

// Load-aware wall-clock bounds (AZ-2723). A test bound is nominal * loadFactor(): how many times slower than an
// idle host a fixed CPU-bound reference loop runs right now, measured in this process, never below 1 and never
// above maxLoadFactor. An idle host keeps the nominal bound, a host loaded by other work gets more time, and a
// slowdown of 8 times or more in the code under test still fails everywhere. The race detector slows the
// reference loop too, so the idle-host time has one constant per build.

// referenceSecondsPlain and referenceSecondsRace are the smallest of 90 runs of referenceRun on an idle host
// (the Mac's Docker golang:1.27, 2026-10-19), in seconds; a loaded host only adds time to a run.
const (
	referenceSecondsPlain = 0.0285
	referenceSecondsRace  = 0.0737
	maxLoadFactor         = 8.0
	// freshFor is how long recentLoadFactor reuses a measurement.
	freshFor = time.Second
)

// referenceSink keeps the compiler from removing the reference loop; referenceTable is a package variable so the
// race detector instruments its reads, as it does the memory the code under test touches.
var (
	referenceSink  uint32
	referenceTable [1024]uint32
)

// referenceRun is integer work with a data-dependent table index and a multiply chain.
func referenceRun() time.Duration {
	for i := range referenceTable {
		referenceTable[i] = uint32(i) * 2654435761
	}
	state := uint32(0x9E3779B9) ^ referenceSink
	start := time.Now()
	for range 8_000_000 {
		state = (state^referenceTable[(state>>22)&1023])*1664525 + 1013904223
	}
	took := time.Since(start)
	referenceSink = state
	return took
}

// loadFactor is the smallest of 3 reference runs over the idle-host time, clamped to [1, maxLoadFactor].
func loadFactor() float64 {
	idle := referenceSecondsPlain
	if raceEnabled {
		idle = referenceSecondsRace
	}
	fastest := referenceRun()
	for range 2 {
		fastest = min(fastest, referenceRun())
	}
	return min(max(fastest.Seconds()/idle, 1), maxLoadFactor)
}

var (
	recentMu     sync.Mutex
	recentAt     time.Time
	recentFactor float64
)

// recentLoadFactor is loadFactor reused for freshFor: for guards inside loops that run one bound many times.
func recentLoadFactor() float64 {
	recentMu.Lock()
	defer recentMu.Unlock()
	if recentFactor != 0 && time.Since(recentAt) < freshFor {
		return recentFactor
	}
	recentFactor = loadFactor()
	recentAt = time.Now()
	return recentFactor
}

// scaled is nominal * factor.
func scaled(nominal time.Duration, factor float64) time.Duration {
	return time.Duration(float64(nominal) * factor)
}

// sustainedLoadFactor is the mean of back-to-back reference runs over window, over the idle-host time, clamped to
// [1, maxLoadFactor]. Unlike loadFactor (the smallest of 3 short runs, which a scheduler serves ahead of a
// section that has been running for seconds) it measures the throughput this process gets over a stretch as long
// as the section that just ran, so it is taken only to confirm a failure, right after the section.
func sustainedLoadFactor(window time.Duration) float64 {
	idle := referenceSecondsPlain
	if raceEnabled {
		idle = referenceSecondsRace
	}
	window = min(window, 10*time.Second)
	start := time.Now()
	runs := 0
	for runs == 0 || time.Since(start) < window {
		referenceRun()
		runs++
	}
	return min(max(time.Since(start).Seconds()/float64(runs)/idle, 1), maxLoadFactor)
}

// assertWithin fails the test, naming the nominal bound, the factor and the elapsed time, when elapsed is over
// the load-aware bound. factorBefore is the loadFactor() taken before the timed section. The first check uses
// it alone; when that fails, the bound is scaled by the largest of it, a fresh loadFactor() and the sustained
// factor over a window as long as the section, because the load that slows a section of a second or more can
// start after the first measurement and is not seen by a 90 ms sample.
func assertWithin(t testing.TB, what string, elapsed, nominal time.Duration, factorBefore float64) {
	t.Helper()
	if elapsed <= scaled(nominal, factorBefore) {
		return
	}
	sustained := sustainedLoadFactor(elapsed)
	factor := max(factorBefore, loadFactor(), sustained)
	if elapsed > scaled(nominal, factor) {
		t.Fatalf("%s: took %v, over the nominal bound %v x load factor %.2f (before %.2f, sustained %.2f) = %v",
			what, elapsed, nominal, factor, factorBefore, sustained, scaled(nominal, factor))
	}
}
