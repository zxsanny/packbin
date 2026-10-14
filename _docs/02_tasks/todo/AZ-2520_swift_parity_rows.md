---
loop: 26
branch: dev
---

# Swift parity rows: TypeScript's U-row and AC-3 tables

**Task**: AZ-2520_swift_parity_rows
**Name**: Swift parity rows: TypeScript's U-row and AC-3 tables
**Description**: Swift pins every cross-package parity row TypeScript pins (U1 to U26 that apply, AC-3 tables, the loop 25 D1 and D7 probe rows).
**Complexity**: 3 points
**Dependencies**: AZ-2519
**Component**: swift
**Tracker**: AZ-2520
**Epic**: AZ-2223

## Problem

Parity across loops 17 to 25 lives in TypeScript test tables and the reference docs; without them Swift can drift on rows no single-kind test covers.

Feature ACs and scenarios: `_docs/02_task_plans/swift-package/` (owns SW-3; no scenario owned).

## Outcome

- Every row of `loop20-parity-pins`, `loop21-parity-probes`, `loop23-bigint-count` (as the others for U6), `flags-when-member` AC-3 table, `flag-group-presence`, `bool-flag`, `fields`, `packbin` and `blackbox-tests-16-loop23-parity-rows.md` gives TypeScript's hex or refusal in Swift.
- The loop 25 probe rows D1 (empty anchored group) and D7 (split flag bit inside a false `when`) give TypeScript's rows (D1b A).
- U24 is C++ only and not ported; U25 is the negative-id check (AZ-2514); U26 A is the nested map (AZ-2516).

## Scope

### Included

- Swift test files porting those tables; a row list in the batch report naming any row Swift cannot express.
- Owns (exclusive write): `swift/**` (tests only; a walker fix found here is reported to the parent)

### Excluded

- Walker changes (reported to the parent and opened as a Bug, as AZ-2437)

## Acceptance Criteria

**AC-1: Parity tables (SW-3)**
Given the rows listed in Outcome
When run in Swift
Then hex mismatches 0; refusal-vs-bytes disagreements 0; every refusal names the field id (and the count where there is one)

**AC-2: U6 follows the others (SW-3)**
Given a `times` count given as an integer above 2^53
When packed in Swift
Then the outcome of C#, Python, Rust, Java and Go (refused or packed as they do), not TypeScript's split

**AC-3: Loop 25 probe rows (SW-3)**
Given the D1 row `Flags(0, Group(0,"mark")), U8(0,"n")` and the D7 split-bit rows (pack `0101030506` for k=1 and `01000306` for k=0, unpack `{k:0, b:6}`, repack `01000206`)
When packed and unpacked in Swift
Then TypeScript's hex and refusals (`batch_02_loop25_report.md` tables); a `when` on the mark refused or built as TypeScript

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-1 | ported parity rows | TypeScript outcome |
| AC-2 | U6 row | the others' outcome |
| AC-3 | D1, D7 rows | TypeScript outcome |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-1 | ring (AZ-2522) | Swift handoffs | pass | — |

## Constraints

- Swift copies TypeScript at HEAD row for row (loop 26 fit decision 4); where TypeScript is a documented exception (U6 bigint `times` split) Swift follows the others (C#, Python, Rust, Java, Go). The D1b rows (empty anchored group, `when` on a mark) stay as documented: Swift copies TypeScript, not Rust or Java. A disagreement found while porting is reported to the parent, not decided inside the task (probe-first).
- ADR-001: no generator, no other package imported; TypeScript outcomes are copied into Swift tables, not computed by running TypeScript from the Swift tests.
- Local runs are `swift test` at the repository root on the owner's Mac (Swift 6.3.3); Linux runs use `swift:6`. No language feature newer than Swift 5.9.
- Errors are thrown as the typed `PackbinError`; no trap escapes `pack`, `unpack` or scheme construction on any input.

- From the batch reports (loop 26): `_docs/02_task_plans/swift-package/parity_differences.md` lists every documented difference; AC-2 and the README pin them. Two open probes: (a) U11 for a nested row under flags: Swift reads the pending count from the nested map with the nested row's own written values, Go reads it from the row around; probe Go and report; (b) the zero-width element asymmetry (pack builds, unpack refuses) copied from TypeScript.

## Risks & Mitigation

**Risk 1: A real disagreement**
- *Risk*: Swift may follow the spec text where TypeScript is the outlier.
- *Mitigation*: Report to the parent; the owner decides (lesson 2026-10-11: one cross-package table in front of the owner).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none beyond the feature's (traps, size, `problem.md`) | parent | resolved | Low |
