---
loop: 97
branch: dev
---

# Rust: dispatch-mix error names a percentage; percentage tests with optional and string fields

**Task**: AZ-3511_parity_percent_rust_assess
**Name**: Rust: dispatch-mix error names a percentage; percentage tests with optional and string fields
**Description**: Rust UnpackError::MixedParity says which setting is a percentage, and Rust tests the optional and string field cases.
**Complexity**: 3 points
**Dependencies**: None (AZ-3499 to AZ-3509 done)
**Component**: Rust package (std and no_std)
**Tracker**: AZ-3511
**Epic**: none

## Problem

The feature assessment of loop 97 (`_docs/loops/loop97/assessment97.md`) found that no package test puts a percentage scheme through a message whose length varies by an optional field, or through a string field read after the repair, although scenario S12 promised both. The owner also decided (2026-11-01, D4) that the Rust dispatch-mix error must not read "25 and 25" for a percentage and a count of the same number.

## Outcome

- A refused dispatch mix in Rust says which of the two settings is a percentage.
- Every package named here proves both cases with a test.

## Scope

### Included
- `UnpackError::MixedParity` gains `first_percent` and `other_percent`; the text names "percent" and "parity bytes"; every use and test of the variant follows (`rust/src`, `rust/tests`, README line is AZ-3509-style docs only if it quotes the variant).
- Tests for AC-1 and AC-2 in the std suite and, where `nostd` supports the fields, in the `nostd` ecc tests.
- `_docs/AGENT_GOTCHAS.md` keeps the line about exhaustive matches; add one sentence that `MixedParity` has the two flags.

### Excluded
- Any change to a wire format, the contract, the vectors, the ring or the README; any change to the percentage rules.
- The `rust-m33f` pins: the change is in the std error type only, so no pin moves; run the embedded stage to prove it.

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
Then the error is `UnpackError::MixedParity { first: 25, other: 25, first_percent: true, other_percent: false }` (and the reverse order the reverse flags), its text says "25 percent" and "25 parity bytes", and every pattern on `MixedParity` in the repo is updated

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

- Tests only; the Rust change is the one public error type edit; run the package's full suite and every reader of a shared shape before the commit (`_docs/AGENT_GOTCHAS.md`).
- Percentage 0 is a scheme without parity; this task does not change that rule.

## Risks & Mitigation

**Risk 1: A scheme with an optional field needs the package's `when`/flag machinery**
- *Risk*: the test scheme is awkward to build in one language.
- *Mitigation*: use the smallest scheme the package's existing tests already build (an optional field behind a flag byte).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Rust `MixedParity` gains two fields: a public error type changes | owner decision 2026-11-01 (D4, option B); breaks exhaustive patterns that name all fields | accepted-risk | Medium |
