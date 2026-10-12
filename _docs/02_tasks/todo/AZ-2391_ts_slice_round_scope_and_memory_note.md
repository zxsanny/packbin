---
loop: 21
branch: dev
---

# TypeScript sliceRound stops copying the enclosing scope per round; README says maxBytes bounds memory

**Task**: AZ-2391_ts_slice_round_scope_and_memory_note
**Name**: TypeScript sliceRound stops copying the enclosing scope per round; README says maxBytes bounds memory
**Description**: `sliceRound` no longer copies the whole enclosing scope per round, and the README says the output budget is also the memory bound.
**Complexity**: 2 points
**Dependencies**: none
**Component**: typescript, README (parent)
**Tracker**: AZ-2391
**Epic**: AZ-2069

## Problem

Security F34 (Low, pre-existing). TypeScript `sliceRound` (`rounds.ts:195`) copies the whole enclosing scope per round: one `times(65535) { u8 }` costs 1.5 s with 100 top-level fields and 23 s with 1 000.

## Outcome

- Per-round cost does not grow with the number of enclosing fields.
- README: `maxBytes` is also the memory bound (2 to 3 times the packet).

## Scope

### Included
- `typescript/src/**/rounds.ts`.

### Excluded
- Other packages (probe only; record any quadratic path in the batch report).

## Acceptance Criteria

**AC-1: flat cost**
Given `times(65535) { u8 }` with 1 000 top-level fields
When packed
Then the time is within 2 times the 100-field time

**AC-2: same bytes**
Given the existing round tests
When run
Then unchanged

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | timing ratio | within 2x |
| AC-2 | round tests | pass |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | none | unit tests only | - | — |

## Constraints

- Wire bytes unchanged.
- Timing test compares two sizes in one run, not an absolute number (loop 20 lesson).

## Loop 21 result

TypeScript `sliceRound` and `packItem` read through `Object.create(values)` views (`overlay`, `defineOwn`) instead of copying the enclosing scope: `times(65535) { u8 }` after 1 000 top-level `u8` took 23 878 ms before and 21 ms after; a list of 65 535 `u8` 24 621 ms before and 19 ms after. Test: `round-scope-cost.test.ts` (ratio of 100 to 1 000 fields; it flaked once under parallel load and passed on the idle step 11 run). README: `maxBytes` is also the memory bound of a pack call (2 to 3 times the packet).
