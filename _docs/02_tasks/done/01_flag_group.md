---
loop: 2
branch: loop/2-strings-lists-dicts
---

# Flag group

**Task**: 01_flag_group
**Name**: Flag group
**Description**: One flags bit introduces a specified group of zero or more fields.
**Complexity**: 5 points
**Dependencies**: AZ-1876_csharp_pack, AZ-1877_typescript_pack, AZ-1878_python_pack, AZ-1879_rust_pack, AZ-1880_cpp_pack, AZ-1881_java_pack
**Component**: library
**Tracker**: pending
**Epic**: pending

## Problem

A flags bit can only introduce one field. A bit that means "present, no payload" cannot be written, and a bit that is followed by two fields (a login id and a timestamp) has to be split by the caller. The group under the bit has to be named in the schema.

## Outcome

- A set bit whose group has 0 fields adds 0 extra bytes
- A set bit whose group is one `uint16` adds 2 extra bytes
- A set bit whose group is a `uint16` then a `uint32` adds 6 extra bytes
- A clear bit adds 0 extra bytes and those fields are absent
- A stored `0` inside a present field is written
- A buffer that ends inside the group is an error and returns 0 values
- All six languages produce the same bytes. Mismatched bytes: 0

## Scope

### Included

- A schema group of 0, 1, or 2 fields under one bit
- The existing one-field flags width
- Short-buffer unpack of a group

### Excluded

- Length-prefixed blobs
- Values narrower than one byte
- A bit whose field count is not fixed in the schema

## System Under Test Boundary

`pack` and `unpack` in each of the six languages. Results are the byte counts below. No registry call.

## Acceptance Criteria

**AC-1: Empty group**
Given a bit whose schema group has 0 fields, and that bit set
When the list is packed
Then that bit adds 0 extra bytes

**AC-2: One field**
Given bit 5 as a `uint16`
When flags `0x00` and flags `0x20` are packed
Then the first adds 0 extra bytes and the second adds 2

**AC-3: Two fields**
Given one bit whose schema group is a `uint16` of 7 then a `uint32` of 1000, and that bit set
When the list is packed
Then that bit adds 6 bytes and those bytes are `0700e8030000`

**AC-4: Cleared bit**
Given the same two-field group, and that bit clear
When the list is packed
Then that bit adds 0 extra bytes, and unpack yields 0 values for the group

**AC-5: Stored zero**
Given a one-byte field in the group whose value is 0, and the bit set
When the list is packed
Then the bit is set and the stored byte is `00`

**AC-6: Short group**
Given the two-field group selected, and a buffer that ends inside it
When it is unpacked
Then the error names the field, the bytes needed, and the bytes left, and the value count is 0

## Non-Functional Requirements

**Compatibility**
- The six languages mismatch on 0 bytes for AC-2 and AC-3

**Reliability**
- A short group does not return a partial value

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-6 | unpack ending inside the two-field group | error, value count 0 |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | bit set, 0 fields | pack | 0 extra bytes | — |
| AC-2 | flags 0x00 and 0x20, uint16 | pack | 0 extra bytes, then 2 | Compatibility |
| AC-3 | uint16 7, uint32 1000 | pack | 6 bytes `0700e8030000` | Compatibility |
| AC-4 | same group, bit clear | pack and unpack | 0 extra bytes, 0 group values | — |
| AC-5 | stored 0 | pack | bit set, byte `00` | — |
| AC-6 | buffer ending inside the group | unpack | field, needed, left; value count 0 | Reliability |

## Constraints

- No registry call
- The field count under a bit is fixed in the schema

## Risks & Mitigation

**Risk 1: A one-field bit grows**
- *Risk*: flags `0x20` stop adding 2 bytes
- *Mitigation*: AC-2 requires 0 then 2

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Project AC-4 states one field per bit. This task keeps that width for a one-field bit and adds a schema group of 0 or 2. | packbin acceptance criteria | open | Medium |
