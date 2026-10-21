---
loop: 55
branch: dev
---

# Bool and group-presence source behind a clear `when` in all eight packages

**Task**: AZ-3133_when_bool_source_corpus
**Name**: Bool and group-presence source behind a clear `when`
**Description**: A bool or group-presence bit that sits in a `when` that does not hold is absent, so the `when` that names it is false; shared hostile cases run in all eight packages.
**Complexity**: 3 points
**Dependencies**: None
**Component**: `fixtures/hostile/cases.txt` and the runners of the eight packages (a package that differs is fixed where it differs)
**Tracker**: AZ-3133
**Epic**: AZ-2645

## Problem

`mark_held` marks bool and group-presence sources too since loop 54 (review #3), but no case covers them. Python is the only package run on the probe `u8 mode; when(mode==1){ flags{ bool on }; u8 a }; when(on==true){ u8 b }`.

## Outcome

- Corpus cases for the bool source run in all eight packages and agree with Python; the empty-group source is pinned in the C++ and Rust package tests.

## Scope

### Included
- Cases `pack_when_of_skipped_bool_source` (mode 0), `pack_when_of_held_bool_source` (mode 1 on true) and the false row, runners of the eight packages (Python bytes: `0100`, `0101010705`, `01010007`); a C++ test and a Rust test of the empty-group variant (only those two accept an empty group as a `when` source).
- A package that differs is fixed when it is the same defect, else ticketed.
- If the C++ core needs a code change, margins stay inside the Cortex-M4F budgets (coordinate with AZ-3132: same package worker).

### Excluded
- Any wire change; a `when` on a bool compared with anything but `true` (refused at construction already, AZ-2126); row U24.

## Acceptance Criteria

**AC-1: Source skipped** (AC-B1)
Given `u8 mode; when(mode==1){ flags{ bool on }; u8 a }; when(on==true){ u8 b }` and the row mode 0, on true, a 7, b 5
When packed and unpacked
Then pack writes the mode byte only and unpack returns mode 0, no error.

**AC-2: Source held** (AC-B2)
Given mode 1, on true / on false, a 7, b 5
When packed and unpacked
Then the packets are `01 01 07 05` and `01 00 07` (after the scheme id) and the rows round-trip.

**AC-3: Group presence bit, C++ and Rust** (AC-B3)
Given the same shape with an empty group in `flags` as the source (only C++ and Rust accept it)
When mode is 0 and when mode is 1
Then the outcome follows AC-1 and AC-2 and the C++ packets equal the Rust packets.

**AC-4: Eight packages** (AC-B4)
Given the shared corpus cases
When the eight runners run
Then 0 packages fail and 0 skip the three bool cases.

## Non-Functional Requirements

**Compatibility**: no wire change; packets of schemes with no skipped source are byte-identical.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 to AC-3 | the cases in each runner | outcome equals the corpus line |
| AC-4 | `fixtures/hostile/cases.test.sh` and the eight suites | 0 failed, 0 skipped |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A package other than Python may differ | fixed here or ticketed, never skipped | open | Medium |
