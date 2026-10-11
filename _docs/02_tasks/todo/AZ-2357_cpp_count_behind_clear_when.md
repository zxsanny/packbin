---
loop: 20
branch: dev
---

# C++ pack refuses rounds whose count is set in the row but sits behind a clear `when`

**Task**: AZ-2357_cpp_count_behind_clear_when
**Name**: C++ count behind a clear when
**Description**: C++ pack writes rounds although their count is never written (`010003055a00`); refuse as the five other packages do.
**Complexity**: 2 points
**Dependencies**: AZ-2331 (done)
**Component**: cpp
**Tracker**: AZ-2357
**Epic**: AZ-2069

## Problem

Owner decision 5 of loop 20 (assessment U4, option A: fix in a loop without other C++ flash cost). A count set in the row but behind a clear `when` still lets rounds through in C++ (`010003055a00`); the other five refuse. Measured fix cost in loop 19: +56 B of the 128 B Cortex-M4F flash margin.

## Outcome

- C++ returns `BadValue` naming the member for that shape; the bytes of every accepted row unchanged.

## Scope

### Included
- `cpp/src/core` pack path; a host test; `docker run gcc:16 make test`; the arm embedded stage with the stack and flash numbers in the batch report.

### Excluded
- Other packages (already refuse).

## Acceptance Criteria

**AC-1: refused**
Given the loop 19 assessment U4 scheme and row (packs `010003055a00` today)
When packed in C++
Then `BadValue` naming the `times` member

**AC-2: budgets**
Given the arm embedded stage
When run
Then stack ≤ 512 B and flash ≤ 8 192 B, with the margins written in the batch report

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | U4 shape | BadValue |
| AC-2 | arm stage | within budget |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | gcc:16 container | `make test` | pass | — |

## Constraints

- Flash margin: stop and report if it goes below 32 B (with AZ-2364 and AZ-2356 together).

## Loop 20 result (wave 1a, 2026-10-11)

Done in `cpp/include/packbin/order.hpp`, `table.hpp`, `cpp/src/core/pack.cpp`: the count source and each `when` that holds it store, in the unused `Field::bit` byte, the distance back to the nearest `when` that holds them; pack follows the links in `item_count`. Arm Cortex-M4F: flash 8112 of 8192 B (margin 80 B, was 128 B; AZ-2357 alone 8120), stack 448 of 512 B unchanged. New construction limit: a count more than 255 entries after the `when` that holds it is `SchemeInvalid` (C9 precedent). One accepted row changes: a plain `times` (no flag byte) with its count behind a clear `when`, count 0 and no rounds, packed `0100` before and is now refused; C++'s own unpack and Python's pack refuse that packet already (upgrade note, step 13).
