---
loop: 2
branch: loop/2-strings-lists-dicts
---

# Counted bit pack

**Task**: 03_counted_bit_pack
**Name**: Counted bit pack
**Description**: Values narrower than a byte, and a bitset whose length comes from a count.
**Complexity**: 5 points
**Dependencies**: AZ-1876_csharp_pack, AZ-1877_typescript_pack, AZ-1878_python_pack, AZ-1879_rust_pack, AZ-1880_cpp_pack, AZ-1881_java_pack
**Component**: library
**Tracker**: pending
**Epic**: pending

## Problem

Every value occupies at least one byte. Four 2-bit kinds need one byte, not four, and a bit per segment has a length that comes from a count already in the packet.

## Outcome

- Four 2-bit values `0, 1, 2, 3`, low bits first, pack as the 1 byte `e4`
- One 2-bit value `1` packs as the 1 byte `01`, unused bits `0`
- 8 one-bit values of `1` pack as 1 byte `ff`
- 9 one-bit values pack as 2 bytes
- A buffer shorter than that width is an error and returns 0 values
- All six languages produce the same bytes. Mismatched bytes: 0

## Scope

### Included

- 2-bit values, 4 per byte, low bits first, unused bits 0
- A bitset whose bit count is a prior integer field, rounded up to whole bytes
- A short tail

### Excluded

- A flags group of whole-byte fields
- A length-prefixed byte string
- Bit widths other than 1 and 2

## System Under Test Boundary

`pack` and `unpack` in each of the six languages. No registry call.

## Acceptance Criteria

**AC-1: Four kinds**
Given four 2-bit values `0, 1, 2, 3`
When the list is packed and unpacked
Then the bytes are the 1 byte `e4`, and the four values match

**AC-2: Partial byte**
Given one 2-bit value `1`
When the list is packed
Then the bytes are the 1 byte `01`

**AC-3: Whole bitset**
Given a count of 8 and eight bits of `1`
When the list is packed
Then the bitset is the 1 byte `ff`

**AC-4: Rounded bitset**
Given a count of 9 and nine bits
When the list is packed
Then the bitset is 2 bytes, and the unused bits in the last byte are `0`

**AC-5: Short tail**
Given a count of 9 and only 1 bitset byte present
When it is unpacked
Then the error names the field, the bytes needed, and the bytes left, and the value count is 0

## Non-Functional Requirements

**Compatibility**
- The six languages mismatch on 0 bytes for AC-1 and AC-4

**Reliability**
- A short tail does not return a partial value

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-5 | unpack of 1 byte for a 9-bit set | error, value count 0 |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | 2-bit values 0, 1, 2, 3 | pack and unpack | 1 byte `e4`, 4 values | Compatibility |
| AC-2 | one 2-bit value 1 | pack | 1 byte `01` | — |
| AC-3 | 8 bits of 1 | pack | 1 byte `ff` | — |
| AC-4 | count 9 | pack | 2 bytes, unused bits 0 | Compatibility |
| AC-5 | count 9, 1 byte present | unpack | field, needed, left; value count 0 | Reliability |

## Constraints

- No registry call
- Unused bits in a partial last byte are 0

## Risks & Mitigation

**Risk 1: Kinds land in the high bits**
- *Risk*: `0, 1, 2, 3` is not `e4`
- *Mitigation*: AC-1 requires `e4`

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| — | — | — | — |
