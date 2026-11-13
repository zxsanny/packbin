---
loop: 122
branch: dev
---

# Dart: the repeat-last cost test times the best of three builds

**Task**: AZ-4277_dart_repeat_last_cost_best_of_three
**Name**: Dart: the repeat-last cost test times the best of three builds
**Description**: entry `dart-repeat-last-cost-test-flake` of the hygiene queue item `_docs/02_task_plans/hygiene-loop122/queue_item.md` (loop 122); its text is the spec.
**Complexity**: 1 points
**Dependencies**: none
**Component**: dart/test/
**Tracker**: AZ-4277
**Epic**: AZ-4133

Dart only.

## Problem
`dart/test/rounds/repeat_last_cost_test.dart` ("16000 sibling whens that write nothing, then a repeat build in a time that follows their number") failed in the pool of loop 121 step 11: `took 869 ms, nominal bound 300 ms, load factor 1.72, scaled bound 514 ms`. It passed alone on the serial retry. The load factor is a CPU loop; the timed build is allocation-bound, so a Docker VM running five other suites slows it by more than the factor shows. One build is one sample: a single garbage-collection pause or time slice decides it.

## Outcome
The test passes in the pool as it does alone, with the same sensitivity to a quadratic walk (the old walk takes seconds at this size).

## Code sections
`dart/test/rounds/repeat_last_cost_test.dart`; `dart/test/support/timing.dart` only if a shared helper is the smallest change.

## Acceptance checks
- AC-1: the timed section is the best of three builds of the same fields (as the C# test of loop 121 takes the best of five), checked against the same load-aware bound (`LoadBound`, nominal 300 ms).
- AC-2: a deliberately quadratic copy of the walk (a temp test that walks every later sibling for each sibling, run once against this test's shape and bound, not committed) fails the check.
- AC-3: the `dart` stage passes three times in a row beside the other suites (`bash scripts/loop-tests.sh` with the dart stage in the pool), or, if the host is too loaded for a pool run, three times alone plus once in the step 11 run.

## Needs
none

## Constraints
The nominal bound stays 300 ms; no other Dart test changes; no change in `lib/`.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| agent-found hygiene entry; no operator decision outstanding | agent | accepted-risk | Low |
