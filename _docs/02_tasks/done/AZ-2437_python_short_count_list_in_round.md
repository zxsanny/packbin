---
loop: 23
branch: dev
---

# Python refuses a short count list in a round body through the U11 check

**Task**: AZ-2437_python_short_count_list_in_round
**Name**: Python refuses a short count list in a round body through the U11 check
**Description**: The AZ-2410 U11 check in Python reads a round's count past the end of a short list and refuses a row TypeScript packs.
**Complexity**: 1 point
**Dependencies**: none
**Component**: python
**Tracker**: AZ-2437
**Epic**: AZ-2069

## Problem

Found in loop 23 by the AZ-2436 Python worker; TypeScript probed by the parent. In a `times`/`repeat` round body with the row 56 shape (`u8 mode; when mode == 1 { u8 c }; <bit> { bits/packed/sized v (count c) }`), a count list shorter than the rounds, where the round with no entry has its `when` clear, is refused: `times {n:2, mode:[1,0], c:[3]}` gives `ValueError: 2: 1 items, times count is 2`; `repeat {mode:[1,0], c:[3]}` gives `KeyError: missing field c`. TypeScript packs `01020103000000` and `010103000000`; Python packs the same row without the counted member, and with `c: [3, None]`. Cause: `_refuse_unwritten_count` reads the count with `_at_round` (`python/src/packbin/_pack_rounds.py`), which raises past the end of the list. `reference_loop22.md` §1: an absent count is not refused by the U11 rule.

## Outcome

- In the U11 check a missing round entry reads as an absent count (no refusal from that check); the rows above pack the TypeScript hex.
- If the row was refused at 88c063f too (before AZ-2410), the worker reports it; the fix still applies, since the U11 check is the refusing path.

## Scope

### Included
- `python/src/packbin/` (the U11 check only) and Python tests.

### Excluded
- The round accessor's behavior for members a round reads (still needs its entry).

## Acceptance Criteria

**AC-1: short count list packs**
Given the `times` and `repeat` rows above, for `bits`, `packed`, `sized`, split bit and combined `flags`
When packed
Then `01020103000000` / `010103000000` (as TypeScript).

**AC-2: U11 unchanged**
Given the AZ-2410 and AZ-2436 refusal rows
When packed
Then refused with the same text.

**AC-3: required entries unchanged**
Given a round that reads `c` (its `when` holds) with no entry
When packed
Then refused as at HEAD.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | short lists x 3 kinds x 2 bit forms x times/repeat | TypeScript hex |
| AC-2 | existing AZ-2410 / AZ-2436 tests | green |
| AC-3 | holding round with no entry | refused as at HEAD |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| — | covered by unit tests | — | — | — |

## Constraints

- Full Python suite `-v --tb=short`.
