---
loop: 26
branch: dev
---

# README Swift section and the eight-language wording

**Task**: AZ-2524_swift_readme
**Name**: README Swift section and the eight-language wording
**Description**: The README shows Swift install and use; the example runs in CI and prints the README hex.
**Complexity**: 2 points
**Dependencies**: AZ-2520, AZ-2523
**Component**: swift
**Tracker**: AZ-2524
**Epic**: AZ-2223

## Problem

Swift users need install and usage text; the README's language lists name seven.

Feature ACs and scenarios: `_docs/02_task_plans/swift-package/` (owns SW-13; no scenario owned).

## Outcome

- A Swift section (install with `.package(url: "https://github.com/zxsanny/packbin", from: "X.Y.Z")`, typed and map pack/unpack example, session note, `swift-crypto` linked on non-Apple platforms only) and Swift in the supported-languages, data-type, untrusted-input and limits lists.
- The README example is a Swift test holding the same code, whose printed hex is the README hex.

## Scope

### Included

- README edits; the README example test under `swift/Tests/PackbinTests/`; architecture.md components list; the Swift rows in interaction-risks.md; Swift in the Consumers line of `contracts/library/pack-session.md`.
- Owns (exclusive write): `README.md`, the README example test file in `swift/Tests/PackbinTests/`, `_docs/02_document/architecture.md`, `_docs/02_document/interaction-risks.md` (Swift rows), `_docs/02_document/contracts/library/pack-session.md` (Consumers line)

### Excluded

- ADR text and `module-layout.md` (AZ-2523)
- `components/08_swift_package/description.md` (written at decompose 1.5; the exact public names live in the package docs)

## Acceptance Criteria

**AC-1: Example runs (SW-13)**
Given the README Swift example
When `swift test` runs its test (in the Swift suite, AZ-2521)
Then the printed output equals the README hex; mismatched bytes 0

**AC-2: Lists name Swift (SW-13)**
Given README supported languages, the data-type table, Untrusted input and Limits to keep in mind
When read
Then each names Swift where Swift has the behavior; the install line uses `.package(url:from:)` and names no Swift tag

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-1 | README example test | output matches |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-1 | Swift suite (AZ-2521) | `swift test` | passes | SW-13 |

## Constraints

- The README states the Swift differences decided in loop 26, as the parent lists them from the batch reports (for example: `nil` is no value and an empty array 0 items; `[UInt8]` is a byte run, never a list; map value types accepted and refused; the limits setting and its defaults; a `PackSession` is for one task at a time; dict keys in UTF-8 byte order; `swift-crypto` is fetched on every platform and linked only off Apple platforms; no `swift/vX.Y.Z` tag, ADR-005).
- Swift copies TypeScript at HEAD row for row (loop 26 fit decision 4); the README does not describe a Swift behavior the tests do not pin.
- The example compiles with the toolchains the manifest admits (no language feature newer than Swift 5.9).

## Risks & Mitigation

**Risk 1: README drift**
- *Risk*: The README example and the test can diverge.
- *Mitigation*: The test holds the same code text; the reviewer compares them.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The `pack-session.md` Consumers line never gained Go in loop 24; this task adds Swift | owner ruling 2026-10-14: the same edit adds Go and Swift | resolved | Low |
