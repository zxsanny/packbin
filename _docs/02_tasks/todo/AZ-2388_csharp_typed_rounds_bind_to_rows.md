---
loop: 21
branch: dev
---

# C#: typed rounds bind to a collection of rows

**Task**: AZ-2388_csharp_typed_rounds_bind_to_rows
**Name**: C#: typed rounds bind to a collection of rows
**Description**: A typed C# round binds to a collection of row objects, the Rust direction, instead of only object-typed or collection members.
**Complexity**: 5 points
**Dependencies**: AZ-2366 (done), AZ-2389; before the Go package
**Component**: csharp
**Tracker**: AZ-2388
**Epic**: AZ-2069

## Problem

Owner decision U8 of loop 21 (option A). Typed C# rounds bind only to object-typed or collection members (loop 20 D5, assessment F17/F27 follow-up). The Go package will copy the Rust model, so the C# model is settled first.

## Outcome

- A typed `Repeat`/`Times` member binds to a collection whose element type is a row class; pack and unpack round-trip it.
- The README round section describes the binding; the old bindings that stay valid keep working.

## Scope

### Included
- `csharp/` typed binding, builder checks, README.

### Excluded
- Other packages.

## Acceptance Criteria

**AC-1: rows bind**
Given a typed `Repeat(0, U8 V)` and a `List<Row>` member
When packed and unpacked
Then the rows round-trip with the same bytes

**AC-2: construction checks**
Given a member type that cannot hold the rounds
When the scheme is built
Then it fails at construction (U9 rule)

**AC-3: old bindings**
Given the existing typed round tests
When run
Then they pass

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | row collection round trip | equal bytes |
| AC-2 | unbindable member types | construction error |
| AC-3 | existing tests | pass |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | ring | C# row round trip through `language-pair.sh` | bytes equal the other five | — |

## Constraints

- The construction check is the binding's own predicate, tested as "builds if and only if it binds" (loop 20 lesson).
- Files at or under 500 lines.
