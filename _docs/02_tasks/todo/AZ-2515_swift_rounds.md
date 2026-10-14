---
loop: 26
branch: dev
---

# Swift rounds and counted kinds: repeat, times, sized, two-bit slots, bits, packed

**Task**: AZ-2515_swift_rounds
**Name**: Swift rounds and counted kinds: repeat, times, sized, two-bit slots, bits, packed
**Description**: Swift packs and unpacks `repeat`, `times`, `sized`, two-bit slots, `bits` and `packed` with the same bytes and refusals as TypeScript.
**Complexity**: 5 points
**Dependencies**: AZ-2514
**Component**: swift
**Tracker**: AZ-2515
**Epic**: AZ-2223

## Problem

Round and counted kinds carry most of the parity rows of loops 13 to 23 (U3, U8, U11, U13, the split-form rules). Swift must match them or a Swift peer drops or misreads values.

Feature ACs and scenarios: `_docs/02_task_plans/swift-package/` (contributes to SW-2 (round kinds), SW-3, SW-12 (U11, empty array); scenario S8 in part).

## Outcome

- README examples for repeat, sized, two-bit slots, bits, packed and times pack and unpack with 0 mismatched bytes.
- A round unpacks to one entry per round, `nil` for a skipped round; aligned lists as TypeScript.

## Scope

### Included

- `repeat`, `times` (count from an earlier integer field), `sized`, `u2` slots, `bits`, `packed`; flags and `when` inside round bodies; round values as aligned lists (typed and map rows); the U11 no-value count refusal at top level and in the six nested positions; U3/U8 short optional lists; split-form loud pack; `times` longer list and count-0-with-values refusals; empty round body refused at construction.
- Owns (exclusive write): `swift/**`

### Excluded

- Round limits and budgets (AZ-2517)
- utf8/list/dict members inside rounds (AZ-2516)

## Acceptance Criteria

**AC-1: README round examples (SW-2)**
Given each README example for repeat, sized, two-bit slots, bits, packed, times
When packed and unpacked
Then the README hex both ways; mismatched bytes 0

**AC-2: Round rows (SW-3)**
Given the TypeScript round tests (`round-values`, `round-roundtrip`, `repeat-short-optional`, `times-longer-list`, `times-count-zero-with-values`, `flags-times-repeat-member`, `flags-under-split-bit`, `split-form-loud-pack`, `split-form-reference`, `empty-round-body`, `nested-round`, `u64-count`, `when-on-written-values`)
When ported to Swift
Then same hex or same refusal as TypeScript; disagreements 0

**AC-3: No-value count (SW-12, U11)**
Given a `bits`/`packed`/`sized` member with a value whose count is no value or behind a clear `when`, at top level and in the six nested positions (`loop22-novalue-count`, `loop23-novalue-nested`)
When packed
Then refused naming the member and the count; a `nil` array is no value, an empty array is 0 items (count 0 written)

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-1 | README round table | README hex |
| AC-2 | ported round rows | TypeScript outcome |
| AC-3 | U11 grid, `nil` vs empty array | refused / count 0 |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-2 | ring kinds `roundflags`, `roundwhen` (AZ-2522) | Swift in the ring | unpacks | — |

## Constraints

- Swift copies TypeScript at HEAD row for row (loop 26 fit decision 4); where TypeScript is a documented exception (U6 bigint `times` split) Swift follows the others (C#, Python, Rust, Java, Go). The D1b rows stay as documented: Swift copies TypeScript. A disagreement found while porting is reported to the parent, not decided inside the task (probe-first).
- ADR-001: hand-written walker, no generator, no import or wrapper of another package. Standard library only in the walker. Unsafe flags 0, C targets 0.
- Local runs are `swift test` at the repository root on the owner's Mac (Swift 6.3.3); Linux runs use `swift:6`. No language feature newer than Swift 5.9.
- Errors are thrown as the typed `PackbinError`; no trap escapes `pack`, `unpack` or scheme construction on any input. A `times` count is a wire integer up to u64: its conversion to a Swift length, the round count times the body width, and the slot offsets use checked arithmetic (a count above `Int.max` throws, it does not trap).

## Risks & Mitigation

**Risk 1: Rounds are the largest surface**
- *Risk*: The TypeScript round code is about 600 lines with many rules.
- *Mitigation*: Port test files first and run them failing, then the walker (probe-first); disagreements go to the parent. The Go round code (`go/`) is a second reference for structure, not for outcomes.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none beyond the feature's (traps, size, `problem.md`) | parent | resolved | Low |
