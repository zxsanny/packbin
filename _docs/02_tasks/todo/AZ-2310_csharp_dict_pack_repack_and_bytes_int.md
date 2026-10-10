---
loop: 18
branch: dev
---

# C# dictionary pack: repack group elements read by Read, Bytes/Sized given an int

**Task**: AZ-2310_csharp_dict_pack_repack_and_bytes_int
**Name**: C# dictionary pack edge cases
**Description**: The rows `Read` returns for a list or dict of group elements pack again to the same bytes, and an `int` given for a `Bytes` or `Sized` name throws `ArgumentException` naming the member.
**Complexity**: 2 points
**Dependencies**: AZ-2119_csharp_group_list_element, AZ-2191_csharp_dict_pack_strict (done)
**Component**: csharp
**Tracker**: AZ-2310
**Epic**: AZ-2069

## Problem

Loop 17 assessment, clear gaps E3 and E8.

- **E3**: dictionary-mode `Pack` of the rows `Read` returns for list or dict group elements fails with `'A' has no value`. AZ-2119 AC-1 says the unpacked shape matches the other five packages, and the project lesson is "unpack random bytes, then repack".
- **E8**: an `int` for a `Bytes` or `Sized` name fails with a raw `InvalidCastException`; AZ-2191 says dictionary `Pack` throws `ArgumentException` naming the member.

## Outcome

- Unpack then pack of group-element lists and dicts returns the original packet.
- A wrong-typed `Bytes`/`Sized` value is an `ArgumentException` naming the member, in and outside a round.

## Scope

### Included
- C# dictionary-mode `Pack` for group elements; the type check for `Bytes` and `Sized` values.

### Excluded
- Typed mode (already covered); other packages.

## Acceptance Criteria

**AC-1: repack of group elements**
Given a scheme with a list of group elements and one with a dict of group elements, and a packet unpacked in dictionary mode
When the unpacked row is passed to `Pack`
Then the bytes equal the original packet and no `'A' has no value`

**AC-2: differential**
Given random packets unpacked with the current build
When repacked
Then each result equals the original packet or fails exactly as the unpack of it failed (the differential rule of `LESSONS.md`)

**AC-3: Bytes/Sized given an int**
Given an `int` for a `Bytes` name and for a `Sized` name, in a round and outside it
When packed
Then `ArgumentException` names the member; no raw `InvalidCastException`

**AC-4: unchanged paths**
Given the existing suite and fixtures
When run on net10.0 and netstandard2.0
Then results are unchanged

## Non-Functional Requirements

**Compatibility**
- No wire change.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | list and dict of group elements | original bytes |
| AC-2 | random-bytes repack | equal or same failure |
| AC-3 | int for Bytes/Sized | `ArgumentException` |
| AC-4 | existing suite | unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | `listgroup` shape from the ring | repack of a packet other packages wrote | original bytes | — |

## Constraints

- Files stay at or under 500 lines.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none | — | resolved | Low |
