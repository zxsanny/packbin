---
loop: 26
branch: dev
---

# Swift hostile vectors and the eighth package in the case checker

**Task**: AZ-2519_swift_hostile_vectors
**Name**: Swift hostile vectors and the eighth package in the case checker
**Description**: Swift replays all 65 hostile cases with the rule each refusal must give, and the case checker counts eight packages.
**Complexity**: 3 points
**Dependencies**: AZ-2517, AZ-2518
**Component**: swift
**Tracker**: AZ-2519
**Epic**: AZ-2223

## Problem

Every package proves its hostile outcomes against `fixtures/hostile/cases.txt`; the checker requires every pack section to name each package once (loop 26 fit decision 5). In Swift a hostile packet that reaches an unchecked index or sum traps and kills the host app, so the replay counts traps, not only wrong outcomes.

Feature ACs and scenarios: `_docs/02_task_plans/swift-package/` (owns SW-4; scenario S2 owned).

## Outcome

- All 65 cases pass in Swift with the outcome term and the refusal rule pinned (as the TypeScript `PACK_REFUSAL` table).
- `check-cases.sh` counts eight names, whole word; every pack section of `fixtures/hostile/README.md` names Swift in `Run by` or `Not run by`.

## Scope

### Included

- A Swift loader for all four stages (unpack with a 1 s guard each, construct, limit with the section's low limit, pack); the rule table and a self-test that a wrong rule entry fails; `check-cases.sh` package list (eight names) with whole-word matching; a `cases.test.sh` corruption case for the Swift name; the README sections.
- Owns (exclusive write): `swift/**` (loader test), `fixtures/hostile/check-cases.sh`, `fixtures/hostile/cases.test.sh`, `fixtures/hostile/README.md`

### Excluded

- New hostile cases
- The fuzz corpus `fixtures/hostile/fuzz/` (AZ-2517)

## Acceptance Criteria

**AC-1: All cases (SW-4, S2)**
Given the 65 cases of `cases.txt` (10 unpack, 2 limit, 15 construct, 38 pack at HEAD)
When the Swift loader runs them
Then each outcome is one of the listed terms; the refusal rule matches the table; traps and crashes 0; each unpack ≤ 1 s; a short case's error names the field, needed and left with no row

**AC-2: Wrong rule fails (SW-4)**
Given a deliberately wrong rule entry
When the loader self-test runs
Then it fails naming the case (as the AZ-2418 self-tests)

**AC-3: Checker counts eight (SW-4)**
Given the committed `README.md`, and copies with Swift missing, Swift twice, and a reason containing "SwiftUI"
When `check-cases.sh` and `cases.test.sh` run
Then the committed file passes; missing or doubled Swift fails; "SwiftUI" is not counted as Swift

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-1 | 65 cases | allowed outcome, 0 traps |
| AC-2 | wrong rule | fails |
| AC-3 | checker copies | pass/fail as stated |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-3 | scaffold job | `cases.test.sh` | passes | — |

## Constraints

- Swift copies TypeScript at HEAD row for row (loop 26 fit decision 4); where TypeScript is a documented exception (U6 bigint `times` split) Swift follows the others (C#, Python, Rust, Java, Go). A disagreement found while porting is reported to the parent, not decided inside the task (probe-first).
- A refused `limit` round is the `too_many` error kind (needed 0, left as in the cases): the loader accepts `too_many` (and `bad_value`) for `limit` cases. The section's low limit sets `maxRounds` only; the other limits keep their defaults.
- A trap ends the whole test process, so a trapping case shows as a crashed run, not a failed case: the loader names each case before running it so the crash log points at it.
- Local runs are `swift test` at the repository root on the owner's Mac (Swift 6.3.3); Linux runs use `swift:6`. No language feature newer than Swift 5.9.
- Errors are thrown as the typed `PackbinError`; no trap escapes `pack`, `unpack` or scheme construction on any input; every input-derived size and index uses checked or wrapping arithmetic.

## Risks & Mitigation

**Risk 1: Skips**
- *Risk*: A case Swift cannot express needs a `Not run by` reason.
- *Mitigation*: Swift's map form can write every row TypeScript writes; a skip is reported to the parent first.

**Risk 2: The 1 s guard cannot stop a hung call**
- *Risk*: Swift cannot cancel a synchronous `unpack` that loops; a guard only measures.
- *Mitigation*: Each unpack is timed and a case over 1 s fails; the CI job timeout bounds a true hang.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Swift traps on overflow, out-of-range index and force unwrap; one trapping case kills the run | AC-1 counts traps and crashes; the case is named before it runs | open | High |
