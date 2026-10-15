---
loop: 28
branch: dev
---

# Loop test script: cpp pool stage race

**Task**: AZ-2565_cpp_pool_race
**Name**: cpp pool race
**Description**: The `cpp` stage and the other pool stages never write the same path, so the pool passes without a serial retry.
**Complexity**: 3 points
**Dependencies**: None
**Component**: ci
**Tracker**: AZ-2565
**Epic**: AZ-2223

## Problem

In loop 27 step 11 the `cpp` pool stage failed once with `ld: cannot open output file build/packbin_tests`; `cpp/build/` is shared with a stage running at the same time. The `scaffold` stage was named as the other party, but no command of it is known to write there; the stage also starts with `make -C cpp clean`.

## Outcome

- The colliding command and path are named with reproduction log lines.
- The shared path is removed or the overlap ended; 3 of 3 pool runs pass with 0 serial retries.

## Scope

### Included
- `scripts/loop-tests.sh` (stage commands, pool order), `scripts/loop-tests.test.sh`, `cpp/Makefile` or compose only if the cause is there; the status report entry.

### Excluded
- Product C++ code; the CI jobs (CI containers have no shared pool).

Feature ACs: `_docs/02_task_plans/ci-split-and-leftovers/acceptance_criteria.md`. Scenarios: `scenarios.md` in the same folder.

## Acceptance Criteria

**AC-1: Cause named (CR-1)**
Given the pool with stages `cpp` and `scaffold` (and the others)
When the race is reproduced with instrumentation
Then the status report names the command and the path, with the log lines (0 "likely")

**AC-2: No collision (CR-2, S-8)**
Given the fix
When `scripts/loop-tests.sh --all --only cpp,scaffold --jobs 3` runs 3 times
Then `cpp` and `scaffold` pass each time with 0 serial retries

**AC-3: Guard (CR-2)**
Given `scripts/loop-tests.test.sh`
When the `cpp` stage runs a host-side `make clean` before its container (the old command put back)
Then the test fails and names the stage and the path `cpp/build` (1 mutant rejected). Amended: the reproduction showed no second pool stage; the cause is the host delete followed by an immediate container start

**AC-4: Stale build of the other OS (S-9)**
Given a Mach-O `cpp/build/` from the host and then the `gcc:16` container run
When the `cpp` stage runs
Then it builds without a manual clean

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-3 | `loop-tests.test.sh` shared-path check | green real, red mutant |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | Mac, Docker, load below 4 | 3 pool runs | pass, 0 retries | CR-2 |

## Constraints

- Reproduce before changing (meta-rule: debugging over contemplation).
- Check host load and swap before the runs (LESSONS 2026-10-12).

## Risks & Mitigation

**Risk 1: The race does not reproduce**
- *Risk*: a rare race cannot be seen in 3 runs.
- *Mitigation*: instrument the stages (log each path written) and name the overlap from the log; report honestly if only the static overlap is shown.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Cause unpinned | AC-1 | open | Medium |
