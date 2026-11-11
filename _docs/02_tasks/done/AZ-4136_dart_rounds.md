---
loop: 99
branch: dev
---

# Dart: rounds and counted kinds (`repeat`, `times`, `sized`, two-bit slots, `bits`, `packed`)

**Task**: AZ-4136_dart_rounds
**Name**: Dart: rounds and counted kinds (`repeat`, `times`, `sized`, two-bit slots, `bits`, `packed`)
**Description**: `repeat`, `times`, `sized`, `u2` with `slot`, `bits` and `packed` in Dart.
**Complexity**: 5 points
**Dependencies**: AZ-4135_dart_scheme_checks
**Component**: dart
**Tracker**: AZ-4136
**Epic**: AZ-4133

## Problem

The server's schemes use rounds and counted fields for lists of targets and compact flags. Dart needs them with the same bytes and the same count rules as the other packages.

Feature criteria, scenarios and decisions: `_docs/02_task_plans/dart-package/` (`acceptance_criteria.md` DT-1 to DT-20, `scenarios.md`, `problem.md` D-1 to D-5 and A-1 to A-7, `task_map.md` for the write sets).

## Outcome

- The README examples for `repeat`, `times`, `sized`, two-bit slots, `bits` and `packed` give the README hex both ways.
- Count rules equal TypeScript's: a count source of any integer kind, a bias, a count behind a clear `when` refused, a nested round refused when built.

## Scope

### Included

- `repeat` to the end of the packet, `times(anchor, count, …)`, `sized`, `u2` with `slot`, `bits`, `packed` (1- or 2-bit, count plus a bias).
- Rows of a round as one list per name (TypeScript's shape) in the map form, and typed child rows through a factory closure.
- The construction checks of these kinds.
- Owns: the walker files of `dart/lib/src/` and their tests.

### Excluded

- Limits (AZ-4139): this task uses the default limits as constants
- Lists and dictionaries (AZ-4138)

## Acceptance Criteria

**AC-1: README round examples (DT-2)**
Given each README example for `repeat`, `times`, `sized`, two-bit slots, `bits`, `packed`
When packed and unpacked
Then the README hex both ways; mismatched bytes 0

**AC-2: Counts (DT-3)**
Given a count from a u8, u16, u32 and u64 source, with a bias, and a count behind a clear `when` with and without a value
When packed and unpacked
Then TypeScript's bytes or refusal for each; a u64 count that is negative as an `int` (above 2^63 - 1) is refused, not wrapped

**AC-3: Zero rounds (DT-12)**
Given an empty list for a `times` name and a `repeat` with no rounds
When packed
Then count 0 written, no round bytes; unpack gives empty lists, not `null`

**AC-4: Short inside a round (DT-2)**
Given a packet cut inside round 2 of 3
When unpacked
Then an error value naming the field and the round's needed bytes; no row

## Non-Functional Requirements

**Reliability**
- Uncaught exceptions from unpack on any input: 0.

**Compatibility**
- Dart 3.13 and newer, native targets (VM and ahead-of-time); no web.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | README round examples: each README example for `repeat`, `times`, `sized`, two-bit slots, `bits`, `packed` | the README hex both ways; mismatched bytes 0 |
| AC-2 | Counts: a count from a u8, u16, u32 and u64 source, with a bias, and a count behind a clear `when` with and without a value | TypeScript's bytes or refusal for each; a u64 count that is negative as an `int` (above 2^63 - 1) is refused, not wrapped |
| AC-3 | Zero rounds: an empty list for a `times` name and a `repeat` with no rounds | count 0 written, no round bytes; unpack gives empty lists, not `null` |
| AC-4 | Short inside a round: a packet cut inside round 2 of 3 | an error value naming the field and the round's needed bytes; no row |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | the `dart` service of `docker-compose.test.yml` (from AZ-4145 on) or `dart test` in `dart/` | the task's tests run on the real package and the shared fixtures read as files | all pass; no fixture is copied into the test code | Reliability |

## Constraints

- Reference for behavior: the TypeScript package at HEAD (A-1); for the file split and the test list: the Swift package.
- A count from the wire is checked against the bytes left before any list is allocated.
- No file over 500 lines.

## Risks & Mitigation

**Risk 1: Allocation from a hostile count**
- *Risk*: A count of 2^32 allocates before the short check.
- *Mitigation*: The count is compared with the bytes left first; AZ-4139 adds the limits.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| None beyond the feature's concerns in `problem.md` | — | resolved | Low |
