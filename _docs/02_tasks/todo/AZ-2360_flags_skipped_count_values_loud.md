---
loop: 20
branch: dev
---

# In a combined flags, a times whose count is skipped while the row gives values is refused naming the member in all six packages

**Task**: AZ-2360_flags_skipped_count_values_loud
**Name**: Combined flags skipped count is loud
**Description**: In a combined flags, a times whose count is skipped while the row gives values is refused naming the member in all six packages.
**Complexity**: 2 points
**Dependencies**: AZ-2331 (done)
**Component**: csharp, typescript, java, rust (change); python, cpp (pin)
**Tracker**: AZ-2360
**Epic**: AZ-2069

## Problem

Owner decision 9 of loop 20 (review B6, option A). Combined `flags`, skipped count with values: loud in Python (`python/src/packbin/_pack.py:79-85`) and C++, silent in C#, TypeScript (`typescript/src/flag-bits.ts:60-62`), Java and Rust. AZ-2331 AC-2 wording ("skipped count with values is refused") covers it.

## Outcome

- Six packages refuse `{pt: [5, 6]}` with the count skipped in a combined `flags`, naming the member; with no values the bit packs clear as today.

## Acceptance Criteria

**AC-1: refused**
Given a combined `flags` whose `times` count is skipped and the row `{pt: [5, 6]}`
When packed in each of the six packages
Then an error naming `pt`

**AC-2: no values still packs**
Given the same scheme and no `pt`
When packed
Then the same hex in six packages as today

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | skipped count + values | error, six |
| AC-2 | skipped count, no values | hex unchanged |

## Constraints

- Wire bytes of every accepted row are unchanged.
