---
loop: 20
branch: dev
---

# C++ Field::late marks every late when or times of a flag bit, not only the first

**Task**: AZ-2364_cpp_late_marks_every_member
**Name**: C++ late marks every member
**Description**: C++ Field::late marks every late when or times of a flag bit, not only the first.
**Complexity**: 1 points
**Dependencies**: AZ-2331 (done)
**Component**: cpp
**Tracker**: AZ-2364
**Epic**: AZ-2069

## Problem

Loop 20 clear gap G4 (review loop 19 C2, `order.hpp:182-194`, `pack.cpp:81`). `mark_late` stores only the first late `when`/`times` of a bit: `bit(group(when(eq(0,1) a), when(eq(0,2) b)))` with mode 2 and `b` given packs; the other packages refuse.

## Outcome

- C++ returns `BadValue` naming `b` for that row; arm stack and flash measured (with AZ-2357 and AZ-2356).

## Acceptance Criteria

**AC-1: refused**
Given `bit(group(when(eq(0,1) a), when(eq(0,2) b)))`, mode 2, `b` given
When packed in C++
Then `BadValue` naming `b`

**AC-2: budgets**
Given the arm embedded stage
When run
Then stack ≤ 512 B and flash ≤ 8 192 B; margins in the batch report

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | two late whens | BadValue |
| AC-2 | arm stage | within budget |

## Constraints

- Wire bytes of every accepted row are unchanged.

## Loop 20 result (wave 1a, 2026-10-11)

Done: `Field::late` is a chain (the flag bit points to its first late `when`/`times`, each one to the next); `mark_late` marks every late member. A link of more than 255 entries between two late `when`s of one bit is `SchemeInvalid` at the later one. Final arm numbers: see AZ-2357 (flash margin 80 B, stack unchanged); `pack_flag_byte` frame 48 to 56 B, not on the deepest measured path.
