---
loop: 87
branch: dev
---

# Rust test targets: cargo clippy --lib --tests at 0 warnings

**Task**: AZ-3430_rust_test_targets_clippy_clean
**Name**: Rust test targets: cargo clippy --lib --tests at 0 warnings
**Description**: The 6 clippy sites in Rust test code are fixed lint by lint, with no behavior change.
**Complexity**: 2 points
**Dependencies**: none
**Component**: rust (`rust/src/text_vectors_tests.rs`, `rust/tests`)
**Tracker**: AZ-3430
**Epic**: none

## Problem

`cargo clippy --lib --tests --features text,ecc,frame` reports 6 distinct warnings on HEAD d088ba2 (toolchain 1.97.1): `type_complexity` in `src/text_vectors_tests.rs:243`; `manual_is_multiple_of` in `tests/nostd_bits_when_tests.rs:215`, `tests/nostd_rounds_tests.rs:141`, `tests/nostd_text_differential_tests.rs:151` and the shared `tests/nostd_support/random.rs:19`; `err_expect` in `tests/nostd_hostile_tests.rs:157`. No CI job runs clippy.

## Outcome

- The lib and its test targets build with 0 clippy warnings under three feature sets.
- Library code, fixtures and embedded images are unchanged.

## Scope

### Included
- The 6 sites in `_docs/02_task_plans/rust-clippy-test-targets-cleanup/problem.md`. `type_complexity`: a `type` alias in the test file. `manual_is_multiple_of`: `is_multiple_of`. `err_expect`: `expect_err`.

### Excluded
- A CI clippy job; any change under `rust/src` other than `text_vectors_tests.rs`; `#[allow(clippy::...)]`.

## Acceptance Criteria

**AC-1: Zero warnings**
Given `rust/` on HEAD with 6 distinct warnings
When `cargo clippy --lib --tests` runs with `--features text,ecc,frame`, default features, and `--no-default-features`
Then each ends with 0 warnings

**AC-2: No behavior change**
Given the same sources
When `cargo test --features text,ecc,frame` runs
Then the pass count equals HEAD (876 passed, 0 failed, 1 ignored)

**AC-3: Only lint-driven edits**
Given the diff
When read
Then it adds no `allow(clippy::...)` and touches no file under `rust/src` except `text_vectors_tests.rs`

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | three clippy runs | 0 warnings |
| AC-2 | Rust suite | as HEAD |

## Blackbox Tests

None: test-code hygiene, no product behavior.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| `is_multiple_of` needs Rust 1.89; no MSRV is pinned | none stated | open | Low |
| The `random.rs` coin flip must stay the same draw | AC-2 | open | Low |
