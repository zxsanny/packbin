---
loop: 25
branch: dev
---

# Python ValueError text for a value whose count no field wrote

**Task**: AZ-2454_python_value_error_text
**Name**: Python ValueError text for a value whose count no field wrote
**Description**: Python raises `ValueError` with the TypeScript text when a value is given to a member whose count no field wrote; today Python raises `RuntimeError("count N is missing")`, which breaks the one error type the other packages share.
**Complexity**: 1 point
**Dependencies**: none
**Component**: python
**Tracker**: AZ-2454
**Epic**:

## Problem

The Low-1 row (handoff 25, D-batch 2026-10-13) pins Python's parity: a value given to a member whose `count` no earlier field wrote is a user error (TypeScript raises `ValueError` naming the member and the count); Python today raises `RuntimeError("count N is missing")`. Switching to `ValueError` matches TypeScript's text and matches the way every other outside-caller error type in Python is spelled.

Reference: `_docs/02_task_plans/python-single-accessor/` (Low-1), TypeScript `src/pack.ts` (the `ValueError` text with the member name).

## Outcome

- `python/packbin/` raises `ValueError` with the TypeScript text (same words, same ordering of the member and the count ids) when a value reaches a member whose count no earlier field wrote.
- The error type is `ValueError`, not `RuntimeError`; `TypeError` is reserved for a wrong Python value type (unchanged).
- A test pinning the exact text and the exception type.

## Scope

### Included

- `python/packbin/*` edits where that error is raised.
- `python/tests/` tests pinning the new type and text.
- Owns (exclusive write): `python/packbin/**`, `python/tests/**`

### Excluded

- Any other package.

## Acceptance Criteria

**AC-1: Error type is `ValueError`**
Given a scheme `times(1, "n"), u8(0, "n"), u8(2, "x")` and a `pack({"x": 1})`
When Python packs
Then `pack` raises `ValueError` (not `RuntimeError`); written bytes 0.

**AC-2: Error text matches TypeScript**
Given AC-1's raise
When the message is read
Then it matches TypeScript's exact text (same words, same ordering of the member name and the count id).

**AC-3: `TypeError` stays for a wrong Python value type**
Given `pack({"x": "a string, not a number"})` on `u8(0, "x")`
When Python packs
Then `pack` raises `TypeError` as before (unchanged); the AC-1 and AC-2 changes do not shadow the type error.

**AC-4: Unpack unchanged**
Given a packet whose bytes reach a member whose on-wire count is missing
When Python unpacks
Then the error class and text of unpack are unchanged by this change (the AC covers pack only).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-1 | pack with no value for `n` | `ValueError` |
| AC-2 | the message | matches TypeScript's text |
| AC-3 | pack with a wrong Python type | still `TypeError` |
| AC-4 | unpack on a short packet | unchanged class and text |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-1, AC-2 | the scheme and the `pack({"x": 1})` call | pack | `ValueError` with TypeScript text | |
| AC-3 | wrong-type value for `u8` | pack | `TypeError` | |
