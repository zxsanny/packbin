---
loop: 89
branch: dev
---

# Rust clippy gate in the CI Rust suite

**Task**: AZ-3443_rust_clippy_ci_gate
**Name**: Rust clippy gate in the CI Rust suite
**Description**: The Rust suite fails when clippy warns on the lib or any test target of the nine feature sets, so the 0 warnings of loops 86 and 87 hold.
**Complexity**: 3 points
**Dependencies**: None
**Component**: ci (`.github/workflows/run-suite.sh`, `docker-compose.test.yml` service `rust`)
**Tracker**: AZ-3443
**Epic**: none

## Problem

`cargo clippy --lib --tests` is at 0 warnings on all nine feature sets of the Rust test build (HEAD f21b4d7, Rust 1.97.1 and 1.99.1), but no CI job runs clippy, so the next lint lands unseen. The Rust suite already fails on any compiler warning in those nine sets (AZ-3357); clippy is not part of it, and the `rust:1.98` suite image has no clippy component. Loops 86 and 87 left the gate out; the owner asked for it at the loop 89 intake.

## Outcome

- A clippy warning in the lib or a test target fails the Rust suite, in CI and on the owner's Mac (same compose service).
- A missing clippy component fails the suite instead of skipping the check.
- The nine sets, the failure messages and the report row keep the shape AZ-3357 gave them.

## Scope

### Included
- Clippy on the lib and every test target (`--lib --tests`) of the nine feature sets: `none`, `alloc`, `text`, `ecc`, `text,ecc`, `frame`, `text,ecc,frame`, default, all features.
- Obtaining the clippy component for the `rust:1.98` image at run time, with a failure that names clippy when it cannot.
- Shell-test cases for a clippy warning and for a missing component, in a script of their own (`run-suite.test.sh` is 470 lines; cap 500).

### Excluded
- Any change under `rust/src`; `#[allow(clippy::...)]`; pedantic or nursery lint groups; `--all-targets` (the crate has no examples or benches).
- The no-std probe crate under `rust/embedded`.
- A fix for lints that a later toolchain bump adds (the bump change owns them).

## Acceptance Criteria

**AC-1: Green on HEAD**
Given HEAD with 0 clippy warnings in each of the nine sets
When the Rust suite runs in the `rust:1.98` container
Then clippy has run on 9 of 9 sets (lib and test targets), 0 warnings, and the suite is green

**AC-2: A warning fails the suite**
Given one added clippy warning (for example `x % 2 == 0` on an unsigned integer) in a test file or the lib
When the Rust suite runs
Then it fails in the set that builds that file, the output names the feature set and quotes the warning line, no later set runs, and the report row names the set; a rustc warning fails it the same way as before AZ-3357

**AC-3: Missing component fails**
Given the clippy component cannot be installed or run
When the Rust suite runs
Then it fails with a message naming clippy, and the check is not counted as passed

**AC-4: Wall time**
Given the first CI run after the push
When the Rust job time is read against the previous green run
Then the job took at most 120 s more

**AC-5: No regression**
Given the same sources
When the Rust suite and `run-suite.test.sh` run
Then the `cargo test` counts equal HEAD and the shell tests pass, with a case for AC-2 and one for AC-3

**AC-6: Only the gate changes**
Given the diff
When read
Then it touches nothing under `rust/src` or `fixtures`, and adds no `allow(clippy::...)`

**AC-7: File size**
Given the files the diff touches
When their lines are counted
Then none is over 500 lines

## Non-Functional Requirements

**Performance**
- AC-4: at most 120 s added to the Rust CI job.

**Reliability**
- A network failure while getting the component fails the suite with a message naming clippy (AC-3).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-2 | the suite script with a stubbed clippy that warns on set `frame` | exit non-zero; `frame` named; warning line shown; no later set run; report row names the set |
| AC-2 | the suite script with a stubbed clippy that fails on set `alloc` | exit non-zero; `alloc` named |
| AC-3 | the suite script with clippy unavailable | exit non-zero; message names clippy |
| AC-1, AC-5 | the suite script with stubs that pass | the nine sets run in order, step count as expected |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | HEAD, `docker compose -f docker-compose.test.yml run --rm rust` | clippy ran on 9 of 9 sets | green, 0 warnings, log lists nine clippy runs | — |
| AC-2 | the same run with `x % 2 == 0` on a `u32` in a test file (reverted after) | the gate | fails; names the set and the `manual_is_multiple_of` line | — |
| AC-4 | first CI run after the push | the Rust job time | previous green run + at most 120 s | AC-4 |

## Constraints

- The new cases of the shell test go in a script of their own (card 1, option A): `run-suite.test.sh` is 470 lines against the 500 soft cap.
- One pass of the nine sets, not two: the test build of AZ-3357 and the clippy check must not compile the sets twice (AC-4).

## Risks & Mitigation

**Risk 1: A toolchain bump adds lints**
- *Risk*: The `rust:1.98` tag or `RING_RUST` moves to a version with new clippy lints and the gate turns red.
- *Mitigation*: The bump change fixes or justifies each lint; no `allow` hides one (flagged concern).

**Risk 2: The component download fails in CI**
- *Risk*: A registry or network failure fails the Rust job for a reason unrelated to the code.
- *Mitigation*: The failure message names clippy and the download, so it is not read as a lint (AC-3).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The owner declined a CI clippy job in loops 86 and 87 | owner chose it at the loop 89 intake | resolved | Low |
| A toolchain bump can add clippy lints and turn the gate red | the bump change fixes or justifies each new lint; no `allow` | open | Medium |
| The `rust:1.98` image needs the clippy component at run time (network) | a missing component fails the suite, never skips | open | Low |
| The extra pass adds wall time to the slowest CI job | AC-4 bound; measured on the first CI run | open | Low |
| `run-suite.test.sh` is 470 lines (cap 500) | card 1: new cases in a script of their own | resolved | Low |
