---
loop: 99
branch: dev
---

# Dart: hostile vectors and the ninth package in the case checker

**Task**: AZ-4143_dart_hostile_vectors
**Name**: Dart: hostile vectors and the ninth package in the case checker
**Description**: All shared hostile cases run in Dart; the checker and the `Run by` lines count nine packages.
**Complexity**: 3 points
**Dependencies**: AZ-4139_dart_limits, AZ-4140_dart_ecc
**Component**: dart
**Tracker**: AZ-4143
**Epic**: AZ-4133

## Problem

The hostile case file is the shared proof that no package can be crashed or stalled by input. Dart must run every case, and the checker that counts which packages run each pack section must count nine.

Feature criteria, scenarios and decisions: `_docs/02_task_plans/dart-package/` (`acceptance_criteria.md` DT-1 to DT-20, `scenarios.md`, `problem.md` D-1 to D-5 and A-1 to A-7, `task_map.md` for the write sets).

## Outcome

- Every case of `fixtures/hostile/cases.txt` gives an allowed outcome in Dart.
- `check-cases.sh` passes with nine names.

## Scope

### Included

- A Dart loader of `cases.txt` and the hostile schemes hand-written from `fixtures/hostile/README.md` (stages unpack, construct, limit, pack).
- `fixtures/hostile/check-cases.sh` (the package list gains `Dart`), `cases.test.sh` (Dart corruption tests as the Go and Swift ones: in neither line, twice, the word inside a reason), and `Dart` in every `Run by` or `Not run by` line of `fixtures/hostile/README.md`.
- Owns: `dart/test/hostile*`, `fixtures/hostile/check-cases.sh`, `fixtures/hostile/cases.test.sh`, `fixtures/hostile/README.md`.

### Excluded

- New hostile cases (none are added)
- The audit probes under `fixtures/hostile/fuzz/<lang>/` (not in CI)

## Acceptance Criteria

**AC-1: All cases (DT-4, S2)**
Given every data line of `fixtures/hostile/cases.txt` (75 today; the test counts the lines it ran and fails on a line it skipped)
When run in Dart at its stage
Then an outcome from the line's allowed terms; uncaught exceptions 0; each unpack case ≤ 1 second

**AC-2: Nine names (DT-4)**
Given `check-cases.sh` with `Dart` in its list
When run on the README
Then passes: every pack and limit section names all nine packages exactly once across `Run by` and `Not run by`

**AC-3: Checker catches Dart mistakes**
Given a README copy with `Dart` in neither line, in both, and only as a word inside a reason (`Dartmouth`)
When `cases.test.sh` runs
Then the checker fails for each copy (whole-word match)

## Non-Functional Requirements

**Reliability**
- Uncaught exceptions from unpack on any input: 0.

**Compatibility**
- Dart 3.13 and newer, native targets (VM and ahead-of-time); no web.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | All cases: every data line of `fixtures/hostile/cases.txt` (75 today; the test counts the lines it ran and fails on a line it skipped) | an outcome from the line's allowed terms; uncaught exceptions 0; each unpack case ≤ 1 second |
| AC-2 | Nine names: `check-cases.sh` with `Dart` in its list | passes: every pack and limit section names all nine packages exactly once across `Run by` and `Not run by` |
| AC-3 | Checker catches Dart mistakes: a README copy with `Dart` in neither line, in both, and only as a word inside a reason (`Dartmouth`) | the checker fails for each copy (whole-word match) |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | the `dart` service of `docker-compose.test.yml` (from AZ-4145 on) or `dart test` in `dart/` | the task's tests run on the real package and the shared fixtures read as files | all pass; no fixture is copied into the test code | Reliability |

## Constraints

- A case Dart cannot run is listed under `Not run by` with the reason, never silently skipped.
- The checker's other eight names and their tests keep passing.
- No file over 500 lines.

## Risks & Mitigation

**Risk 1: Shared README edit**
- *Risk*: 45 `Run by` lines change in a file other loaders do not parse but the checker does.
- *Mitigation*: Run `check-cases.sh` and `cases.test.sh` after the edit; the edit is mechanical (one name added per line).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| None beyond the feature's concerns in `problem.md` | — | resolved | Low |
