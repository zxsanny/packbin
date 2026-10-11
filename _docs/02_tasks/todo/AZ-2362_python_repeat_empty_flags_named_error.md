---
loop: 20
branch: dev
---

# Python packs a repeat with an empty list as a flags member without a bare IndexError

**Task**: AZ-2362_python_repeat_empty_flags_named_error
**Name**: Python empty repeat under flags
**Description**: Python packs a repeat with an empty list as a flags member without a bare IndexError.
**Complexity**: 1 points
**Dependencies**: AZ-2336 (done)
**Component**: python
**Tracker**: AZ-2362
**Epic**: AZ-2069

## Problem

Loop 20 clear gap G2 (assessment loop 19). Python raises a bare `IndexError` for a `repeat` with an empty list under a `flags` member.

## Outcome

- Python gives the same outcome as the other packages for that row (probe TypeScript or Rust first and match it: a clear bit, or a named error); never a bare `IndexError`.

## Acceptance Criteria

**AC-1: no bare IndexError**
Given a `repeat` as a `flags` member and `[]`
When packed in Python
Then the reference package's outcome (same hex, or an error naming the member)

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | empty repeat under flags | matches reference |

## Constraints

- Wire bytes of every accepted row are unchanged.
