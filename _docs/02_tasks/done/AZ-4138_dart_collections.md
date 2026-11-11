---
loop: 99
branch: dev
---

# Dart: lists, dictionaries and nested rows

**Task**: AZ-4138_dart_collections
**Name**: Dart: lists, dictionaries and nested rows
**Description**: `utf8` fields in schemes, `list` and `dict` of scalars, strings and rows, and nested rows.
**Complexity**: 5 points
**Dependencies**: AZ-4136_dart_rounds, AZ-4137_dart_text
**Component**: dart
**Tracker**: AZ-4138
**Epic**: AZ-4133

## Problem

Archangel's typed rows (activities, route shares) need lists and dictionaries of rows instead of JSON inside binary frames. Dart needs `list` and `dict` with the same bytes and refusals as the other packages.

Feature criteria, scenarios and decisions: `_docs/02_task_plans/dart-package/` (`acceptance_criteria.md` DT-1 to DT-20, `scenarios.md`, `problem.md` D-1 to D-5 and A-1 to A-7, `task_map.md` for the write sets).

## Outcome

- The README string, list and dictionary examples give the README hex both ways.
- Dictionary keys are written in ascending order of their bytes and a repeated or out-of-order key is refused on unpack.
- Typed rows and maps give the same bytes.

## Scope

### Included

- The `utf8` field (the codec of AZ-4137 wired into the walker).
- `list` and `dict` with a u16 count: elements of scalars, strings, and rows (groups); keys as the other packages allow.
- Nested rows: typed child rows through a factory closure; nested maps in the map form (U26 A).
- `null` is no value; an empty list or map is a value with 0 items.
- Owns: the walker and collection files of `dart/lib/src/` and their tests.

### Excluded

- Limits (AZ-4139)

## Acceptance Criteria

**AC-1: README collections (DT-2)**
Given each README example for `utf8`, `list` and `dict`
When packed and unpacked
Then the README hex both ways; mismatched bytes 0

**AC-2: Dictionary key order (DT-2)**
Given a Dart map whose keys are inserted out of order, and wire bytes with a repeated key and with keys out of order
When packed, unpacked
Then pack writes the keys ascending by their unsigned bytes; unpack gives `bad_value` for both wire cases

**AC-3: Typed row equals map (DT-12, S8)**
Given the same values as a typed row and as a map, with a nested-row group, a `null` member and an empty list
When packed
Then the same bytes; the `null` member's bit is clear; the empty list writes count 0; the nested group is read from the nested map

**AC-4: Element types (DT-15)**
Given a list holding a wrong Dart type for its element kind, and a dictionary with a non-string key where a string key is declared
When packed
Then a thrown pack error naming the field and the element index; bytes returned 0

**AC-5: Count over the bytes left**
Given a list count of 65,535 with 3 bytes left
When unpacked
Then an error value (`short` with the needed bytes); nothing allocated for 65,535 items

## Non-Functional Requirements

**Reliability**
- Uncaught exceptions from unpack on any input: 0.

**Compatibility**
- Dart 3.13 and newer, native targets (VM and ahead-of-time); no web.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | README collections: each README example for `utf8`, `list` and `dict` | the README hex both ways; mismatched bytes 0 |
| AC-2 | Dictionary key order: a Dart map whose keys are inserted out of order, and wire bytes with a repeated key and with keys out of order | pack writes the keys ascending by their unsigned bytes; unpack gives `bad_value` for both wire cases |
| AC-3 | Typed row equals map: the same values as a typed row and as a map, with a nested-row group, a `null` member and an empty list | the same bytes; the `null` member's bit is clear; the empty list writes count 0; the nested group is read from the nested map |
| AC-4 | Element types: a list holding a wrong Dart type for its element kind, and a dictionary with a non-string key where a string key is declared | a thrown pack error naming the field and the element index; bytes returned 0 |
| AC-5 | Count over the bytes left: a list count of 65,535 with 3 bytes left | an error value (`short` with the needed bytes); nothing allocated for 65,535 items |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | the `dart` service of `docker-compose.test.yml` (from AZ-4145 on) or `dart test` in `dart/` | the task's tests run on the real package and the shared fixtures read as files | all pass; no fixture is copied into the test code | Reliability |

## Constraints

- Reference for behavior: the TypeScript package at HEAD (A-1); for the file split and the test list: the Swift package.
- The stream-safe check on dictionary keys that only Swift makes is not copied; Dart follows TypeScript.
- No file over 500 lines.

## Risks & Mitigation

**Risk 1: Map iteration order**
- *Risk*: Dart's default map keeps insertion order, so pack must sort keys by bytes, not by `String.compareTo` (UTF-16 order differs from UTF-8 byte order above U+FFFF).
- *Mitigation*: Keys are sorted by their encoded bytes; one test uses keys where the two orders differ.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| None beyond the feature's concerns in `problem.md` | — | resolved | Low |
