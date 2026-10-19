package packbin

import (
	"runtime"
	"testing"
	"time"
)

// AC-7 (project AC-10): 100 000 pack-then-unpack round trips of the AC-1 row (and of a 20-character string) on one core take at most
// 1 second times the load factor (timing_test.go). The fastest of up to three passes counts, as in TypeScript:
// a shared runner can stall one pass, while a real slowdown makes every pass slow.
func TestAC7SpeedRoundTrips(t *testing.T) {
	for _, form := range []struct {
		name   string
		scheme *Scheme
		row    any
	}{
		{"typed", positionTypedScheme(t), goldenRow()},
		{"map", positionMapScheme(t), goldenMap()},
		// AZ-2653 AC-8: a 20-character Ukrainian string, packed with the compact text format and read back.
		{"text", mustScheme(t, 1, Utf8(0, "s")), gm("s", "Доброго ранку, друже")},
	} {
		t.Run(form.name, func(t *testing.T) {
			// Arrange
			const rounds = 100_000
			defer runtime.GOMAXPROCS(runtime.GOMAXPROCS(1))
			fastest, factor := time.Duration(1<<63-1), 1.0

			// Act
			for pass := 0; pass < 3 && fastest > scaled(time.Second, factor); pass++ {
				passFactor := loadFactor()
				start := time.Now()
				for range rounds {
					raw, err := Pack(form.scheme, form.row)
					if err != nil {
						t.Fatal(err)
					}
					if _, err := Unpack(raw, form.scheme); err != nil {
						t.Fatal(err)
					}
				}
				if took := time.Since(start); float64(took)/passFactor < float64(fastest)/factor {
					fastest, factor = took, passFactor
				}
			}

			// Assert
			t.Logf("%s: fastest pass of %d round trips: %v at load factor %.2f (race detector: %v)", form.name, rounds, fastest, factor, raceEnabled)
			if raceEnabled {
				// The race detector costs about 5x; the 1 s bound is asserted by the run without it
				// (run-suite.sh go runs this test a second time with -run, no -race).
				t.Skipf("%s: %v under the race detector; the 1 s bound is asserted without it", form.name, fastest)
			}
			assertWithin(t, "fastest pass of "+form.name, fastest, time.Second, factor)
		})
	}
}
