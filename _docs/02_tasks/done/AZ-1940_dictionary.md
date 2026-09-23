---
loop: 2
branch: loop/2-strings-lists-dicts
---

# Dictionary

**Task**: AZ-1940_dictionary
**Name**: Dictionary
**Description**: A dictionary is a 2-byte pair count, then that many key/value pairs, in key-byte order.
**Complexity**: 5 points
**Dependencies**: AZ-1938_utf8_string, AZ-1939_counted_list
**Component**: library
**Tracker**: AZ-1940
**Epic**: AZ-1937

## Problem

Access rules are a map from a name to a list of actions. Insert order differs across languages. If a pair count is treated as a byte count, the next key starts in the middle of a value.

## Outcome

- Username `zxsanny`, roles `user` and `dispatcher`, and access `store` → `read`, `write`; `channel` → `read`; `map` → `read`, `gps_fix`, `set`, `edit` pack to 103 bytes `07007a7873616e6e7902000400757365720a0064697370617463686572030007006368616e6e656c010004007265616403006d6170040004007265616407006770735f6669780300736574040065646974050073746f7265020004007265616405007772697465`.
- Inserting the access keys as `store`, then `channel`, then `map` yields those same 103 bytes.
- Unpack of that hex returns that username, those two roles, and those three keys with those lists. Wrong fields: 0. Bytes left: 0.
- An empty string, an empty list, and an empty dictionary pack to `000000000000`.
- The same dictionary key twice returns an error and 0 values.
- Packing the 103-byte value twice, including from two callers at once, mismatches on 0 bytes.
- The six languages mismatch on 0 bytes for the 103-byte value.

## Scope

### Included

- A dictionary of string to list of string
- Key order by UTF-8 bytes, ascending
- The empty triple
- A repeated key

### Excluded

- An application table from an integer id to display text
- `repeat` as a dictionary value

## System Under Test Boundary

`pack` and `unpack` in each of the six languages. No registry call.

## Acceptance Criteria

**AC-1: User value**
Given username `zxsanny`, roles `user` and `dispatcher`, and the access map above
When it is packed
Then the bytes are the 103-byte hex in Outcome, and bytes left after unpack are 0

**AC-2: Insert order**
Given the same access keys inserted as `store`, `channel`, `map`
When it is packed
Then mismatched bytes against AC-1 are 0

**AC-3: Unpack**
Given the AC-1 hex
When it is unpacked
Then username, both roles, and the three access lists match, wrong fields are 0, and bytes left are 0

**AC-4: Empty triple**
Given an empty string, an empty list, and an empty dictionary
When they are packed
Then the bytes are `000000000000`

**AC-5: Repeated key**
Given a dictionary buffer that contains the same key twice
When it is unpacked
Then the error returns and the value count is 0

## Non-Functional Requirements

**Compatibility**
- The six languages mismatch on 0 bytes for AC-1

**Reliability**
- Two packs of the same value mismatch on 0 bytes. A repeated key returns 0 values.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-5 | dictionary with one key written twice | error, value count 0 |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | the user value | pack in each language | 103-byte hex, bytes left 0 on unpack | Compatibility |
| AC-2 | keys inserted store, channel, map | pack | 0 mismatched bytes against AC-1 | — |
| AC-3 | the 103-byte hex | unpack | username, 2 roles, 3 access keys, wrong fields 0 | Reliability |
| AC-4 | empty string, list, and dictionary | pack | `000000000000` | — |
| AC-5 | one key twice | unpack | value count 0 | Reliability |

## Constraints

- Pair order on the wire follows the key's UTF-8 bytes, one byte at a time, unsigned, ascending.
- The pair count is the number of pairs, not the number of bytes, and it does not include the 2 count bytes.
- Field names `username`, `roles`, and `access` are not written.

## Risks & Mitigation

**Risk 1: Pair count is read as a byte length**
- *Risk*: the next key starts inside a value and the map is wrong
- *Mitigation*: AC-1 and AC-3 fix the 103-byte layout and require bytes left 0

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Two equal keys | this task AC-5 | resolved | Low |

## Scenarios

S1, S2, S3, S6, S8, S10, S12.
