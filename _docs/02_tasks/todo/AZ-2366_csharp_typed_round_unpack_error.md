---
loop: 20
branch: dev
---

# A typed C# Unpack of a packet holding a set round returns an error result instead of throwing, and the collection member checks run inside repeat and times bodies

**Task**: AZ-2366_csharp_typed_round_unpack_error
**Name**: C# typed round unpack error
**Description**: A typed C# Unpack of a packet holding a set round returns an error result instead of throwing, and the collection member checks run inside repeat and times bodies.
**Complexity**: 2 points
**Dependencies**: AZ-2305 (done)
**Component**: csharp
**Tracker**: AZ-2366
**Epic**: AZ-2069

## Problem

Security F17 and F27. `Repeat(0, U8 V)` with the packet `03 01 02` throws `InvalidCastException: Object must implement IConvertible` out of typed `Unpack` (`csharp/RowBinding.cs` `ApplyField`/`SetValue`, reached from `SchemeHandler<T>.Dispatch`); a receive loop without a catch stops. F27: `csharp/SchemeOrder.cs` skips `RequireCollection` inside a round (`!inRound`), so once rounds bind, a `List<int>` of `u32` in a round would throw `OverflowException` again. Problem D5: binding typed rounds to a collection of rows stays out of scope.

## Outcome

- Typed `Unpack` of a set round returns the package's typed error result (the same kind it returns for a bad value), never an exception.
- The collection member checks run for a `list` or `dict` inside a `repeat` or `times` body: `List<int>` with a `u32` element in a round fails at construction.

## Acceptance Criteria

**AC-1: no exception**
Given `Repeat(0, U8 V)` (type 3) and the packet `03 01 02`, and a `times` and a `flags`-member round
When unpacked with typed `Unpack`
Then an error result naming the field, no exception

**AC-2: checks in rounds**
Given `Repeat(0, List((Row x) => x.Ids, U32(...)))` with `List<int> Ids`, and the same in `Times`
When the scheme is built
Then refused at construction, naming the member; `List<long>` builds

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | typed unpack of rounds | error result |
| AC-2 | narrow collection in round | refused at construction |

## Constraints

- Wire bytes of every accepted row are unchanged.
