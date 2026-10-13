---
loop: 25
branch: dev
---

# Go peak memory for F10 and wide-round packets

**Task**: AZ-2475_go_peak_memory
**Name**: Go peak memory for F10 and wide-round packets
**Description**: Measure Go's peak memory for the F10 packet at `maxSlots` 4 194 304 and the wide-round packet at the defaults; land one figure per shape into the loop 22 memory table and the README memory bullet.
**Complexity**: 1 point
**Dependencies**: none
**Component**: go
**Tracker**: AZ-2475
**Epic**:

## Problem

D8 (assessment 24, handoff 25) carries forward: Go has no measured peak memory for the two shapes the loop 22 memory table pins across the other packages. The F41 audit figures were indicative ("about 10 %"); one measured number per shape is needed to publish the Go column.

Reference: `_docs/06_metrics/retro_2026-10-12_loop22.md` (table), `_docs/loops/loop24/assessment24.md` (D8), F41 audit note in handoff 25.

## Outcome

- `go/mem_test.go` (or named alike) measures peak allocation of unpack on both shapes, once per shape, via `runtime.ReadMemStats` or an allocation profile; the test prints the figure in MB and PASSes.
- The loop 22 memory table (`_docs/06_metrics/retro_2026-10-12_loop22.md`) and the README memory bullet gain a Go row with the measured figure (not an estimate).
- The measurement is a Go `-run` test, not a Go `-bench`; it is not part of the `test.yml` scaffold (opt-in via a build tag or an environment variable so the CI runtime does not change).

## Scope

### Included

- `go/mem_test.go` and any helper under `go/` the measurement needs.
- Owns (exclusive write): `go/mem_test.go`, `go/internal/memcheck/**` if a helper is needed; the README edits and the loop 22 retro row (parent writes on close).

### Excluded

- Any other package.
- A new perf NFR; the figure is a measurement, not a bound (plan25.md step 15 marked `no`).

## Acceptance Criteria

**AC-1: F10 peak measured**
Given the F10 shape (hostile packet raised to the current limits; `maxSlots` 4 194 304)
When the Go memory test unpacks and reads `HeapAlloc` across the run
Then one figure in MB prints, within one run (± 10 %), and the test PASSes.

**AC-2: Wide-round peak measured**
Given the wide-round shape (`roundLimit` default; 1 MiB-equivalent per the F41 audit)
When the Go memory test unpacks and reads `HeapAlloc`
Then one figure in MB prints and the test PASSes.

**AC-3: Loop 22 table carries the figure**
Given the AC-1 and AC-2 figures
When the loop 22 retro table is read
Then it has a Go row with both numbers.

**AC-4: README memory bullet names Go**
Given the README's "Limits to keep in mind" / memory bullet
When read
Then it names Go with the measured figures (same wording shape as the other packages).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-1 | F10 at raised limits | figure prints, PASS |
| AC-2 | wide-round at defaults | figure prints, PASS |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-1 | F10 shape; `maxSlots` 4 194 304 | measure Go peak | one figure (MB) | |
| AC-2 | wide-round shape; defaults | measure Go peak | one figure (MB) | |
