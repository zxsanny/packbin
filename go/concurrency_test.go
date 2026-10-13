package packbin

import (
	"bytes"
	"sync"
	"sync/atomic"
	"testing"
)

// AC-6: one built scheme, 8 goroutines x 10 000 pack-then-unpack round trips; run under -race.
func TestAC6ConcurrentRoundTrips(t *testing.T) {
	// Arrange
	typed := positionTypedScheme(t)
	asMap := positionMapScheme(t)
	other := mustScheme(t, 1, U8(0, "x"))
	golden := mustHex(t, goldenHex(t))
	const goroutines, rounds = 8, 10_000
	var mismatches, failures atomic.Int64
	var wg sync.WaitGroup

	// Act
	for g := range goroutines {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for i := range rounds {
				speed := uint8(i)
				row := goldenRow()
				if g%2 == 1 {
					row.Speed = &speed
				}
				raw, err := Pack(typed, row)
				if err != nil {
					failures.Add(1)
					continue
				}
				back, err := Unpack(raw, typed, other)
				if err != nil {
					failures.Add(1)
					continue
				}
				got := back.(*Position)
				if got.Sid != 1 || got.Lat != row.Lat || (g%2 == 1 && (got.Speed == nil || *got.Speed != speed)) {
					mismatches.Add(1)
				}
				if g%2 == 0 {
					m, err := UnpackMap(raw, asMap)
					again, packErr := Pack(asMap, m)
					if err != nil || packErr != nil || !bytes.Equal(again, golden) {
						mismatches.Add(1)
					}
				}
			}
		}()
	}
	wg.Wait()

	// Assert
	if mismatches.Load() != 0 || failures.Load() != 0 {
		t.Fatalf("mismatches %d failures %d", mismatches.Load(), failures.Load())
	}
}
