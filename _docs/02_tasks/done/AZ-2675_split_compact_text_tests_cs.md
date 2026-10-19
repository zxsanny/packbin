---
loop: 37
branch: dev
---

# Compact text: split CompactTextTests.cs under 500 lines

**Task**: AZ-2675_split_compact_text_tests_cs
**Name**: Compact text: split CompactTextTests.cs under 500 lines
**Description**: Compact text: split CompactTextTests.cs under 500 lines
**Complexity**: 2 points
**Dependencies**: None
**Component**: compact-text
**Tracker**: AZ-2675
**Epic**: AZ-2645

## Problem

`csharp/tests/CompactTextTests.cs` is 620 lines; the cap is 500 (`quality-thresholds.md`).

## Outcome

- The tests live in files of at most 500 lines, split by responsibility, unchanged in number and result.

## Scope

### Included
- `csharp/tests/CompactTextTests.cs` and new sibling test files.

### Excluded
- Any change to a test's assertions or to `csharp/src`.

## Acceptance Criteria

**AC-1: Split without loss**
Given the 620-line file
When it is split
Then every new file is at most 500 lines and `dotnet test` (with `MSBUILDDISABLENODEREUSE=1`) reports the same number of compact-text tests, all passing (RL-2)

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | test count before and after | equal, all pass |


## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none beyond `problem.md` | — | resolved | Low |
