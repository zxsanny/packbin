package packbin

import (
	"runtime"
	"testing"
	"time"
)

// AC-7 (project AC-10): 100 000 pack-then-unpack round trips of the AC-1 row (and of a 20-character string) on one core take at most
// 1 second. The fastest of up to three passes counts, as in TypeScript: a shared runner can stall one
// pass, while a real slowdown makes every pass slow.
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
			fastest := time.Duration(1<<63 - 1)

			// Act
			for pass := 0; pass < 3 && fastest > time.Second; pass++ {
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
				fastest = min(fastest, time.Since(start))
			}

			// Assert
			t.Logf("%s: fastest pass of %d round trips: %v (race detector: %v)", form.name, rounds, fastest, raceEnabled)
			if raceEnabled {
				// The race detector costs about 5x; the 1 s bound is asserted by the run without it
				// (run-suite.sh go runs this test a second time with -run, no -race).
				t.Skipf("%s: %v under the race detector; the 1 s bound is asserted without it", form.name, fastest)
			}
			if fastest > time.Second {
				t.Fatalf("fastest pass %v, above 1s", fastest)
			}
		})
	}
}
