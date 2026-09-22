# Flags and a short field

**Task**: AZ-1920_flags_short
**Name**: Flags and a short field
**Description**: Flag width, a stored zero, a short field, and the next pack still matches.
**Complexity**: 5 points
**Dependencies**: AZ-1913_test_infrastructure
**Component**: Blackbox Tests
**Tracker**: AZ-1920
**Epic**: AZ-1865

## Problem

A cleared flag must add no payload, a stored zero must still be written, and a short buffer must not poison the next pack.

## Outcome

- Flags 0x00 add 0 extra bytes. Flags 0x20 add 2 extra bytes
- An optional value of 0 sets the bit and stores integer 0
- A buffer that ends inside the uint16 names the field, the bytes needed, and the bytes left, and returns 0 values
- The next position pack is still the golden hex
- The process does not crash

## Scope

### Included

- FT-P-04, FT-P-05, FT-N-01, NFT-SEC-02, NFT-RES-01

### Excluded

- Repeated groups and the tag gate

## System Under Test Boundary

The test calls `pack` and `unpack` on the real package. It does not replace the walker. Results are compared to `results_report.md` flags rows.

## Acceptance Criteria

**AC-1: Flag width**
Given flags 0x00 and then 0x20 around a uint16
When the list is packed
Then the first adds 0 extra bytes and the second adds 2

**AC-2: A stored zero**
Given an optional value of 0
When the list is packed
Then the bit is set and the stored integer is 0

**AC-3: A short field**
Given a buffer that ends inside that uint16
When it is unpacked
Then the error names the field, the bytes needed, and the bytes left, and the value count is 0

**AC-4: The next call**
Given that short unpack just returned
When the position row is packed
Then the hex is `4001000065cd1d00a3e1110100`

## Non-Functional Requirements

**Reliability**
- A short packet does not crash the process

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-3 | unpack of a short uint16 | error, value count 0 |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | flags 0x00 and 0x20 | pack | 0 extra bytes, then 2 | — |
| AC-2 | optional value 0 | pack | bit set, stored 0 | — |
| AC-3 | buffer ending inside the uint16 | unpack | field, needed, left; value count 0 | Reliability |
| AC-4 | after AC-3 | pack the position row | golden hex | Reliability |

## Constraints

- No registry call

## Risks & Mitigation

**Risk 1: Absence and zero look the same**
- *Risk*: a stored 0 is omitted
- *Mitigation*: AC-2 requires the bit and the zero byte

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| — | — | — | — |
