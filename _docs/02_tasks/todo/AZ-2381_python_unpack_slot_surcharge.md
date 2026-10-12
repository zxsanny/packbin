---
loop: 21
branch: dev
---

# Python unpack charges the same slots as pack

**Task**: AZ-2381_python_unpack_slot_surcharge
**Name**: Python unpack charges the same slots as pack
**Description**: Python unpack stops charging 8 more slots per name for the first round of each run, so a packet pack writes at `maxSlots` unpacks.
**Complexity**: 2 points
**Dependencies**: AZ-2382 (the rule and its reference table)
**Component**: python
**Tracker**: AZ-2381
**Epic**: AZ-2069

## Problem

Owner decision U1 of loop 21 (option A, README line 1192). Python unpack charges 8 more slots per name for the first round of each run, so a packet Python's own pack writes at exactly `maxSlots` is refused by Python's own unpack.

## Outcome

- Python unpack charges by the AZ-2382 rule; the README sentence about the surcharge is removed.

## Scope

### Included
- `python/` unpack slot accounting.

### Excluded
- Other packages; wire bytes.

## Acceptance Criteria

**AC-1: pack then unpack at the limit**
Given a round packed at exactly `maxSlots`
When Python unpacks it
Then it unpacks

**AC-2: one over**
Given a round one slot over
When Python packs it
Then it is refused as before

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | round at the limit | round-trips |
| AC-2 | one over | refused |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | hostile `unpack` stage | existing slot cases | unchanged | — |

## Constraints

- Python 3.10+ per-worker venv.
- Wire bytes unchanged.
