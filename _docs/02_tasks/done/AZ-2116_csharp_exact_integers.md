# C# unpack returns exact integer types

**Task**: AZ-2116_csharp_exact_integers
**Name**: C# unpack returns exact integer types
**Description**: `ReadScalar` (`csharp/Walker.Scalars.cs:79-109`) boxes every unpacked integer as `double`, so `u64`/`i64` above 2^53 come back rounded.
**Complexity**: 3 points
**Dependencies**: None
**Component**: csharp
**Tracker**: AZ-2116
**Epic**: AZ-2069

## Status

Done by AZ-2123 (loop 11, commit `c9c6572`), found in the loop 15 todo audit (2026-10-06): `ReadScalar` (`csharp/Walker.Scalars.cs:79-93`) now returns `ulong` and `long` for `u64` and `i64`, so values above 2^53 keep their exact value (`TopRangeU64_DoesNotThrowAndKeepsTheExactValue`, `csharp/tests/TopRangeAndSessionTests.cs:53-57`, and the round trip at line 80); the README documents the change (`README.md`, "In C# a `u64` or `i64` field arrives ... as `ulong` or `long`"). The narrower kinds (`u8` to `u32`, `f32`) still box as `double`, which is exact for every value they can hold. The Problem text below describes the code before AZ-2123.

## Problem

`ReadScalar` (`csharp/Walker.Scalars.cs:79-109`) boxes every unpacked integer as `double`, so `u64`/`i64` above 2^53 come back rounded. Counts clamp around it (`TryUnpackCount`).

## Outcome

Each AC below passes in the named package(s); wire bytes of packets that work today do not change.

## Scope

### Included
- csharp: the change and tests named in the ACs.

### Excluded
- Error kind and label of any error value (C15).
- Other packages.

## Acceptance Criteria

**AC-1**
Given `u64` value 2^63+1, When packed and unpacked, Then the exact value is returned

**AC-2**
Given every existing test and the golden vector, When they run, Then they pass unchanged; the public row type stays compatible or the change is documented

## Constraints

- ADR-001: no shared walker, no import from another package.
- Files stay at or under 500 lines.

## Risks & Mitigation

- *Risk*: scope creep into neighbouring tickets. *Mitigation*: Not urgent. Source: loop 11 feature-assess U3.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Written from a feature-assess row; refine the Given/When/Then with the implementer before the loop that takes it | coordinator | open | Low |
