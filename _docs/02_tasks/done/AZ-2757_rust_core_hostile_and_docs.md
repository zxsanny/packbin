---
loop: 53
branch: dev
---
# Rust core: hostile corpus, differential proof, publish check and docs

**Task**: AZ-2757_rust_core_hostile_and_docs
**Name**: Rust core: hostile corpus, differential proof, publish check and docs
**Description**: The hostile corpus and fuzz corpora run through the core; the differential test is complete; the crate still publishes; the module layout, component description and README are updated.
**Complexity**: 3 points
**Dependencies**: AZ-2749, AZ-2751, AZ-2752, AZ-2753, AZ-2754, AZ-2755, AZ-2756
**Component**: rust (core)
**Tracker**: AZ-2757
**Epic**: AZ-2750

## Problem

AC-2 of the feature (no panic path from untrusted bytes, hostile corpus returns errors only) is proven only when the whole corpus runs through the core.

## Outcome

- Every case of `fixtures/hostile/cases.txt` and the fuzz corpora run on the core; the differential test covers every fixture file; `cargo publish --dry-run` passes with default features and the `no_std` build passes; documents name the new modules.

## Scope

### Included
- The runner that builds core schemes from the case text (card 2), the skip table with reasons, the publish check, `module-layout.md`, the Rust component description, the Rust README, the AGENT_GOTCHAS lines the work earned.

### Excluded
- New field kinds; the first `v*` tag (owner).

## Acceptance Criteria

**AC-1: Hostile corpus (R4, original AC-2)**
Given `fixtures/hostile/cases.txt` and the fuzz corpora
When the core replays every stage
Then each case returns the refusal its row names; a case the C++ runner skips is skipped with the same reason; none panics

**AC-2: Differential proof**
Given every fixture file (golden, text, ecc, hostile) and random rows
When std and core pack and unpack
Then bytes equal and values equal

**AC-3: Publish check**
Given the crate
When `cargo publish --dry-run` and a `--no-default-features` build run
Then both pass; the default build is unchanged

**AC-4: Documents**
Given the finished work
When module layout, the component description and the README are read
Then they name the `nostd` module, the features and the CI job

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | the replay runner on all stages | all refusals match |
| AC-2 | differential over files | equal |
| AC-3 | dry-run and feature build | pass |
| AC-4 | grep of the documents | names present |

## Constraints

- Wire bytes do not change (wire-stability policy); the std API and its tests are untouched.
- Fit decisions of `_docs/02_task_plans/rust-nostd-core/feature-description.md`: the caller's row is read and written through a `Row` trait by field id (card 1); a scheme is a plain `&[Field]` slice, so host tests can build it at runtime (card 2); any format change changes the std walker and the core walker in one task and the differential test covers both (card 4).
- No `unwrap`, `expect`, panicking index or unchecked arithmetic on a path reachable from untrusted bytes; lengths use checked or saturating operations.
- Source file length soft cap 500 lines; tests follow AAA; no verbose logs.


## Risks & Mitigation

**Risk 1: A corpus row that needs a dynamic scheme the core cannot express**
- *Mitigation*: the row is skipped with a stated reason, as the C++ runner does, never silently

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The first estimate of 5 points covered the whole feature; the slices sum to 34 points | owner (scope per loop) | accepted-risk | Medium |
