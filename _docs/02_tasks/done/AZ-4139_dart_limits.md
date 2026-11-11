---
loop: 99
branch: dev
---

# Dart: round limits, pack budgets and the seeded unpack run

**Task**: AZ-4139_dart_limits
**Name**: Dart: round limits, pack budgets and the seeded unpack run
**Description**: `maxRounds`, `maxSlots`, `maxBytes` and `withLimits` on pack and unpack, and a seeded random unpack run.
**Complexity**: 3 points
**Dependencies**: AZ-4138_dart_collections
**Component**: dart
**Tracker**: AZ-4139
**Epic**: AZ-4133

## Problem

A hostile packet must not make the phone allocate without bound. Dart needs the same limits as the other packages, on unpack and on pack, and a run that throws random and mutated bytes at unpack.

Feature criteria, scenarios and decisions: `_docs/02_task_plans/dart-package/` (`acceptance_criteria.md` DT-1 to DT-20, `scenarios.md`, `problem.md` D-1 to D-5 and A-1 to A-7, `task_map.md` for the write sets).

## Outcome

- Default limits equal the other packages' (65,535 rounds; 1,048,576 slots; 16,777,216 bytes).
- A lowered limit refuses; a raised one accepts the old worst packet.
- A 60-second seeded run finds 0 exceptions.

## Scope

### Included

- The three limits on a scheme, `withLimits`, the slot-width rule of the README's Untrusted input section, limits enforced on pack too.
- A seeded random unpack run: every input of `fixtures/hostile/fuzz/corpus.txt`, then random mutations, for a set time; the seed is printed so a failure can be replayed.
- Owns: the limits file and tests of `dart/`.

### Excluded

- The hostile case file (AZ-4143)

## Acceptance Criteria

**AC-1: Defaults and one past (DT-5, S6)**
Given rows with 65,535 and 65,536 rounds, and packets at and one past the slot and byte budgets
When packed and unpacked with the default limits
Then at the limit: packs and unpacks; one past: `too_many` (unpack) or a thrown pack error, as TypeScript

**AC-2: Lowered and raised (DT-5)**
Given `withLimits` with a lower and a higher value of each limit
When the same packet is unpacked
Then lowered: `too_many` or `bad_value` with needed 0; raised: the row

**AC-3: Limit of zero (zero value)**
Given `withLimits(maxRounds: 0)` and the same for the other two
When set
Then the rule of the TypeScript package for 0 is copied and pinned by a test (refused when set, or 0 rounds allowed: whichever TypeScript does; the test names which)

**AC-4: Seeded run (DT-5)**
Given the corpus (33 inputs today) and a seed
When the run goes on for ≥ 60 seconds in CI (shorter in a local quick mode)
Then uncaught exceptions 0; unpack calls over 1 second 0; results above the slot budget 0; the test fails if a corpus line names a case id missing from the hostile case file

## Non-Functional Requirements

**Reliability**
- Uncaught exceptions from unpack on any input: 0.

**Compatibility**
- Dart 3.13 and newer, native targets (VM and ahead-of-time); no web.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | Defaults and one past: rows with 65,535 and 65,536 rounds, and packets at and one past the slot and byte budgets | at the limit: packs and unpacks; one past: `too_many` (unpack) or a thrown pack error, as TypeScript |
| AC-2 | Lowered and raised: `withLimits` with a lower and a higher value of each limit | lowered: `too_many` or `bad_value` with needed 0; raised: the row |
| AC-3 | Limit of zero: `withLimits(maxRounds: 0)` and the same for the other two | the rule of the TypeScript package for 0 is copied and pinned by a test (refused when set, or 0 rounds allowed: whichever TypeScript does; the test names which) |
| AC-4 | Seeded run: the corpus (33 inputs today) and a seed | uncaught exceptions 0; unpack calls over 1 second 0; results above the slot budget 0; the test fails if a corpus line names a case id missing from the hostile case file |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | the `dart` service of `docker-compose.test.yml` (from AZ-4145 on) or `dart test` in `dart/` | the task's tests run on the real package and the shared fixtures read as files | all pass; no fixture is copied into the test code | Reliability |

## Constraints

- Reference for behavior: the TypeScript package at HEAD (A-1); for the file split and the test list: the Swift package.
- The run is time-boxed by a variable so the local suite stays fast; CI sets 60 seconds.
- No file over 500 lines.

## Risks & Mitigation

**Risk 1: No native fuzzer in Dart**
- *Risk*: There is no coverage-guided fuzzer like Go's.
- *Mitigation*: A seeded mutation run over the shared corpus; the same corpus the other packages use.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| None beyond the feature's concerns in `problem.md` | — | resolved | Low |
