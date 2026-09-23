---
loop: 2
branch: loop/2-strings-lists-dicts
---

# Length-prefixed bytes

**Task**: 02_length_prefixed_bytes
**Name**: Length-prefixed bytes
**Description**: A count field is followed by that many bytes.
**Complexity**: 3 points
**Dependencies**: AZ-1876_csharp_pack, AZ-1877_typescript_pack, AZ-1878_python_pack, AZ-1879_rust_pack, AZ-1880_cpp_pack, AZ-1881_java_pack
**Component**: library
**Tracker**: pending
**Epic**: pending

## Problem

Byte fields have a size fixed in the schema. A string whose length is in the packet (a count, then that many bytes) cannot be one field.

## Outcome

- A `uint16` count of 3 followed by `756176` packs as `0300756176` (5 bytes)
- A count of 0 packs as `0000` and unpacks to 0 payload bytes
- A buffer shorter than the declared count is an error and returns 0 values
- All six languages produce the same bytes. Mismatched bytes: 0

## Scope

### Included

- A count that is already a field in the list, then that many following bytes
- Count 0
- A short buffer

### Excluded

- A flags group
- Values narrower than one byte
- A count that is not an integer field already in the packet

## System Under Test Boundary

`pack` and `unpack` in each of the six languages. No registry call.

## Acceptance Criteria

**AC-1: Counted bytes**
Given a `uint16` count of 3 and the bytes `756176`
When the list is packed
Then those fields are the 5 bytes `0300756176`, and unpack returns the same 3 bytes

**AC-2: Empty payload**
Given a `uint16` count of 0
When the list is packed and unpacked
Then the bytes are `0000` and the payload length is 0

**AC-3: Short payload**
Given a count of 3 and only 1 payload byte present
When it is unpacked
Then the error names the field, the bytes needed, and the bytes left, and the value count is 0

## Non-Functional Requirements

**Compatibility**
- The six languages mismatch on 0 bytes for AC-1

**Reliability**
- A short payload does not return a partial value

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-3 | unpack with 1 byte of a declared 3 | error, value count 0 |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | count 3, bytes `756176` | pack and unpack | 5 bytes `0300756176`, 3 payload bytes | Compatibility |
| AC-2 | count 0 | pack and unpack | `0000`, payload length 0 | — |
| AC-3 | count 3, 1 byte present | unpack | field, needed, left; value count 0 | Reliability |

## Constraints

- No registry call
- The count is little-endian, matching the other integer fields

## Risks & Mitigation

**Risk 1: A short string is accepted**
- *Risk*: unpack returns the 1 byte it has
- *Mitigation*: AC-3 requires value count 0

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| — | — | — | — |
