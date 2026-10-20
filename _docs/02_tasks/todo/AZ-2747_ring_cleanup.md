---
loop: 48
branch: dev
---

# Ring cleanup: comments and the ring-wiring.test.sh split

**Task**: AZ-2747_ring_cleanup
**Name**: Ring comments name `ring-lib.sh`; `ring-wiring.test.sh` split below the cap
**Description**: After AZ-2744 the runner and handoff live in `ring-lib.sh`; comments still name `language-pair.sh`, and `ring-wiring.test.sh` is exactly 500 lines.
**Complexity**: 1 point
**Dependencies**: None (AZ-2744 is done)
**Component**: `.github/workflows/ring-cxx.sh`, `ring-go.sh`, `ring-swift.sh`, `ring-prepare.sh`, `ring-toolchains.sh`, `publish-vcpkg.test.sh`, `ring-wiring.test.sh` and one new wiring test file; `test.yml` and `scripts/loop-tests.sh` where they list the test files
**Tracker**: AZ-2747
**Epic**: AZ-2645

## Problem

Comments in six scripts say `language-pair.sh` for what moved to `ring-lib.sh` in loop 47. `ring-wiring.test.sh` sits at exactly 500 lines (soft cap, `quality-thresholds.md`), so its next edit needs a split first.

## Outcome

- Each comment that means the runner or handoff points at `ring-lib.sh`; comments that mean the rows or stages keep `language-pair.sh`.
- `ring-wiring.test.sh` and the new file are each 450 lines or fewer, split by responsibility (for example the shim ring and the element/Go checks out of the workflow checks), with the same checks and mutants.

## Scope

### Included
- Comment text in the six scripts (no code change).
- Split of `ring-wiring.test.sh`; the new file is run by `test.yml` and `scripts/loop-tests.sh` where the existing file is.

### Excluded
- Any ring row, driver, hex vector or package source; renaming a script; a new CI job.

## Acceptance Criteria

**AC-1: Comments**
Given the six scripts
When `git diff` is read
Then only comment lines changed there, and each changed line names the file that holds what it describes.

**AC-2: Split**
Given `ring-wiring.test.sh` and its new sibling
When `wc -l` is read
Then both are at most 450 lines.

**AC-3: Same checks**
Given the two wiring test files
When they run
Then both are green, the number of `expect_rejected` / `expect_accepted` calls in the two files together is the same as before, and each mutant is still rejected (a mutant that no longer applies is rewritten, not dropped).

**AC-4: Wired**
Given `test.yml` and `scripts/loop-tests.sh`
When they are read
Then both run the new file wherever they run `ring-wiring.test.sh`, and `ring-wiring.test.sh` (the wiring test of the wiring tests, if any) reads the right file.

## Non-Functional Requirements

**Performance**
- No added CI job; the `scaffold` job time does not grow beyond noise.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-3 | `bash .github/workflows/ring-wiring.test.sh` and the new file | green, mutants rejected |
| AC-1, AC-2 | `git diff` of the six scripts, `wc -l` | comment-only, at most 450 |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | host recipes of `AGENT_GOTCHAS.md` | `bash .github/workflows/language-pair.sh` | "language pairs passed" | Performance |

## Constraints

- Before the commit: `git grep` every reader of the lines of `ring-wiring.test.sh` and run each one (`AGENT_GOTCHAS.md`, loops 34 and 39); `bash -n` and `shellcheck` if installed; bash 3.2 syntax only.
- A worker never runs `git stash/checkout/reset/clean/add/rm/mv`; commands end on their own.

## Risks & Mitigation

**Risk 1: A split loses a mutant**
- *Risk*: a helper shared by two parts is copied and one copy drifts.
- *Mitigation*: AC-3 counts the calls before and after; shared helpers go to one sourced file.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none | | | |
