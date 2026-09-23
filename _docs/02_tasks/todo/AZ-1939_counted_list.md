---
loop: 2
branch: loop/2-strings-lists-dicts
---

# Counted list

**Task**: AZ-1939_counted_list
**Name**: Counted list
**Description**: A list is a 2-byte element count, then that many elements, and it does not consume the next field.
**Complexity**: 5 points
**Dependencies**: AZ-1938_utf8_string
**Component**: library
**Tracker**: AZ-1939
**Epic**: AZ-1937

## Problem

`repeat` reads until the buffer ends, so a list in the middle of a packet has nowhere to stop. A count that is one element too high swallows the next field.

## Outcome

- Two little-endian 2-byte integers 1 and 2 pack to `020001000200` (6 bytes).
- One big-endian 2-byte integer 1 packs to `01000001` (4 bytes).
- A list of one 1-byte integer 1, then a following 1-byte integer 2, packs to `01000102`. Unpack returns the list `[1]` and the following field `2`.
- An empty list packs to `0000`.
- A list of 65536 elements writes 0 bytes and fails.
- The six languages mismatch on 0 bytes for the 4-byte list-then-field packet.

## Scope

### Included

- A list of integers, including one big-endian integer
- A list of strings
- A list followed by another field
- Count 0 and count 65536

### Excluded

- `repeat` as an element
- A dictionary

## System Under Test Boundary

`pack` and `unpack` in each of the six languages. No registry call.

## Acceptance Criteria

**AC-1: Two integers**
Given a list of the little-endian 2-byte integers 1 and 2
When it is packed and unpacked
Then the bytes are `020001000200` and the list is `[1, 2]`

**AC-2: Big-endian element**
Given a list of one big-endian 2-byte integer 1
When it is packed
Then the bytes are `01000001`

**AC-3: The next field survives**
Given a list of one 1-byte integer 1 followed by a 1-byte integer 2
When it is packed and unpacked
Then the bytes are `01000102`, the list is `[1]`, the following field is `2`, and bytes left are 0

**AC-4: Empty and over the limit**
Given an empty list, and separately a list of 65536 elements
When each is packed
Then the empty list is `0000`, and the list of 65536 writes 0 bytes and fails

## Non-Functional Requirements

**Compatibility**
- The six languages mismatch on 0 bytes for AC-3

**Reliability**
- The element count is not a byte count of the whole list, and it does not include the 2 count bytes

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-3 | list of one byte, then another byte | `01000102`, list `[1]`, next field `2`, bytes left 0 |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | integers 1, 2 | pack and unpack | `020001000200`, `[1, 2]` | — |
| AC-2 | one big-endian integer 1 | pack | `01000001` | — |
| AC-3 | list `[1]` then field `2` | pack and unpack in each language | `01000102`, both values, bytes left 0 | Compatibility, Reliability |
| AC-4 | empty list; 65536 elements | pack | `0000`; 0 bytes written and pack fails | — |

## Constraints

- The count is little-endian and is the number of elements that follow.
- `repeat` stays a read-until-the-end group and is not an element of a list.

## Risks & Mitigation

**Risk 1: The list reads one element too many**
- *Risk*: the following field disappears or its first bytes become the last element
- *Mitigation*: AC-3 requires the following field `2` and bytes left 0

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| — | — | — | — |

## Scenarios

S9, S11.
