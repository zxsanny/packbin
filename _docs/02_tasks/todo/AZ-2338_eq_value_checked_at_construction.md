---
loop: 19
branch: dev
---

# `eq(integerSource, value)` with a non-integer, NaN, out-of-range or bool-for-integer value is refused at scheme construction in all six packages

**Task**: AZ-2338_eq_value_checked_at_construction
**Name**: eq value checked at construction
**Description**: `eq(integerSource, value)` with a non-integer, NaN, out-of-range or bool-for-integer value is refused at scheme construction in all six packages.
**Complexity**: 3 points
**Dependencies**: AZ-2126 (done)
**Component**: all six
**Tracker**: AZ-2338
**Epic**: AZ-2069

## Problem

Owner decision 11 (review C5, T8) of loop 19 (2026-10-11, option A, accepted as recommended). `Eq(u8, 300)`, a string or NaN still builds in C#; Python `eq(intField, True)` matches 1. A scheme that can never match should fail when it is built.

## Outcome

- All six refuse such an `eq` at construction with the package's construction error naming the member.

## Scope

### Included
- Probe, check, tests.

### Excluded
- `eq(bool, true)` rule of AZ-2126 stays.

## Acceptance Criteria

**AC-1: out-of-range refused**
Given `eq(u8, 300)`
When scheme built
Then construction error in six packages

**AC-2: non-integer refused**
Given `eq(u8, "x")` and NaN
When built
Then construction error

**AC-3: bool for integer refused**
Given `eq(u8, True)` in Python
When built
Then construction error

**AC-4: valid value builds**
Given `eq(u8, 5)`
When built and packed
Then bytes unchanged

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1..3 | three bad values | error |
| AC-4 | valid | unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | hostile `construct` stage | `construct_eq_out_of_range` | error | — |

## Constraints

- Integer range comes from the source field type; no new API.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Each package knows its source type at build; the check order must not depend on member order | coordinator | open | Low |
