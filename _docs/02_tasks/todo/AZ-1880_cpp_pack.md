# C++ pack and unpack

**Task**: AZ-1880_cpp_pack
**Name**: C++ pack and unpack
**Description**: C++ pack and unpack of a caller-owned field list, matching the golden hex.
**Complexity**: 5 points
**Dependencies**: AZ-1866_initial_structure
**Component**: cpp
**Tracker**: AZ-1880
**Epic**: AZ-1863

## Problem

a C++ program needs the same bytes as the other five languages. A tagged serializer would change the size.

## Outcome

- `pack` of the position fixture yields `4001000065cd1d00a3e1110100`, mismatched bytes 0
- `unpack` of that hex returns the five fields and 0 motion fields
- This package's bytes match the fixture
- The package is what vcpkg `packbin` publishes

## Scope

### Included

- `pack` and `unpack`
- Integer and float fields, `bytes(n)`, little-endian by default, `be`, flags, `when`, and `repeat`
- The package identity vcpkg `packbin`, license MIT

### Excluded

- A code generator
- The tag job (AZ-1875)
- Another language's package

## Acceptance Criteria

**AC-1: Position pack**
Given type 64, sid 1, latitude 500000000, longitude 300000000, profile 1, and motion flags clear
When `pack` runs
Then the bytes are `4001000065cd1d00a3e1110100` and mismatched bytes are 0

**AC-2: Position unpack**
Given that hex
When `unpack` runs
Then the five fields match and the motion field count is 0

**AC-3: Bytes match the fixture**
Given the shared golden fixture
When this package packs the position list
Then mismatched bytes against the fixture are 0

**AC-4: Flags and a stored zero**
Given a list whose bit 5 is a uint16
When flags are 0x00, flags are 0x20, a field is present as 0, and a field is absent
Then 0x00 adds 0 bytes, 0x20 adds 2 bytes, the present 0 is written, and absence does not substitute 0

**AC-5: A short buffer returns no value**
Given a buffer that ends inside a field
When `unpack` runs, and then `pack` of the position fixture runs
Then the unpack value count is 0, the error names the field, needed, and left, and the following pack still matches the golden hex

## Non-Functional Requirements

**Performance**
- 100000 pack-then-unpack round trips of the position fixture finish in ≤ 1 second on one core

**Compatibility**
- Field names in errors are the same strings as the other languages

**Reliability**
- A short packet does not change the next call

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | position pack | hex `4001000065cd1d00a3e1110100`, mismatched bytes 0 |
| AC-2 | position unpack | five fields, motion field count 0 |
| AC-3 | bytes against the fixture | mismatched bytes 0 |
| AC-4 | flags 0x00, flags 0x20, present 0, absence | 0 bytes, 2 bytes, 0 written, absence adds 0 bytes |
| AC-5 | short field, then a position pack | value count 0, then the golden hex |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | the position value | `pack` | the 13-byte hex | — |
| AC-5 | a buffer that ends inside a field | `unpack` | 0 values | — |
| AC-5 | the same process after that error | position `pack` | the golden hex | ≤ 1 second is a separate loop |

## Constraints

- No tag, length prefix, version byte, or schema id on the wire
- ADR 001
- The archive contains 0 registry tokens

## Risks & Mitigation

**Risk 1: R01**
- *Risk*: this hand-written list drifts
- *Mitigation*: AC-3 compares to the fixture. A mismatch publishes nothing

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| — | — | — | — |

## Runtime Completeness

- **Capability**: pack and unpack in C++
- **Production code**: the real `pack` and `unpack` for this language
- **Allowed external stubs**: none for the field walker
- **Unacceptable substitutes**: a function that returns the golden hex without walking the field list
