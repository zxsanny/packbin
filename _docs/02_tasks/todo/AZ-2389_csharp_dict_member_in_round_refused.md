---
loop: 21
branch: dev
---

# C#: a dictionary member in a round that cannot hold the rounds is refused at construction

**Task**: AZ-2389_csharp_dict_member_in_round_refused
**Name**: C#: a dictionary member in a round that cannot hold the rounds is refused at construction
**Description**: A C# dictionary member in a round whose type cannot hold the rounds fails when the scheme is built, not at pack time.
**Complexity**: 2 points
**Dependencies**: none
**Component**: csharp
**Tracker**: AZ-2389
**Epic**: AZ-2069

## Problem

Owner decision U9 of loop 21 (option A). A C# dict member in a round that cannot hold the rounds still builds and is pack-only; unpack can never fill it.

## Outcome

- The scheme builder refuses it with a named error.

## Scope

### Included
- C# construction checks.

### Excluded
- Packing of valid dictionary rounds.

## Acceptance Criteria

**AC-1: refused at build**
Given a dict member in a round that cannot hold the rounds
When the scheme is built
Then an error naming the member

**AC-2: valid dict rounds**
Given a dict member that can hold them
When built and packed
Then unchanged

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | the shape | construction error |
| AC-2 | valid shape | builds |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | none | unit tests only | - | — |

## Constraints

- Same predicate as the binding (see AZ-2388).
