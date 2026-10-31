---
loop: 97
branch: dev
---

# Percentage tests with optional and string fields in Go, Swift and C++

**Task**: AZ-3513_parity_percent_tests_goswcpp
**Name**: Percentage tests with optional and string fields in Go, Swift and C++
**Description**: Tests of a percentage scheme with an optional field and a string field, and of the mix error, in three packages.
**Complexity**: 3 points
**Dependencies**: None (AZ-3499 to AZ-3509 done)
**Component**: Go, Swift and C++ packages
**Tracker**: AZ-3513
**Epic**: none

## Problem

The feature assessment of loop 97 (`_docs/loops/loop97/assessment97.md`) found that no package test puts a percentage scheme through a message whose length varies by an optional field, or through a string field read after the repair, although scenario S12 promised both. The same applies to the mix error of D4: these packages must show their refusal tells a percentage from a count (C++ shows 256 + p).

## Outcome

- Go, Swift and C++ each prove the optional-field and string-field cases and the mix error.
- Every package named here proves both cases with a test.

## Scope

### Included
- New test cases (a new test file each) in `go`, `swift/Tests`, `cpp/tests/core`.
- C++: a bytes field where `PACKBIN_NO_TEXT` is set; keep each file under 500 lines.
- Source changes only if a test finds a real defect (then report it; do not hide it).

### Excluded
- Any change to a wire format, the contract, the vectors, the ring or the README; any change to the percentage rules.
- Python, TypeScript, C#, Java, Rust (other tasks).

## Acceptance Criteria

Wording and figures: `_docs/02_task_plans/parity-percent/acceptance_criteria.md` AC-17 to AC-19.

**AC-1: Optional field under 25 %** (AC-17, S12b)
Given a scheme with an optional field under 25 %
When one message with the field (13 clear bytes) and one without (10 clear bytes) are packed and unpacked
Then they are 17 and 13 bytes long (4 and 3 parity bytes) and both round trip

**AC-2: String field under 25 %** (AC-18, S12c)
Given a scheme with a string field under 25 %
When one byte inside the string is wrong and the limit repairs it
Then the string is the original; in a build without compact text a bytes field behaves the same

**AC-3: The mix error tells a percentage from a count** (AC-19, D4)
Given handlers of 25 percent and of a count of 25
When one unpack call is built with both
Then it is refused and the error text or fields tell which setting is the percentage

## Non-Functional Requirements

**Compatibility**
- No byte on the wire changes; the old tests pass unchanged.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | optional-field scheme at 25 %, two messages | lengths 17 and 13, round trips |
| AC-2 | string (or bytes) field at 25 %, one wrong byte | original string |
| AC-3 | dispatch mix of 25 percent and count 25 | refused; the error tells which is the percentage |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 to AC-3 | the package's own suite | full suite | green, old tests unchanged | Compatibility |

## Constraints

- Tests only; run the package's full suite and every reader of a shared shape before the commit (`_docs/AGENT_GOTCHAS.md`).
- Percentage 0 is a scheme without parity; this task does not change that rule.

## Risks & Mitigation

**Risk 1: A scheme with an optional field needs the package's `when`/flag machinery**
- *Risk*: the test scheme is awkward to build in one language.
- *Mitigation*: use the smallest scheme the package's existing tests already build (an optional field behind a flag byte).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Rust `MixedParity` gains two fields: a public error type changes | owner decision 2026-11-01 (D4, option B); breaks exhaustive patterns that name all fields | accepted-risk | Medium |
