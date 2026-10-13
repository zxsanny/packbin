---
loop: 24
branch: dev
---

# Go rounds and counted kinds: repeat, times, sized, two-bit slots, bits, packed

**Task**: AZ-2442_go_rounds
**Name**: Go rounds and counted kinds: repeat, times, sized, two-bit slots, bits, packed
**Description**: Go packs and unpacks `repeat`, `times`, `sized`, two-bit slots, `bits` and `packed` with the same bytes and refusals as TypeScript.
**Complexity**: 5 points
**Dependencies**: AZ-2441
**Component**: go
**Tracker**: AZ-2442
**Epic**: AZ-2222

## Problem

Round and counted kinds carry most of the parity rows of loops 13 to 23 (U3, U8, U11, U13, the split-form rules). Go must match them or a Go peer drops or misreads values.

Feature ACs and scenarios: `_docs/02_task_plans/go-package/` (GO-2 (round kinds), GO-3, GO-12; scenario S8).

## Outcome

- README examples for repeat, sized, two-bit slots, bits, packed and times pack and unpack with 0 mismatched bytes.
- A round unpacks to one entry per round, nil for a skipped round; aligned lists as TypeScript.

## Scope

### Included

- `repeat`, `times` (count from an earlier integer field), `sized`, `u2` slots, `bits`, `packed`; flags and `when` inside round bodies; round values as aligned lists (typed and map rows); the U11 no-value count refusal at top level and in the six nested positions; U3/U8 short optional lists; split-form loud pack; `times` longer list and count-0-with-values refusals; empty round body refused at construction.
- Owns (exclusive write): `go/**`

### Excluded

- Round limits and budgets (AZ-2444)
- utf8/list/dict members inside rounds (AZ-2443)

## Acceptance Criteria

**AC-1: README round examples**
Given each README example for repeat, sized, two-bit slots, bits, packed, times
When packed and unpacked
Then the README hex both ways; mismatched bytes 0

**AC-2: Round rows**
Given the TypeScript round tests (`round-values`, `round-roundtrip`, `repeat-short-optional`, `times-longer-list`, `times-count-zero-with-values`, `flags-times-repeat-member`, `flags-under-split-bit`, `split-form-loud-pack`, `split-form-reference`, `empty-round-body`, `nested-round`, `u64-count`, `when-on-written-values`)
When ported to Go
Then same hex or same refusal as TypeScript; disagreements 0

**AC-3: No-value count (U11)**
Given a `bits`/`packed`/`sized` member with a value whose count is no value or behind a clear `when`, at top level and in the six nested positions (`loop22-novalue-count`, `loop23-novalue-nested`)
When packed
Then refused naming the member and the count; a nil slice is no value, an empty slice is 0 items (G-5)

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-1 | README round table | README hex |
| AC-2 | ported round rows | TypeScript outcome |
| AC-3 | U11 grid | refused |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-2 | ring kinds `roundflags`, `roundwhen` (AZ-2449) | Go in the ring | unpacks | — |

## Constraints

- Go copies TypeScript at HEAD row for row (loop 24 fit decision 4); where TypeScript is a documented exception (U6 bigint `times` split) Go follows the five. A disagreement found while porting is reported to the parent, not decided inside the task (probe-first).
- ADR-001: hand-written walker, no generator, no import of another package. Standard library plus `golang.org/x/crypto` only (G-3). No cgo.
- Go runs only in Docker on the owner's Mac: `docker run --rm -v "$PWD":/src -w /src/go golang:1.27 go test -race ./...` (G-2).
- Errors are values; no panic escapes `Pack`, `Unpack` or scheme construction on any input.

## Risks & Mitigation

**Risk 1: Rounds are the largest surface**
- *Risk*: The TypeScript round code is about 600 lines with many rules.
- *Mitigation*: Port test files first and run them failing, then the walker (probe-first); disagreements go to the parent.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none beyond the feature's (size, `problem.md`) | parent | resolved | Low |
