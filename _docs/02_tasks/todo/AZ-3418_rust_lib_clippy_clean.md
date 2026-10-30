---
loop: 86
branch: dev
---

# Rust lib: cargo clippy --lib at 0 warnings

**Task**: AZ-3418_rust_lib_clippy_clean
**Name**: Rust lib: cargo clippy --lib at 0 warnings
**Description**: The 11 clippy warnings in `rust/src` are fixed lint by lint, with no behavior change.
**Complexity**: 2 points
**Dependencies**: none
**Component**: rust (`rust/src/walk/text`, `field`, `scheme`, `nostd/text`)
**Tracker**: AZ-3418
**Epic**: none

## Problem

`cargo clippy --lib --features text,ecc,frame` reports 11 warnings on HEAD 02ffcef (toolchain 1.97.1), none in `session_core`: `int_plus_one` and 2 `unnecessary_map_or` in `walk/text/encode.rs`, `needless_range_loop` in `walk/text.rs`, `replace_box` in `field/mod.rs`, 4 `type_complexity` and 1 `redundant_closure` in `scheme`, `duplicate_mod` in `nostd/text/mod.rs`. No CI job runs clippy.

## Outcome

- The lib builds with 0 clippy warnings under three feature sets.
- Behavior, fixtures and embedded images are unchanged.

## Scope

### Included
- The 11 sites in `_docs/02_task_plans/rust-clippy-lib-cleanup/problem.md`. `type_complexity`: one pair of type aliases for the getter and setter boxes, shared by `scheme/mod.rs` and `scheme/bound.rs`. `duplicate_mod`: `#[allow(clippy::duplicate_mod)]` with a one-line comment (the shared table is deliberate).

### Excluded
- A CI clippy job; clippy on test targets (`--all-targets` warns in `nostd_*` tests); `session_core` (clean).

## Acceptance Criteria

**AC-1: Zero warnings**
Given `rust/` on HEAD with 11 warnings
When `cargo clippy --lib` runs with `--features text,ecc,frame`, default features, and `--no-default-features`
Then each ends with 0 warnings

**AC-2: No behavior change**
Given the same sources
When `cargo test --features text,ecc,frame` and `scripts/loop-tests.sh --all --only ring` run
Then the pass count equals HEAD, 0 failed, ring 64 pairs 0 mismatched

**AC-3: Only lint-driven edits**
Given the diff
When read
Then the only new `allow(clippy::...)` is `duplicate_mod` with its comment

**AC-4: Embedded untouched**
Given the diff
When its files are checked against crate cfgs
Then `field`, `scheme`, `walk` are `std`-only and `nostd/text/mod.rs` changes by an attribute only

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | three clippy runs | 0 warnings |
| AC-2 | Rust suite | as HEAD |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | ring drivers | `loop-tests.sh --all --only ring` | PASS | none |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The `encode.rs` tie-break and `field` big-endian wrap rewrites must keep their results | AC-2 | open | Low |
