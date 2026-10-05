# Python refuses when and count names that point to a later field

**Task**: AZ-2113_python_later_field_refs
**Name**: Python refuses when and count names that point to a later field
**Description**: Python builds the schemes of vectors `when_names_later_field` and `count_names_later_field` (expected `scheme_error`).
**Complexity**: 2 points
**Dependencies**: None
**Component**: python
**Tracker**: AZ-2113
**Epic**: AZ-2069

## Problem

Python builds the schemes of vectors `when_names_later_field` and `count_names_later_field` (expected `scheme_error`). README: "The tested field must already have been read."

## Outcome

Each AC below passes in the named package(s); wire bytes of packets that work today do not change.

## Scope

### Included
- python: the change and tests named in the ACs.

### Excluded
- Error kind and label of any error value (C15).
- Other packages.

## Acceptance Criteria

**AC-1**
Given `u8 a`, `when(1, eq(2,1), u8 b)`, `u8 c`, When the scheme is built, Then it raises `ValueError` naming the later id

**AC-2**
Given `sized` counting on a later field, When built, Then it raises `ValueError`

**AC-3**
Given every existing scheme test, When they run, Then they pass unchanged

## Constraints

- ADR-001: no shared walker, no import from another package.
- Files stay at or under 500 lines.

## Risks & Mitigation

- *Risk*: scope creep into neighbouring tickets. *Mitigation*: Could fold into AZ-2083. Source: loop 11 feature-assess G2.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Written from a feature-assess row; refine the Given/When/Then with the implementer before the loop that takes it | coordinator | open | Low |
