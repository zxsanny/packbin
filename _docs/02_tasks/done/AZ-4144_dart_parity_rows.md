---
loop: 99
branch: dev
---

# Dart: TypeScript parity rows

**Task**: AZ-4144_dart_parity_rows
**Name**: Dart: TypeScript parity rows
**Description**: The TypeScript parity tables run in Dart; differences are written down.
**Complexity**: 3 points
**Dependencies**: AZ-4143_dart_hostile_vectors
**Component**: dart
**Tracker**: AZ-4144
**Epic**: AZ-4133

## Problem

Where the packages once differed, the TypeScript suite pins the decided row. Dart must give the same hex or the same refusal for each, and any place where Dart cannot or should not copy TypeScript must be a written, tested difference.

Feature criteria, scenarios and decisions: `_docs/02_task_plans/dart-package/` (`acceptance_criteria.md` DT-1 to DT-20, `scenarios.md`, `problem.md` D-1 to D-5 and A-1 to A-7, `task_map.md` for the write sets).

## Outcome

- Every TypeScript parity row that applies gives TypeScript's hex or refusal in Dart.
- `parity_differences.md` lists each difference with its reason and its Dart test.

## Scope

### Included

- Dart tests for the parity tables of `typescript/tests/` (the U rows that apply, the AC-3 table, the loop 19 to 23 refusals, the `when`-chain and dispatch-order rows).
- `_docs/02_task_plans/dart-package/parity_differences.md`.
- Fixes in `dart/lib/` for rows that disagree without a reason.
- Owns: `dart/test/parity*`, `parity_differences.md`; may edit walker files for fixes.

### Excluded

- Rows that are TypeScript-only by the documented exceptions (for example 5.0 packed as an integer: Dart refuses a `double`, Go-2)

## Acceptance Criteria

**AC-1: Parity tables (DT-3)**
Given each pinned row of the TypeScript parity tests
When run in Dart
Then the same hex, or a refusal where TypeScript refuses, naming the field id; mismatches not in `parity_differences.md`: 0

**AC-2: Written differences (DT-3)**
Given `parity_differences.md`
When read against the tests
Then every row in it has a Dart test that pins Dart's behavior; rows without a test 0

**AC-3: Dispatch and check order**
Given the dispatch-order rows of loop 40 (which error wins when two apply)
When run in Dart
Then the same error kind as TypeScript for every row

## Non-Functional Requirements

**Reliability**
- Uncaught exceptions from unpack on any input: 0.

**Compatibility**
- Dart 3.13 and newer, native targets (VM and ahead-of-time); no web.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | Parity tables: each pinned row of the TypeScript parity tests | the same hex, or a refusal where TypeScript refuses, naming the field id; mismatches not in `parity_differences.md`: 0 |
| AC-2 | Written differences: `parity_differences.md` | every row in it has a Dart test that pins Dart's behavior; rows without a test 0 |
| AC-3 | Dispatch and check order: the dispatch-order rows of loop 40 (which error wins when two apply) | the same error kind as TypeScript for every row |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | the `dart` service of `docker-compose.test.yml` (from AZ-4145 on) or `dart test` in `dart/` | the task's tests run on the real package and the shared fixtures read as files | all pass; no fixture is copied into the test code | Reliability |

## Constraints

- Reference for behavior: the TypeScript package at HEAD (A-1); for the file split and the test list: the Swift package.
- A difference needs a reason from an owner decision (Go-1 to Go-4, A-3) or from the language; "easier in Dart" is not a reason.

## Risks & Mitigation

**Risk 1: A late walker fix**
- *Risk*: A parity fix changes bytes an earlier task pinned.
- *Mitigation*: The whole Dart suite runs after every fix.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| None beyond the feature's concerns in `problem.md` | — | resolved | Low |
