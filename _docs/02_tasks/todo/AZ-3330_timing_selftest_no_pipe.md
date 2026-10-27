---
loop: 76
branch: dev
---

# The publish timing selftest reads its checks without a pipe from `printf`

**Task**: AZ-3330_timing_selftest_no_pipe
**Name**: `publish-timing.selftest.sh` without `printf | grep` pipelines, and with evidence on failure
**Description**: The timing selftest no longer pipes a variable into an early-exit reader under `pipefail`, and a failed check prints what it matched against.
**Complexity**: 2 points
**Dependencies**: None
**Component**: CI scripts (`.github/workflows/`)
**Tracker**: AZ-3330
**Epic**: AZ-2645

Item 1 of `_docs/02_task_plans/hygiene-after-frame-ports/problem.md` (L75-2).

## Problem

`publish-timing.selftest.sh` failed once at host load near 100 (`printf: write error: Broken pipe`, then "alpha has no timing line"; it passed alone at load 12). The file has 15 `printf '%s\n' "$out" | grep ...` pipelines under `set -euo pipefail`. The suspected cause (the reader `grep -q` exits on its first match while `printf` still writes) was not reproduced: 0 failures in 3,000 trials of the pattern, idle and with 12 CPU burners at load 5 to 12, Apple bash 3.2.57. The cause stays unproven. A failed check prints only its own message, so the next failure will not show whether the pipe or the text was at fault.

## Outcome

- The file has 0 `printf ... | grep` pipelines; the checks read the captured text from a here-string or a variable test.
- A check that does not match prints the captured driver output with its `FAIL` line.
- The record says "cause unproven"; nothing claims the flake fixed.

## Scope

### Included
- `.github/workflows/publish-timing.selftest.sh` only.

### Excluded
- `publish-timing.test.sh`, `publish-gate.test.sh` and every other script (only this file has the pattern: `git grep` finds no other `printf '%s\n' ... | grep -q` file in `.github/workflows/`); a retry around the checks; any claim about the cause.

## Acceptance Criteria

**AC-1: No pipe to an early-exit reader**
Given `.github/workflows/publish-timing.selftest.sh`
When it is searched for `printf '%s\n' ... | grep` pipelines
Then there are 0 (15 today)

**AC-2: Still catches what it caught**
Given a copy of the repository's `.github/workflows/` in which `publish-timing.test.sh` is mutated so `alpha` prints no timing line
When the selftest runs against the copy
Then it exits non-zero and prints `FAIL: alpha has no timing line`; on the unmutated files it exits 0 with 0 `FAIL` lines

**AC-3: The next failure shows its evidence**
Given a check of the selftest that does not match
When it fails
Then the captured driver output it matched against is printed with the `FAIL` line

**AC-4: Stable under load**
Given 12 CPU burners
When the selftest runs 20 times in a row
Then all 20 exit 0 (a sanity bound, not a proof of the cause)

**AC-5: File size**
Given the changed file
When its lines are counted
Then it is at most 500 (231 today)

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `grep -c` of the pattern | 0 |
| AC-2 | mutated copy | non-zero exit, the `alpha` message |
| AC-3 | mutated copy | the captured output follows the `FAIL` line |
| AC-4 | 20 runs under 12 burners | 20 exit 0 |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | a tree copy under the scratchpad | the selftest on the copy | as AC-2 | — |

## Constraints

- It runs under Apple bash 3.2 (the Mac) and bash 5 (CI): a here-string (`grep -q ... <<< "$out"`) works in both. Edit and write no file in the repository while `scripts/loop-tests.sh` is in its publish-gate stage.
- A worker runs no `git add`, `rm`, `mv`, `restore --staged`, `stash`, `checkout`, `reset` or `clean`; every command takes stdin from `/dev/null`; CPU burners end by `alarm`.

## Risks & Mitigation

**Risk 1: the flake is not this pattern**
- *Risk*: the next high-load failure has another cause.
- *Mitigation*: AC-3 prints the matched text, so the cause is readable at once.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The cause of the one failure is not reproduced | state "unproven" in the record; do not call the flake fixed | open | Low |
