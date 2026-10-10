---
loop: 18
branch: dev
---

# C# a non-null nested row with all members null counts as present under flags

**Task**: AZ-2306_csharp_empty_nested_row_present
**Name**: C# empty nested row is present
**Description**: A non-null typed nested row object under a flags group sets the group's bit even when every member is null, and pack then fails naming the first missing member.
**Complexity**: 1 point
**Dependencies**: AZ-2128_flag_group_presence_parity (C# part, done in loop 17)
**Component**: csharp
**Tracker**: AZ-2306
**Epic**: AZ-2069

## Problem

Owner decision 3 of loop 18 (2026-10-10, option B; assessment D2). A typed nested row object that is non-null but has only null members leaves its flags group's bit clear, so the object disappears from the packet with no error, while a set group with a null nested row fails loudly. Every other loud-pack rule since loop 11 turns a silent drop into an error.

## Outcome

- The object itself is a value that is present; handing one in is never silently dropped.

## Scope

### Included
- C# typed `Pack` presence for a nested row object under `Flags` or a flag-bit group, at any depth.

### Excluded
- A null nested row (stays absent); dictionary rows; other packages.

## Acceptance Criteria

**AC-1: an all-null object is present**
Given a typed row with a flags group holding a nested row object whose members are all null
When it is packed
Then the group's bit is set and pack fails with `ArgumentException` naming the first missing member of the nested row

**AC-2: a null nested row stays absent**
Given the same row with the nested row set to null
When it is packed
Then the bit is clear and the bytes equal today's bytes

**AC-3: a filled object is unchanged**
Given the nested row with its required members set
When packed and unpacked
Then the bytes and the unpacked row equal today's

## Non-Functional Requirements

**Compatibility**
- A caller that builds empty placeholder objects now gets an error (upgrade note).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | all-null object under flags, depth 1 and 2 | `ArgumentException` naming member |
| AC-2 | null nested row | bytes unchanged |
| AC-3 | filled object | bytes unchanged, round trip |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | existing fixtures | golden and route | unchanged | — |

## Constraints

- Files stay at or under 500 lines.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Behavior change for callers that pass empty placeholder objects | owner decision 2026-10-10 | resolved | Low |

## Loop 18 result (2026-10-10)

Done in loop 18 wave 1 (csharp). A non-null typed nested row counts as present in `GroupOn`; pack fails naming the first missing member; null stays `0100`; the filled depth-2 row packs `01010406`. `EmptyNestedRowTests`.
