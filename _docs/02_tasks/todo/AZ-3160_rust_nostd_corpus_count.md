---
loop: 58
branch: dev
---

# Rust nostd corpus count by an independent rule

**Task**: AZ-3160_rust_nostd_corpus_count
**Name**: Rust nostd corpus count by an independent rule
**Description**: The nostd corpus test derives its expected input count from corpus.txt by a rule other than the loader's filter.
**Complexity**: 2 points
**Dependencies**: None
**Component**: `rust/tests/nostd_hostile_tests.rs`, `rust/tests/nostd_support/hostile.rs`
**Tracker**: AZ-3160
**Epic**: AZ-2645

## Problem

The test counts `corpus.txt` lines with the loader's own filter (`!trim().is_empty() && !starts_with('#')`), so a wrong filter is wrong in both and the count still matches.

## Outcome

- The count is derived by a separate rule and fails naming expected and loaded counts.

## Scope

### Included
- Test code in the files named under Component.

### Excluded
- Any product code, `fixtures/` in the real tree, the other packages' loaders.

## Acceptance Criteria

**AC-1: Independent count** — Given a loader whose filter also drops lines starting with a letter (broken copy), When the nostd corpus test runs, Then it fails naming the expected and loaded counts; on the unmodified loader it passes.

**AC-2: Extra line** — Given a copy of `corpus.txt` with one extra input line, When the test runs, Then it passes with the new count.

## Non-Functional Requirements

**Compatibility**: test code only; Cortex-M4F flash 8,032 B and the stack figures stay as in loop 57.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | broken copy of the loader filter under the scratchpad | fails naming both counts |
| AC-2 | `cargo test` on the real tree and on a corpus copy | passes |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Test-only change | no edit under `cpp/src`, `cpp/include` or any library source | open | Low |
