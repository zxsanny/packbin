---
loop: 19
branch: dev
---

# A C# group element uses only its own members; it no longer inherits the outer row's values

**Task**: AZ-2337_csharp_group_element_members_only
**Name**: C# group element members only
**Description**: A C# group element uses only its own members; it no longer inherits the outer row's values.
**Complexity**: 2 points
**Dependencies**: AZ-2307 (done)
**Component**: csharp
**Tracker**: AZ-2337
**Epic**: AZ-2069

## Problem

Owner decision 9 (assessment U10) of loop 19 (2026-10-11, option A, accepted as recommended). A group element in C# can read the outer row's values; other packages scope an element to its members.

## Outcome

- C# packs a group element from its members only; a missing member is reported by name.

## Scope

### Included
- Probe row, restrict lookup, tests.

### Excluded
- Other packages (probe table).

## Acceptance Criteria

**AC-1: element ignores outer values**
Given an outer value with the same name as a missing element member
When packed in C#
Then error naming the missing member, as in TypeScript

**AC-2: complete elements unchanged**
Given elements with all members
When packed
Then bytes unchanged

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | missing member | error |
| AC-2 | complete element | unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | group rings | rings | unchanged | — |

## Constraints

- Typed rows and dictionary rows both covered.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Callers that relied on inheritance break (upgrade note) | owner decision 9 | resolved | Medium |

## Loop 19 result (2026-10-11)

Done in loop 19: a C# group element uses members only.
