---
loop: 21
branch: dev
---

# A short list in an optional flags position is refused everywhere

**Task**: AZ-2383_short_list_in_optional_flags
**Name**: A short list in an optional flags position is refused everywhere
**Description**: TypeScript refuses a short list in an optional flags position, as Python does; the other four are probed and aligned.
**Complexity**: 2 points
**Dependencies**: none (TypeScript first for the hex row)
**Component**: typescript, python, java, csharp, rust
**Tracker**: AZ-2383
**Epic**: AZ-2069

## Problem

Owner decision U3 of loop 21 (option A). TypeScript packs a short list in an optional flags position as `010101050200`; Python refuses it.

## Outcome

- Refused in all five growable packages with a named error; the probe results of Java, C# and Rust are recorded in the batch report.

## Scope

### Included
- The pack walk for an optional flags position holding a list shorter than its count.

### Excluded
- C++ (fixed arrays) unless its probe differs.

## Acceptance Criteria

**AC-1: refused**
Given the U3 scheme and a short list
When packed in each package
Then an error naming the member and no bytes

**AC-2: full list packs**
Given a list of the right length
When packed
Then the same bytes as today

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | short list per package | error |
| AC-2 | full list | same bytes |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | hostile `pack` stage | `pack_flags_short_list` (AZ-2394) | error in six | — |

## Constraints

- Wire bytes of accepted rows unchanged.
