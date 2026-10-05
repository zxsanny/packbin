---
loop: 10
branch: loop/10-cpp-microcontroller
---

# C++ core: buffers, scalar kinds, error values

**Task**: AZ-2060_cpp_core_scalars
**Name**: C++ core scalars
**Description**: An allocation-free, exception-free C++ core packs and unpacks scalar fields into caller buffers and reports errors as values.
**Complexity**: 3 points
**Dependencies**: None
**Component**: cpp
**Tracker**: AZ-2060
**Epic**: AZ-2059

## Problem

The C++ package throws on errors, allocates on every call and copies native number objects. So it cannot build with `-fno-exceptions`, and it writes wrong bytes on a big-endian CPU (`_docs/02_task_plans/cpp-microcontroller/problem.md` blockers 1, 3, 5, 6).

## Outcome

- Scalar fields (u8…u64, i8…i64, f32, f64, bool, fixed bytes, big-endian marker) pack into a caller buffer and unpack from a caller buffer with 0 heap calls and 0 exceptions.
- Every failure is one of `Ok`, `ShortPacket`, `TrailingBytes`, `TypeMismatch`, `BufferFull`, `TooMany`, `BadValue`, `SchemeInvalid`, with the byte offset and field id.
- Bytes are identical on little- and big-endian CPUs.

## Scope

### Included
- Core writer and reader over caller buffers; scalar kinds; byte order independent of the host CPU; the error enum with offset and field id.
- Compile-time refusal of `f64` where `double` is not 8 bytes.
- Host unit tests for the above, built with `-fno-exceptions -fno-rtti`.

### Excluded
- Scheme tables and type number (AZ-2061), grouped/conditional kinds (AZ-2062), counted/variable kinds (AZ-2063), host port and removal of the old walker (AZ-2064), session (AZ-2065), target CI (AZ-2066).

## Acceptance Criteria

**AC-1: Scalars match today's bytes**
Given every scalar vector the host suite asserts today
When the core packs the row into a buffer exactly the packet size and unpacks the hex
Then mismatched bytes are 0, mismatched fields are 0, and the written length equals the packet size (scenario S1).

**AC-2: Short output buffer**
Given an output buffer one byte smaller than the packet
When the core packs
Then the result is `BufferFull` with the offset and field id, and 0 bytes are written past that offset (S2).

**AC-3: Short and trailing input**
Given a packet one byte short, and a packet with one trailing byte
When the core unpacks
Then the results are `ShortPacket` and `TrailingBytes` with offset and field id; process aborts: 0 (S3).

**AC-4: Byte order independent of the CPU**
Given little-endian default and `be()` fields of every width
When numbers are written and read
Then the bytes equal the expected hex, and numbers go through shifts on an unsigned value of the field width, never a copy of the native object (S7; proven on a big-endian CPU in AZ-2066).

**AC-5: f64 needs an 8-byte double**
Given a build where `sizeof(double) == 4`
When a scheme uses `f64`
Then compilation fails with a `static_assert` naming `f64`; with `f32` only, the build succeeds (feature AC-9).

## Non-Functional Requirements

**Compatibility**
- Builds with `-std=c++17 -fno-exceptions -fno-rtti -Os -Wall -Wextra -Werror`. Allowed headers only: `<cstdint>`, `<cstddef>`, `<cstring>`, `<type_traits>`, `<limits>`, `<array>`, `<utility>`.
- No global or static mutable state; reentrant.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | each scalar vector, pack and unpack | 0 mismatched bytes/fields, length equals packet size |
| AC-2 | buffer one byte short | `BufferFull`, offset and id, no write past offset |
| AC-3 | short packet; trailing byte | `ShortPacket`; `TrailingBytes` with offset and id |
| AC-4 | little and big-endian fields of each width | expected hex |
| AC-5 | compile check with the double-size condition forced | compile error naming `f64` |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | `fixtures/golden.hex` scalar fields | pack/unpack through the core | identical bytes | Compatibility |

## Constraints

- Feature `restrictions.md` § Embedded profile governs every rule in the core.
- Wire bytes do not change.

## Risks & Mitigation

**Risk 1: Two walkers for a while**
- *Risk*: the old dynamic walker still exists until AZ-2064.
- *Mitigation*: AZ-2064 deletes it; no new code may call the old walker after this task.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Core and old walker coexist until AZ-2064 | D-1 A, AZ-2064 | accepted-risk | Low |
