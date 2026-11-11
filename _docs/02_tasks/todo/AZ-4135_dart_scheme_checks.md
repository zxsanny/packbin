---
loop: 99
branch: dev
---

# Dart: scheme construction checks and the anchored group

**Task**: AZ-4135_dart_scheme_checks
**Name**: Dart: scheme construction checks and the anchored group
**Description**: Every refusal the TypeScript package makes when a scheme is built, in Dart, and the anchored group.
**Complexity**: 5 points
**Dependencies**: AZ-4134_dart_core
**Component**: dart
**Tracker**: AZ-4135
**Epic**: AZ-4133

## Problem

A scheme with a bad reference or an impossible value must be refused when it is built, not when a packet arrives. Dart must refuse the same schemes as TypeScript (with Go-1 to Go-4 as Swift took them), naming the field.

Feature criteria, scenarios and decisions: `_docs/02_task_plans/dart-package/` (`acceptance_criteria.md` DT-1 to DT-20, `scenarios.md`, `problem.md` D-1 to D-5 and A-1 to A-7, `task_map.md` for the write sets).

## Outcome

- Every construction row TypeScript refuses is refused in Dart with the field id in the message; every row it builds, Dart builds.
- Anchored groups, groups under flags and under a flag-byte bit pack and unpack the README hex.

## Scope

### Included

- Reference checks (`when` and count sources exist, come earlier, are in scope), field-id order, at most 8 members of one `flags`, `bool` only under flags or a flag-byte bit, `eq` values the source can hold (range, not a string, NaN, fraction or bool), duplicate names, flag-byte bit numbers 0 to 7 used once.
- `group` (anchored), groups as nested maps both ways in the map form (Go-4).
- Owns: the walker and checks files of `dart/lib/src/` and their tests.

### Excluded

- Checks of rounds and counted kinds (AZ-4136)
- Collection element checks (AZ-4138)

## Acceptance Criteria

**AC-1: Refused schemes (DT-3)**
Given each construction row of the TypeScript scheme-check tests
When the scheme is built in Dart
Then a thrown scheme error naming the field id for every row TypeScript refuses; refusal-vs-build disagreements 0

**AC-2: `eq` range (DT-3)**
Given `eq(u8, 300)`, `eq(u64, -1)` given as a negative literal meant as out of range, `eq(i8, 200)`, `eq` with a string, NaN, 1.5 or a bool
When the scheme is built
Then refused, naming the field; `eq(u64, x)` for a Dart `int` is the 64-bit pattern (A-3): the spec row for `eq(u64, -1)` is recorded in `parity_differences.md` as the one place where Dart cannot tell -1 from 2^64 - 1

**AC-3: Groups (DT-2)**
Given the README group examples (anchored, under flags, under a flag-byte bit) as typed rows and nested maps
When packed and unpacked
Then the README hex both ways; a flat key of an absent group is refused (Go-4)

**AC-4: Nine members of one flags**
Given a `flags` with 9 members
When built
Then refused when built

## Non-Functional Requirements

**Reliability**
- Uncaught exceptions from unpack on any input: 0.

**Compatibility**
- Dart 3.13 and newer, native targets (VM and ahead-of-time); no web.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | Refused schemes: each construction row of the TypeScript scheme-check tests | a thrown scheme error naming the field id for every row TypeScript refuses; refusal-vs-build disagreements 0 |
| AC-2 | `eq` range: `eq(u8, 300)`, `eq(u64, -1)` given as a negative literal meant as out of range, `eq(i8, 200)`, `eq` with a string, NaN, 1.5 or a bool | refused, naming the field; `eq(u64, x)` for a Dart `int` is the 64-bit pattern (A-3): the spec row for `eq(u64, -1)` is recorded in `parity_differences.md` as the one place where Dart cannot tell -1 from 2^64 - 1 |
| AC-3 | Groups: the README group examples (anchored, under flags, under a flag-byte bit) as typed rows and nested maps | the README hex both ways; a flat key of an absent group is refused (Go-4) |
| AC-4 | Nine members of one flags: a `flags` with 9 members | refused when built |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | the `dart` service of `docker-compose.test.yml` (from AZ-4145 on) or `dart test` in `dart/` | the task's tests run on the real package and the shared fixtures read as files | all pass; no fixture is copied into the test code | Reliability |

## Constraints

- Reference for behavior: the TypeScript package at HEAD (A-1); for the file split and the test list: the Swift package.
- A scheme error is thrown at construction only; unpack of a built scheme never throws.
- No file over 500 lines.

## Risks & Mitigation

**Risk 1: `eq(u64, -1)`**
- *Risk*: A-3 makes -1 and 2^64 - 1 the same `int`, so the TypeScript refusal of `eq(u64, -1)` cannot be copied.
- *Mitigation*: Recorded as a named difference; the test pins Dart's behavior.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| `eq(u64, negative)` cannot be refused under A-3 | agent default A-3; owner may reverse | accepted-risk | Low |
