---
loop: 26
branch: dev
---

# Swift round limits, pack budgets and unpack fuzzing

**Task**: AZ-2517_swift_limits
**Name**: Swift round limits, pack budgets and unpack fuzzing
**Description**: Swift has the same `maxRounds`, `maxSlots`, `maxBytes` defaults, a limits setting, pack caps and a bounded unpack, proven by a corpus and seeded random unpack run.
**Complexity**: 3 points
**Dependencies**: AZ-2516
**Component**: swift
**Tracker**: AZ-2517
**Epic**: AZ-2223

## Problem

Without the limits a hostile packet or row makes Swift allocate or loop without bound (F28, F33 in other packages); in Swift an unchecked count can also trap and kill the host.

Feature ACs and scenarios: `_docs/02_task_plans/swift-package/` (owns SW-5; scenario S6 owned).

## Outcome

- Defaults 65 535 / 1 048 576 / 16 777 216; the limits setting refuses a limit below 1 and defaults an omitted one (as C#, TypeScript, Python).
- Unpack work is bounded by the input length and the limits; the fuzz run finds 0 traps.

## Scope

### Included

- Defaults and the limits setting; unpack round refusal before the round's bytes are read (`too_many`/`bad_value`, needed 0); pack refusals for a `times` count or `repeat` list above `maxRounds`, a round past `maxSlots`, output above `maxBytes`; empty-body charge; raised-limit unpack of the old worst packet (F10).
- The shared unpack corpus `fixtures/hostile/fuzz/` (new: raw inputs with the scheme kind each is read with, seeded from the hostile `unpack` hex and the inputs of Go's corpus; Go's corpus in `go/testdata/` is not changed) and a Swift unpack fuzz run over it plus a seeded random run: the seed is printed, the duration is set from outside (≥ 60 s in CI, a few seconds by default in `swift test`).
- Owns (exclusive write): `swift/**`, `fixtures/hostile/fuzz/**`

### Excluded

- The hostile file loader (AZ-2519)
- The CI step that runs the fuzz for 60 s (AZ-2521)

## Acceptance Criteria

**AC-1: Limit rows (SW-5, S6)**
Given the TypeScript tests `round-limits`, `pack-output-budget`, `pack-repeat-round-cap`, `pack-round-count-cap`, `round-slot-width`, `round-scope-cost`, `loop22-max-slots` and the rows of `reference_loop20_budget.md`, `reference_loop21_slots.md`, `reference_loop22.md`
When ported to Swift
Then same outcome as TypeScript; rows at 65 535 rounds, 1 048 576 slots and 16 MiB output pack and unpack, one past is refused naming the member; disagreements 0; traps 0

**AC-2: Bounded unpack (SW-5)**
Given the `fixtures/hostile/fuzz/` corpus and a seeded random run
When the Swift unpack fuzz run runs for 60 s
Then traps 0; each input returns in ≤ 1 second; no storage is reserved from an input count before that count is charged to the round and slot budget (pinned by a maximal-count, short-input case refused with needed 0 in ≤ 1 s)

**AC-3: Raised limit (SW-5)**
Given the old worst packet (F10) and a scheme with a raised `maxSlots`
When unpacked
Then unpacks; with the default limit it is refused

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-1 | ported limit rows, at and one past each limit | TypeScript outcome |
| AC-2 | corpus + seeded random run (short by default) | 0 traps |
| AC-3 | raised limit | unpacks |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-1 | hostile `limit` cases (AZ-2519) | limit stage | too_many or bad_value, needed 0 | — |
| AC-2 | `run-suite.sh swift` (AZ-2521) | 60 s fuzz step | 0 traps | SW-5 |

## Constraints

- Swift copies TypeScript at HEAD row for row (loop 26 fit decision 4); where TypeScript is a documented exception (U6 bigint `times` split) Swift follows the others (C#, Python, Rust, Java, Go). A disagreement found while porting is reported to the parent, not decided inside the task (probe-first).
- The fuzz run must not assert that an unpacked row repacks: a `flags` `times` whose bit is clear with a count above 0 unpacks and then repacks with `missing pt` (as TypeScript and Go). A huge `times` count with a lone scalar loops on pack until the pack caps exist: charge `maxRounds`/`maxSlots` where rounds start.
- A trap is a process exit, not a thrown error: the fuzz run counts a trap as a failed run of the whole step, so its input must be recoverable (the seed is printed before the run; corpus inputs are named).
- ADR-001: no generator, no other package imported. No fuzzing library or test-only package dependency (SW-11).
- Local runs are `swift test` at the repository root on the owner's Mac (Swift 6.3.3); Linux runs use `swift:6`. No language feature newer than Swift 5.9.
- Errors are thrown as the typed `PackbinError`; no trap escapes `pack`, `unpack` or scheme construction on any input. Budget sums (rounds x body width, slots, output bytes) use checked arithmetic: an overflowing sum is a refusal, never a trap.

## Risks & Mitigation

**Risk 1: Fuzz time in CI**
- *Risk*: 60 s fuzz adds a minute to the suite.
- *Mitigation*: The 60 s run is a separate CI step (AZ-2521) with the duration set from outside; the default `swift test` runs the corpus and a few seconds of random input.

**Risk 2: No coverage-guided fuzzer**
- *Risk*: Swift's libFuzzer support is Linux-only and a seeded random run finds fewer deep paths than Go's coverage-guided fuzzing.
- *Mitigation*: The corpus carries Go's coverage-found inputs and every hostile `unpack` packet; random inputs mutate corpus entries as well as drawing fresh bytes.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Swift traps on overflow, out-of-range index and force unwrap; a trap on hostile input kills the process | checked arithmetic on budgets and counts; AC-2 counts traps | open | High |
| `fixtures/hostile/fuzz/` does not exist yet; this task creates it (shared, so later packages may read it); SW-5 "0 allocations above the slot budget's ceiling" is measured as "no storage reserved before the budget charge" (AC-2), not a memory profile | parent confirms the folder and the measure | open | Low |
