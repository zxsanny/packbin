---
loop: 76
branch: dev
---

# Rust tests compile in every feature set

**Task**: AZ-3331_rust_feature_set_tests
**Name**: The Rust test targets build in each of the package's feature sets
**Description**: `cargo test --no-default-features --features <set> --no-run` succeeds for every set the crate documents, not only the default.
**Complexity**: 3 points
**Dependencies**: None
**Component**: 04_rust_package
**Tracker**: AZ-3331
**Epic**: AZ-2645

Item 3 of `_docs/02_task_plans/hygiene-after-frame-ports/problem.md`.

## Problem

Seven of the eight feature sets (none, `alloc`, `text`, `ecc`, `text,ecc`, `frame`, `text,ecc,frame`; the default builds) do not compile their tests. Two causes, both in test code. First, the library's own test modules `session_core/sha256.rs:190-191` and `session_core/hkdf.rs:84-92` use `String`, `Vec` and `format!` where `extern crate alloc` is absent (6 errors in the `frame` set, which stops cargo at that target). Second, 22 of the 38 files in `rust/tests/` use the std API and carry no `#![cfg(feature = "std")]`, and `nostd_dict_tests.rs` is gated on `text` alone but uses `nostd_support::random`, which needs `std`. The suite never hits this because `.github/workflows/run-suite.sh` names each no-std target with `--test <name>`; a plain `cargo test` in a non-default set does. Proved on a scratch copy of `HEAD`: with the changes below all 8 sets exit 0.

## Outcome

- All 8 feature sets compile their test targets (`--no-run`) with Cargo 1.79 and, for `frame`, with the Docker toolchain.
- The tests that run in the `frame` set pass. The default suite and the embedded figures do not move.

## Scope

### Included
- An inner `#![cfg(feature = "std")]` on the 22 std-only files of `rust/tests/*.rs` that carry no inner `#![cfg]` (the 24 files without one, less `nostd_docs_tests.rs` and `nostd_flat_tests.rs`); the gate of `nostd_dict_tests.rs` widened to `all(feature = "std", feature = "text")`.
- `#[cfg(all(test, not(feature = "std")))] extern crate std;` in `rust/src/lib.rs` and a `#[cfg(not(feature = "std"))] use std::{format, string::String, vec::Vec};` in the test modules of `session_core/sha256.rs` and `hkdf.rs`.

### Excluded
- Any non-test code of `session_core/`, `nostd/` or `ecc_core.rs` (the embedded stage compiles them; a figure must not move); `required-features` entries in `Cargo.toml` (23 manifest lines against the repo's own inner-attribute pattern, 14 files already); `rust/Cargo.toml` features; the run-suite commands.

## Acceptance Criteria

**AC-1: Every feature set compiles its tests**
Given `cd rust && cargo test --no-default-features --features <set> --no-run` for the sets `(none)`, `alloc`, `text`, `ecc`, `text,ecc`, `frame`, `text,ecc,frame`, and the default set
When each runs with Cargo 1.79; the `frame` set also with the toolchain of `docker compose -f docker-compose.test.yml run --rm rust`
Then all 8 exit 0 (7 of the 8 fail today)

**AC-2: The tests that run, pass**
Given the `frame` set
When `cargo test --no-default-features --features frame --no-fail-fast` runs in the checkout
Then every test that runs passes; the count is recorded in the report

**AC-3: Nothing else moves**
Given the default-feature suite and the Rust embedded stage
When both run after the change
Then the default test counts equal a run on `HEAD` of this loop, and every `rust-m33f` pin of `rust/embedded/limits-m33f.txt` and the Cortex-M4F figures are unchanged

**AC-4: File size**
Given the changed files
When their lines are counted
Then none passes 500 lines that did not before

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | eight `--no-run` builds | exit 0 |
| AC-2 | the `frame` set run | all pass, count recorded |
| AC-3 | default suite and embedded stage | counts and pins equal |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | `docker compose -f docker-compose.test.yml run --rm rust` and `rust-embedded` | the CI stages | PASS, figures equal the pins | — |

## Constraints

- Use `CARGO_TARGET_DIR` under the scratchpad for the matrix builds (a shared `rust/target` is not needed). Run `rustfmt` on single files only, then `git checkout -- rust/src/walk/text_tables.rs` (the `#[path]` module makes rustfmt reformat that generated file).
- A worker runs no `git add`, `rm`, `mv`, `restore --staged`, `stash`, `checkout` (except that one restore), `reset` or `clean`; stdin from `/dev/null`; a time limit on every cargo run (`perl -e 'alarm N; exec @ARGV' --`).
- `nostd_docs_tests.rs` reads `README.md` from the checkout; it fails in a tree copy without it (not a defect).

## Risks & Mitigation

**Risk 1: a set fails for a reason other than a gate or an import**
- *Risk*: a test file needs more than `std` (a feature pair).
- *Mitigation*: widen that file's gate as `nostd_dict_tests.rs` does; a product-code cause gets its own task.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The `session_core` test modules sit in files the embedded stage compiles | `#[cfg(test)]` only; AC-3 runs the stage | open | Medium |
