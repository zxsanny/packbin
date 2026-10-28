---
loop: 79
branch: dev
---

# Rust: warning-free test builds of every feature set

**Task**: AZ-3357_rust_test_build_warnings
**Name**: Rust test-build warnings
**Description**: The Rust test builds print no warning in any feature set, and the suite builds every test target of each feature set so a missing feature gate fails CI.
**Complexity**: 2 points
**Dependencies**: None
**Component**: Rust package (`rust/`), suite runner (`.github/workflows/run-suite.sh`)
**Tracker**: AZ-3357
**Epic**: none

## Problem

On HEAD `cb6759b` with Rust 1.98, `cargo test --no-default-features --features frame --no-run` (and `text,ecc,frame`) prints 3 warnings for 4 items: `test_previous_is_zero` and `test_material` (`rust/src/nostd/frame/mod.rs:363`), `hmac_sha256_of` (`rust/src/session_core/hkdf.rs:76`), `block_of` (`rust/src/session_core/pad.rs:89`). Each is `#[cfg(test)]`, but its callers are built only with `std` (`rust/src/lib.rs:57-64`). The all-features build warns about `pub use super::from_hex;` (`rust/tests/nostd_support/hostile.rs:137`) in the 9 nostd test crates that do not use it, and the default build about `take` (`rust/src/session_core/counters.rs:18`), whose callers need `frame` (found during implementation). `run-suite.sh` runs each no-std set against named targets only (`--test <name>`), so a test file that lacks its feature gate compiles in no CI run (loop 76: 22 files, found by hand).

## Outcome

- 0 warnings in the test builds of all 9 sets (7 no-std sets, default, all-features).
- The suite (CI `suites` job and step 11, both through `run-suite.sh rust`) builds every test target of each set and fails on a build error or a warning, naming the set.

## Scope

### Included

- The 4 helpers and `counters::take` carry the cfg of their callers; the re-export goes and its 3 users import `from_hex` from `nostd_support`.
- `run-suite.sh` Rust branch: `cargo test --no-run` over all targets for none, `alloc`, `text`, `ecc`, `text,ecc`, `frame`, `text,ecc,frame` (with `--no-default-features`), default and `--all-features`; a failed build or a `warning:` line fails the suite with the set's name.
- `run-suite.test.sh`: the new commands, the command count, and a stand-in `cargo` that prints `warning:`.

### Excluded

- Clippy (no clippy in CI), rustfmt of the crate, any change to library behavior or to the test bodies.
- The embedded Rust stage (`rust/embedded/`).

## Acceptance Criteria

Loop ACs: `_docs/02_task_plans/ring-and-test-build-fixes/acceptance_criteria.md` AC-8 to AC-11, AC-12 (Rust part), AC-13, AC-14.

**AC-8: No warnings**
Given Rust 1.98
When `cargo test --no-run` runs for `--no-default-features --features frame`, `--no-default-features --features text,ecc,frame`, the default set and `--all-features`
Then each prints 0 `warning:` lines (was 3, 3, 1, 1)

**AC-9: The suite builds every set and refuses warnings**
Given `run-suite.sh rust`
When it runs
Then it builds all test targets of the 9 sets with `--no-run`; a build that fails or prints `warning:` fails the suite with a message naming the set; `run-suite.test.sh` checks the 9 commands and the stand-in that prints `warning:` (exit 1, set named)

**AC-10: The defect class of loop 76 is caught**
Given a scratch copy where one std test file has lost its `#![cfg(feature = "std")]`
When the new step runs
Then it fails on the `none` set

**AC-11: Test results unchanged**
Given HEAD and the change
When `run-suite.sh rust` runs
Then every `cargo test` command reports the same passed count as on HEAD, 0 failed

## Non-Functional Requirements

**Performance**
- The step 11 `rust` stage grows by no more than 60 s over its figure on HEAD at the same load (loop AC-12; measured on this Mac: 1 to 3 s for each no-std set with the crate built).

**Compatibility**
- The check holds for the toolchain of the `rust:1.98` image that CI and step 11 use; the host default 1.79 is not a target.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-9 | `run-suite.test.sh` with the stand-in `cargo` | 9 `--no-run` commands logged; a `warning:` line fails with the set named |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-8 | Rust 1.98 | the 4 builds | 0 `warning:` lines each | Compatibility |
| AC-10 | scratch copy, gate removed from one std test file | `run-suite.sh rust` | fails on `none` | — |
| AC-11 | `docker compose -f docker-compose.test.yml run --rm rust` on HEAD and after | passed counts per command | equal, 0 failed | Performance |

## Constraints

- `run-suite.sh` is the one place both CI and step 11 run Rust (`docker-compose.test.yml` service `rust`); no second runner.
- A CI step added goes into `scripts/loop-tests.sh` in the same commit (LESSONS, loop 78): here none is needed, since the `rust` stage runs `run-suite.sh rust`.

## Risks & Mitigation

**Risk 1: A toolchain bump adds a lint**
- *Risk*: a later `rust:1.99` image warns on code that 1.98 accepts and the suite goes red.
- *Mitigation*: the image is pinned; the failure names the set, and the bump fixes the warning in the same change.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Seven more builds in the CI Rust job | measured 1 to 3 s each; AC-12 bound | open | Low |
| A worker running `cargo fmt` on the crate rewrites files it does not own | worker prompt: rustfmt single files only (AGENT_GOTCHAS) | open | Low |
