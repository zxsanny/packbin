---
loop: 12
---

# Python refuses an empty `group(anchor)`; pin non-true bool values

**Task**: AZ-2132_python_empty_group_refused
**Name**: Python empty group refused
**Description**: `group(anchor)` with no fields fails scheme construction wherever it stands; `{on: 1}` / `{on: "yes"}` are pinned to a clear bit.
**Complexity**: 1 point
**Dependencies**: AZ-2083_python_bool_flag_limit
**Component**: python
**Tracker**: AZ-2132
**Epic**: AZ-2069

## Problem

Loop 12 feature assessment (`_docs/loops/loop12/assessment12.md` U3, G3). Python `group(anchor)` with no fields has no accessor, so it carries no value; it builds anywhere today, so the shared construct vector `empty_group_outside_flags` is not met (AZ-2083 Excluded, `README.md` exception). A bool value other than `True` packs `0100`, unpinned. Python split form is not buildable yet (AZ-2100), so Python is not in the `bitwhen` ring.

## Owner decisions (2026-10-05)

U3: A — any empty group that can never carry `true` fails construction wherever it stands.

## Acceptance Criteria

**AC-1: empty group refused everywhere**
Given `group(1)` with no fields at top level, inside `flags`, inside `when` / `repeat` / `times`, and as a list element
When `Scheme(...)` is built
Then `ValueError` naming the anchor

**AC-2: shared construct vector**
Given `empty_group_outside_flags` from `fixtures/hostile/cases.txt`
When the Python construct runner builds it
Then `scheme_error`

**AC-3: non-true values clear the bit**
Given `flags(0, bool(0, on))`
When `{on: 1}` and `{on: "yes"}` are packed
Then `0100`

## Constraints

- ADR-001; `ValueError` for construction errors; files ≤ 500 lines.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none | — | — | — |
