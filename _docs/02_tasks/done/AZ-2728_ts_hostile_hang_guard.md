---
loop: 44
branch: dev
---

# TypeScript hostile test: load-aware hang guard, worker start-up not counted against the first case

**Task**: AZ-2728_ts_hostile_hang_guard
**Name**: TypeScript hostile hang guard
**Description**: The hostile worker's start-up has its own guard, and both guards scale with the load factor.
**Complexity**: 1 point
**Dependencies**: AZ-2723
**Component**: typescript package (tests)
**Tracker**: AZ-2728
**Epic**: AZ-2645

## Problem

`typescript/tests/hostile.test.ts` arms a fixed 5 s hang guard (`KILL_AFTER_MS`) when it creates the hostile worker, so the worker's start-up (thread, module load, type stripping) counts against the first case. In the loop 43 step 11 pool (host load 11 to 25) start-up took 11.9 s: the guard fired on `zero-progress repeat ends with trailing error`, then on the next test, and TypeScript passed only on the serial retry (`smoke43.md`). The guard is the last fixed wall-clock bound in the TypeScript suite that AZ-2723 did not convert.

## Outcome

- `tests/support/hostile-worker.ts` posts a ready message after its imports. Start-up has its own guard; the per-case guard arms only after ready.
- Both guards are nominal x the load factor of `tests/support/timing.ts` (`bound`, cap 8), measured in the main thread before each batch.
- A real hang still ends the worker, is reported naming the case, and the remaining cases run in a fresh worker.

## Scope

### Included
- `typescript/tests/hostile.test.ts` (`runBatch`), `typescript/tests/support/hostile-worker.ts`.

### Excluded
- Production code; other packages; the timing helper itself.

## Acceptance Criteria

**AC-1: hang named**
Given a hostile case that never returns
When the hostile test runs it
Then that case is reported as a hang naming the case, and the other cases still run.

**AC-2: start-up not charged to a case**
Given a worker whose start-up takes longer than the per-case guard
When the batch runs
Then no case is reported as a hang because of the start-up.

**AC-3: busy host**
Given 12 busy processes on the host
When the TypeScript suite runs
Then it passes as it does idle.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | a probe job that loops forever in the worker | reported as a hang with its key; the next job still settles |
| AC-2 | a worker that waits before ready longer than the case guard | no hang reported |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | 12 busy processes | `node --test tests/*.ts` in `typescript/` | pass | — |

## Constraints

- Tests only; the guard stays a hang detector, not a performance bound.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none | — | resolved | Low |
