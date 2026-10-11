---
loop: 19
branch: dev
---

# A `times` list shorter than the count is a named error in Python outside `flags`, as inside

**Task**: AZ-2336_python_short_times_list_named_error
**Name**: Python short times list named error
**Description**: A `times` list shorter than the count is a named error in Python outside `flags`, as inside.
**Complexity**: 1 points
**Dependencies**: AZ-2248 (done)
**Component**: python
**Tracker**: AZ-2336
**Epic**: AZ-2069

## Problem

Owner decision 8 (assessment U9) of loop 19 (2026-10-11, option A, accepted as recommended). Outside `flags` a short list raises a bare `IndexError` (three tests pin it); inside `flags` the error names the member.

## Outcome

- A short `times` list raises the named packer error naming the member.

## Scope

### Included
- Raise the named error; update the three tests that pin `IndexError`.

### Excluded
- Other packages.

## Acceptance Criteria

**AC-1: short list is named**
Given a `times` count 3 and a list of 2
When packed in Python outside flags
Then a named error naming the member, not `IndexError`

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | short list | named error |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | existing hostile case | unchanged | unchanged | — |

## Constraints

- Error type follows the package's existing bad-value error.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Three tests are rewritten, not deleted | coordinator | resolved | Low |
