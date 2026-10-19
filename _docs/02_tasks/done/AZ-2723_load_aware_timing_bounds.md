# Load-aware wall-clock bounds in the test suites of all eight packages

**Task**: AZ-2723_load_aware_timing_bounds
**Name**: Load-aware timing bounds (retro action 2)
**Description**: A wall-clock assertion in a test scales its bound with the speed the host has right now, measured by a reference loop in the same process, so step 11 stops needing serial retries.
**Complexity**: 5 points
**Dependencies**: None
**Component**: tests of all 8 packages
**Tracker**: AZ-2723
**Epic**: AZ-2645

## Problem

In loops 38 to 42 step 11 passed only on the serial retry (or failed) because fixed bounds of 1 to 2 s broke while other sessions loaded the host (load average 27 to 30 in loop 42): Go `TestAC3RaisedSlotLimit...` 1.14 s of 1 s, Go `TestAC1ALoneStringUnderATimes...` 1.36 s, C# `EccRepair 1000 repairs` 1.34 s, Python EC-13 1.63 s; earlier Rust debug `nfr_round_trips_under_one_second`, TypeScript round-scope-cost, Java AC-8. The Python AC-10 test already scales (`75b1d39`).

## Outcome

- Each package has one small test helper that returns a load factor: the best of three runs of a fixed CPU-bound reference loop, taken just before the timed code, divided by that loop's time on an idle host (measured once, the smallest of at least 10 runs, written in the helper), never below 1 and capped at 8.
- Every wall-clock assertion with a nominal bound of 3 s or less in the package's tests (unit, hostile replay, speed, NFR) uses `bound = nominal * factor`; the nominal bound and the work are unchanged, and the failure message prints the nominal bound, the factor and the elapsed time.
- A real regression still fails: the quadratic dict check of F51 (170 times over the bound) fails at the cap; a 2x slowdown fails on an idle host.

## Acceptance Criteria

**AC-1**: With the host idle, every package's suite passes as before with the same nominal bounds (the factor is 1 or close to it).
**AC-2**: With 12 busy processes running beside the suite (`yes > /dev/null` x 12 on this Mac), the timing checks of a package pass without a retry (run once per package).
**AC-3**: The helper and its constants are in one test file per package, under 500 lines per file; no production code changes.
**AC-4**: The gotcha line in `_docs/AGENT_GOTCHAS.md` names the helper of each package.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A bound that grows with load can hide a slowdown that happens only under load | the cap of 8 and the idle-host AC-1 run; CI runners are idle | accepted | Low |
