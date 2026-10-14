# Performance Tests

### NFT-PERF-01: Position round trips

**Summary**: 100000 pack-then-unpack round trips of the 13-byte fixture stay inside one second on one core.
**Traces to**: AC-10
**Metric**: elapsed time

**Preconditions**:
- One core
- One warm-up call of the same fixture before the timed loop

**Steps**:

| Step | Consumer Action | Measurement |
|------|----------------|-------------|
| 1 | pack and unpack the position fixture 100000 times | elapsed time |

**Pass criteria**: elapsed time ≤ 1 second, in C# and in TypeScript (the TypeScript test asserts ≤ 1.4 seconds since loop 25, owner decision of 2026-10-14: on a loaded host all three passes took 1,280 ms; the product bound stays 1 second, measured on an idle machine)
**Duration**: one loop of 100000 iterations

**Go (loop 24, GO-8, FT-X-91)**: `TestAC7SpeedRoundTrips` runs the same loop typed and as a map, on one core (`GOMAXPROCS(1)`), the fastest of up to three passes. The bound is asserted only without the race detector (about 5x slower: 580 ms typed, 447 ms map on the owner's Mac); `run-suite.sh go` runs the test a second time without `-race`. Compose run after the review fixes: 160 ms typed, 128 ms map. The test failed twice at host load average 79 to 87 before the move (batch discoveries 15, 29, 38): run it on a quiet host.

**Swift (loop 26, SW-8, FT-X-132)**: `SpeedTests.roundTrips_hundredThousandGoldenRows_takeAtMostOneSecond` runs the same loop typed and as a map. `run-suite.sh swift` asserts the bound in a release build (`swift_speed`, which also times the 1 MiB hostile unpack `FuzzTests/mebibyte`); the debug run makes one pass, and the thread-sanitizer run does not run it (in the `swift:6.3.3` container the sanitizer made the size and speed tests take 25 minutes). Worker runs on the owner's Mac in release: 0.37 s typed, 0.19 s map (AZ-2513), 0.40 s and 0.22 s (AZ-2517). The step 11 release speed run in the container passed. The first figure on the Ubuntu runner is unknown.
