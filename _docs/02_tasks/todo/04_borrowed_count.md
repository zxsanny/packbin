---
loop: 7
branch:
---

# Borrowed count

**Task**: 04_borrowed_count
**Name**: Borrowed count
**Description**: A later field takes its item count from an earlier field, so one scheme packs and unpacks a route.
**Complexity**: 8 points
**Dependencies**: AZ-1950
**Component**: library
**Tracker**: pending
**Epic**: pending

## Problem

A route frame is one record: header, then N two-bit point kinds, then N latitude/longitude pairs, then N−1 straight-leg bits. The count N is already written in the header. `u2` only accepts a fixed list of named slots. `bits` takes that count as stored and cannot use N−1. `repeat` unpacks until the buffer ends, so a field after the pairs is eaten. Callers pack the header as one scheme, append the kinds by hand, pack the pairs as a second scheme, drop that scheme's type byte, and append the mask by hand.

## Outcome

- One row type and one scheme pack the route. A second scheme is not used. Hand-appended bytes: 0.
- Unpack of those bytes fills the same row. Bytes left: 0.
- The route hex is `3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101`.
- All six languages produce that hex. Mismatched bytes: 0.
- `repeat` until the buffer ends, and fixed-slot `u2`, stay as they are.

## Scope

### Included

- A packed integer list of width 1 or 2. The item count is an earlier integer field, plus a bias of 0 or −1. No length byte of its own. Low bits first, unused bits in the last byte are 0.
- A counted group: the inner fields exactly N times, N from an earlier integer field, then the next field of the scheme.
- Either field may sit inside an existing `when`, so the straight-leg mask is written after the pairs and only when that flag is set.
- Pack rejects a list whose length is not the borrowed count.
- A short tail names the field, the bytes needed, and the bytes left, and returns 0 values.
- The route fixture below, in all six languages.
- `schema.md` rows for the two helpers.

### Excluded

- Widths other than 1 and 2.
- A bias other than 0 and −1.
- Changing `repeat` or fixed-slot `u2`.
- A length prefix on the packed list or the counted group.
- Application code that calls packbin.

## Call shape

Width is 1 or 2. `countId` is the earlier field. `bias` defaults to 0. Item count is that field's value plus the bias. A count of 0 with bias −1 has item count 0 and writes no bytes.

| Language | Packed list | Counted group |
|----------|-------------|---------------|
| C# | `Field.Packed<T>(width, id, accessor, countId, bias = 0)` | `Field.Times(countId, fields)` |
| TypeScript | `packed(width, id, acc, countId, bias = 0)` | `times(countId, fields)` |
| Python | `packed(width, id, accessor, count_id, bias=0)` | `times(count_id, fields)` |
| Rust | `packed(width, name, count_name, bias)` | `times(count_name, fields)` |
| Java | `Packbin.packed(width, id, get, set, countId, bias)` | `Packbin.times(countId, fields)` |
| C++ | `packed(width, id, countId, bias)` | `times(countId, fields)` |

Python uses one member accessor when that call shape is already on the branch, and the reader/writer pair otherwise.

## Route fixture

One class. The scheme is the whole frame. Field order:

1. `u16` sid, `u16` name.
2. Flag byte. Bit 0 is an optional `u16` unit name. Bit 1 is a bool, straight-mask present, and writes no payload. Bit 2 is an optional `u16` route id.
3. `u8` count.
4. Packed list, width 2, bias 0, count from that `u8`. One value per point: 0 vertex, 1 start, 2 checkpoint, 3 end.
5. Counted group, same count: `i32` lat, `i32` lon, once per point.
6. `when` the straight bool is set: packed list, width 1, bias −1. One bit per leg. A set bit is a straight line.

Row: sid 16, name 21, unit name absent, straight set, route id 45, count 2, kinds `[1, 3]`, latitudes `[500000000, 500010000]`, longitudes `[300000000, 300010000]`, straight bits `[1]`.

Packed hex: `3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101`.

Unpack returns that row. A second pack of the unpacked row is the same hex.

## System Under Test Boundary

`pack` and `unpack` in each of the six languages. No registry call.

## Acceptance Criteria

**AC-1: Width-2 list borrows the count.**
Given a prior `u8` count of 4 and the values `0, 1, 2, 3`.
When the packed list of width 2 and bias 0 is packed and unpacked.
Then the values are one byte `e4`, and the four values match. The count byte is not repeated inside the list.

**AC-2: Width-1 list uses count minus one.**
Given a prior count of 9 and eight bits of `1`, bias −1.
When the list is packed.
Then the bitset is 1 byte `ff`. A count of 1 and bias −1 writes 0 bitset bytes.

**AC-3: The group stops, then the next field is read.**
Given a count of 2, two lat/lon pairs, and a following `u8` of `7`.
When the counted group is packed and unpacked.
Then both pairs match, the following byte is `7`, and bytes left are 0. The `7` is not read as another latitude.

**AC-4: One route scheme round-trips.**
Given the route fixture.
When it is packed, unpacked, and packed again.
Then both hex strings are `3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101`. Bytes left: 0. Schemes used: 1.

**AC-5: Length and short tail fail closed.**
Given kinds whose length is not the borrowed count.
When packed.
Then packing fails and names the field.
Given a count of 2 and only one coordinate byte after the kinds.
When unpacked.
Then the error names the field, the bytes needed, and the bytes left, and the value count is 0.

## Feature Acceptance Criteria

Exercises the borrowed count. Fixed-slot `u2` and `repeat` until the buffer ends are unchanged. A `repeat` of one pair followed by a trailing `u8` still consumes that `u8` as a latitude.

## Non-Functional Requirements

**Compatibility**
- The six languages mismatch on 0 bytes for AC-1 and AC-4.

**Reliability**
- A short tail does not return a partial point or a partial kind.

## Language effort

The bit math already exists. `bits` borrows a count. `u2` packs fixed slots low-bits-first. `repeat` already writes one group per list index and stops on pack; only unpack runs to the end of the buffer. This task adds a list source and a bias to the packed form, and a count stop to unpack of a group.

| Language | What changes | Difficulty |
|----------|----------------|------------|
| C# | One `Packed` factory and `Times`. Count resolution already walks `countId`. | Low. Same pattern as `Bits`. |
| TypeScript | Two field objects and two walker arms. Accessors are already functions. | Low. Same size as `bits` and `repeat`. |
| Rust | Two `Field` variants and match arms in pack and unpack. | Medium. The enum and `Value` lists are the cost, not the bit math. |
| Python | Two node types and the pack/unpack functions. | Low once the accessor shape on the branch is followed. |
| Java | Two factories with get/set pairs, and the walker. | Medium. Mechanical, more lines than C#. |
| C++ | Two field constructors and the counted walker. Map values are already id-keyed. | Low–medium. Same shape as the existing `u2` and `bits` functions. |

No shared walker. Each package changes on its own. The route fixture is the check that they still match.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-2 | count 1, bias −1 | 0 bitset bytes |
| AC-5 | kinds length ≠ count | pack fails, field named |
| AC-5 | count 2, one coordinate byte | error, value count 0 |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | count 4, values 0, 1, 2, 3 | pack and unpack | 1 byte `e4`, 4 values, count not repeated | Compatibility |
| AC-2 | count 9, eight bits of 1, bias −1 | pack | 1 byte `ff` | — |
| AC-3 | count 2, two pairs, trailing `u8` 7 | pack and unpack | pairs match, trailing byte is 7, bytes left 0 | Reliability |
| AC-4 | route fixture | pack, unpack, pack | hex matches twice, one scheme | Compatibility |
| AC-5 | short coordinate tail | unpack | field, needed, left; value count 0 | Reliability |

## Constraints

- No registry call.
- Unused bits in a partial last byte are 0.
- Item count is the earlier field plus the bias. It is not a second length on the wire.
- The straight-leg mask is a `when` after the counted group, not a payload written next to the flag byte.

## Risks & Mitigation

**Risk 1: Kinds land in the high bits**
- *Risk*: `0, 1, 2, 3` is not `e4`, or the route kind byte is not `0d`
- *Mitigation*: AC-1 requires `e4`. AC-4 requires the route hex, whose kind byte is `0d`

**Risk 2: The counted group consumes the mask**
- *Risk*: unpack reads the straight-leg byte as another coordinate
- *Mitigation*: AC-3 puts a known byte after the pairs. AC-4 checks the mask bit survives unpack

**Risk 3: Bias −1 is applied twice**
- *Risk*: the mask is one leg short
- *Mitigation*: AC-2 uses count 9 and expects one byte `ff` (8 bits). AC-4 expects the final byte `01` for one leg

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| — | — | — | — |
