---
loop: 24
branch: dev
---

# Go round limits, pack budgets and unpack fuzzing

**Task**: AZ-2444_go_limits
**Name**: Go round limits, pack budgets and unpack fuzzing
**Description**: Go has the same `maxRounds`, `maxSlots`, `maxBytes` defaults, `WithLimits`, pack caps and a bounded unpack, proven by fuzzing.
**Complexity**: 3 points
**Dependencies**: AZ-2443
**Component**: go
**Tracker**: AZ-2444
**Epic**: AZ-2222

## Problem

Without the limits a hostile packet or row makes Go allocate or loop without bound (F28, F33 in other packages).

Feature ACs and scenarios: `_docs/02_task_plans/go-package/` (GO-5; scenario S6).

## Outcome

- Defaults 65 535 / 1 048 576 / 16 777 216; `WithLimits` refuses a non-positive limit.
- Unpack work is bounded by the input length and the limits; fuzzing finds 0 panics.

## Scope

### Included

- Defaults and `WithLimits`; unpack round refusal before the round's bytes are read (`too_many`/`bad_value`, needed 0); pack refusals for a `times` count or `repeat` list above `maxRounds`, a round past `maxSlots`, output above `maxBytes`; empty-body charge; raised-limit unpack of the old worst packet; a fuzz target for unpack with a seed corpus in `go/testdata/`.
- Owns (exclusive write): `go/**`

### Excluded

- The hostile file loader (AZ-2446)

## Acceptance Criteria

**AC-1: Limit rows**
Given the TypeScript tests `round-limits`, `pack-output-budget`, `pack-repeat-round-cap`, `pack-round-count-cap`, `round-slot-width`, `round-scope-cost`, `loop22-max-slots` and the rows of `reference_loop20_budget.md`, `reference_loop21_slots.md`, `reference_loop22.md`
When ported to Go
Then same outcome as TypeScript; disagreements 0

**AC-2: Bounded unpack**
Given random and corpus inputs
When `go test -fuzz=FuzzUnpack -fuzztime=60s`
Then panics 0; each input returns in ≤ 1 second

**AC-3: Raised limit**
Given the old worst packet and a scheme with a raised limit
When unpacked
Then unpacks; with the default limit it is refused

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-1 | ported limit rows | TypeScript outcome |
| AC-2 | fuzz 60 s | 0 panics |
| AC-3 | raised limit | unpacks |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-1 | hostile `limit` cases (AZ-2446) | limit stage | too_many or bad_value, needed 0 | — |

## Constraints

- Go copies TypeScript at HEAD row for row (loop 24 fit decision 4); where TypeScript is a documented exception (U6 bigint `times` split) Go follows the five. A disagreement found while porting is reported to the parent, not decided inside the task (probe-first).
- ADR-001: hand-written walker, no generator, no import of another package. Standard library plus `golang.org/x/crypto` only (G-3). No cgo.
- `FuzzUnpack` must not assert that an unpacked row repacks: a `flags` `times` whose bit is clear with a count above 0 unpacks and then repacks with `missing pt` (as TypeScript; AZ-2442 discovery 18). A huge `times` count with a lone scalar loops on pack until this task adds the pack caps (discovery 22). Rounds start in `packer.rounds` and `reader.rounds` (marked): charge `maxRounds`/`maxSlots` there.
- Go runs only in Docker on the owner's Mac: `docker run --rm -v "$PWD":/src -w /src/go golang:1.27 go test -race ./...` (G-2).
- Errors are values; no panic escapes `Pack`, `Unpack` or scheme construction on any input.

## Risks & Mitigation

**Risk 1: Fuzz time in CI**
- *Risk*: 60 s fuzz adds a minute to the suite.
- *Mitigation*: The fuzz run is a separate CI step (AZ-2448) with `-fuzztime=60s`; the default `go test` runs the seed corpus only.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none beyond the feature's (size, `problem.md`) | parent | resolved | Low |
