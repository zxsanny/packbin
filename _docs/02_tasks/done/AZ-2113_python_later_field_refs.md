# Python refuses when and count names that point to a later field

**Task**: AZ-2113_python_later_field_refs
**Name**: Python refuses when and count names that point to a later field
**Description**: Python builds the schemes of vectors `when_names_later_field` and `count_names_later_field` (expected `scheme_error`).
**Complexity**: 3 points
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

**AC-4** (added by the loop 13 feature assessment, X4)
Given `u8 mode(0)` and `repeat(1, when(1, eq(0, 1), u8 v(1)))`, When Python builds it, Then it raises `ValueError` naming the outer id (a reference inside a `repeat` / `times` body may name only an earlier field of the same body); the three reference construct vectors `when_names_later_field`, `count_names_later_field` and `when_names_outer_field_in_repeat` are built by the Python construct test and refused

## Constraints

- ADR-001: no shared walker, no import from another package.
- Files stay at or under 500 lines.

## Risks & Mitigation

- *Risk*: scope creep into neighbouring tickets. *Mitigation*: Could fold into AZ-2083. Source: loop 11 feature-assess G2.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Written from a feature-assess row; refine the Given/When/Then with the implementer before the loop that takes it | coordinator | open | Low |
| Loop 13 assessment (X4): Python builds the `when_names_outer_field_in_repeat` scheme; `CONSTRUCT_SCHEMES` in the Python construct test omits all three reference vectors. AC-4 added | coordinator | open | Medium |

## Loop 16 result (2026-10-06)

Done in loop 16 (batch 1). AC-3 ("existing scheme tests pass unchanged") contradicted AC-4 for three existing tests that built schemes AC-4 refuses; they were rebuilt with the same bytes and the same results (`hostile_support.zero_progress_when`, `times_zero_width`: a zero-width `bytes` field plus an in-round `when`, the TypeScript `emptyRound` precedent) or now assert the construction refusal and gained a ported unpack test (`test_zero_width_elements.py`, group-wrapped element). Python still does not refuse a `repeat` or `times` nested in a round, or a count that names a bool or float (TypeScript refuses the count); no ticket.
