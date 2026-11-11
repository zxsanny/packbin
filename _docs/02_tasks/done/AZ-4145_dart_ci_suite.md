---
loop: 99
branch: dev
---

# Dart in the CI suite

**Task**: AZ-4145_dart_ci_suite
**Name**: Dart in the CI suite
**Description**: A `dart` compose service, `run-suite.sh dart`, `test.yml`, the `loop-tests.sh` stage, the tool pin and the scaffold checks.
**Complexity**: 3 points
**Dependencies**: AZ-4134_dart_core
**Component**: dart
**Tracker**: AZ-4145
**Epic**: AZ-4133

## Problem

A package that CI does not run drifts. Dart needs the same suite wiring as the other eight, without going over the 20 jobs the free plan runs at once.

Feature criteria, scenarios and decisions: `_docs/02_task_plans/dart-package/` (`acceptance_criteria.md` DT-1 to DT-20, `scenarios.md`, `problem.md` D-1 to D-5 and A-1 to A-7, `task_map.md` for the write sets).

## Outcome

- Every push and pull request runs the Dart suite; a failing Dart test fails the check.
- `test.yml` still makes at most 20 jobs.

## Scope

### Included

- `docker-compose.test.yml`: a `dart` service on the pinned `dart:<pin>` image with a pub cache volume, running `run-suite.sh dart`.
- `run-suite.sh dart`: `dart pub get`, `dart format --set-exit-if-changed`, `dart analyze --fatal-infos`, `dart test` with a verbose reporter, the 60-second seeded run, the speed check on a compiled executable, and the dependency check (0 runtime dependencies, no forbidden imports). Its self-test rows.
- `test.yml`: Dart in an existing suites entry (with Go), the scaffold checks (`dart/pubspec.yaml`, `dart/lib/packbin.dart`, test files exist). `tool-pins.txt`: `dart==3.13.x`, read through `tool-pin.sh`; a check that the compose image equals the pin.
- `scripts/loop-tests.sh`: a `dart` stage in the pool, its `covers()` rows and test paths; `scripts/loop-tests.test.sh` rows.
- Owns: `.github/workflows/run-suite.sh`, `run-suite*.test.sh`, the suites and scaffold jobs of `test.yml`, `docker-compose.test.yml`, `scripts/loop-tests.sh`, `scripts/loop-tests.test.sh`, `.github/workflows/tool-pins.txt`.

### Excluded

- The ring job (AZ-4146)
- The publish-gate jobs and `docker-compose.publish.yml` (AZ-4147)

## Acceptance Criteria

**AC-1: Suite runs (DT-9)**
Given the `dart` compose service
When `docker compose -f docker-compose.test.yml run --rm dart`
Then format, analyze (0 issues), tests, seeded run and speed all pass; the test output names each test (not a quiet mode)

**AC-2: A failure fails (DT-9)**
Given a Dart test changed to fail, an unformatted file, and an analyzer info
When the suite runs for each
Then a non-zero exit for each

**AC-3: Job count (DT-9)**
Given `test.yml`
When its jobs and matrix entries are counted
Then ≤ 20; Dart shares the Go entry

**AC-4: Pin (DT-9)**
Given `tool-pins.txt` and `docker-compose.test.yml`
When the pin test runs
Then the image tag equals the pin; a changed tag fails the test

**AC-5: Loop stage**
Given `scripts/loop-tests.sh --only dart` and a change set touching only `dart/test/`
When run
Then the `dart` stage runs; `loop-tests.test.sh` passes with the new rows

## Non-Functional Requirements

**Reliability**
- Uncaught exceptions from unpack on any input: 0.

**Compatibility**
- Dart 3.13 and newer, native targets (VM and ahead-of-time); no web.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | Suite runs: the `dart` compose service | format, analyze (0 issues), tests, seeded run and speed all pass; the test output names each test (not a quiet mode) |
| AC-2 | A failure fails: a Dart test changed to fail, an unformatted file, and an analyzer info | a non-zero exit for each |
| AC-3 | Job count: `test.yml` | ≤ 20; Dart shares the Go entry |
| AC-4 | Pin: `tool-pins.txt` and `docker-compose.test.yml` | the image tag equals the pin; a changed tag fails the test |
| AC-5 | Loop stage: `scripts/loop-tests.sh --only dart` and a change set touching only `dart/test/` | the `dart` stage runs; `loop-tests.test.sh` passes with the new rows |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | the `dart` service of `docker-compose.test.yml` (from AZ-4145 on) or `dart test` in `dart/` | the task's tests run on the real package and the shared fixtures read as files | all pass; no fixture is copied into the test code | Reliability |

## Constraints

- Tests never run in a quiet mode.
- The suite's watcher output stays line-buffered as the other stages'.
- No file over 500 lines: `run-suite.sh` is 472 lines today, so the Dart helpers go into a sourced file as the Swift tests did.

## Risks & Mitigation

**Risk 1: `run-suite.sh` over the cap**
- *Risk*: Adding the Dart case pushes the file over 500 lines.
- *Mitigation*: Dart helpers in a sourced `run-suite-dart.sh`; line counts checked before commit.

**Risk 2: The seeded run and speed check make the shared job slow**
- *Risk*: Go plus Dart in one job.
- *Mitigation*: Timings read after the first CI run; the split stays inside 20 jobs.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| None beyond the feature's concerns in `problem.md` | — | resolved | Low |
