---
loop: 22
branch: dev
---

# C# integer list given double, float or decimal elements is refused at construction

**Task**: AZ-2411_csharp_float_list_for_integer_refused
**Name**: C# integer list given double, float or decimal elements is refused at construction
**Description**: A scheme that binds a `List<double>` (or `float`, `decimal`) to an integer list builds and unpacks but its pack refuses it; construction refuses it so a scheme builds iff it packs.
**Complexity**: 2 points
**Dependencies**: none
**Component**: csharp
**Tracker**: AZ-2411
**Epic**: AZ-2069

## Problem

Owner decision U12 of loop 22 (option A, a breaking change). Since AZ-2373 (loop 21) unpack gives exact integer types and whole floats are refused for integer fields, but a typed member of type `List<double>`, `List<float>` or `List<decimal>` bound to an integer list builds and unpacks, then pack refuses it. Loop 20 lesson: a construction check mirrors the binding's own predicate and is tested as "builds if and only if it binds/packs".

## Outcome

- Building a scheme whose integer list or integer list element is bound to a `double`, `float` or `decimal` member (also arrays and other generic collections of them) throws a named construction error.
- Every list binding that packs today still builds; nothing else changes.
- An upgrade-note line (step 13) names the breaking change.

## Scope

### Included
- The integer-list member-type check in the C# scheme builder, and the C# README upgrade note input in the batch report.

### Excluded
- Float lists (`f32`/`f64` fields) keep accepting `double`/`float`; integer scalars (AZ-2373) unchanged; other packages.

## Acceptance Criteria

**AC-1: refused at build**
Given an integer list bound to `List<double>`, `List<float>`, `List<decimal>`, `double[]`
When the scheme is built
Then a construction error names the member and the type.

**AC-2: builds iff packs**
Given the matrix of 23 member types x U8/U32 element kinds x list kinds used by AZ-2388/AZ-2373 tests
When each scheme is built and a row is packed
Then every scheme that builds packs a row, and none that is refused would have packed.

**AC-3: float fields unaffected**
Given `f32`/`f64` list fields bound to `List<float>`/`List<double>`
When built and packed
Then unchanged.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | four types x two integer kinds | build error |
| AC-2 | the binding matrix | build iff pack |
| AC-3 | float lists | unchanged |

## Blackbox Tests

None (construction check in one package; the C# ring is unaffected).

## Constraints

- Breaking change only for schemes that already failed at pack time.
