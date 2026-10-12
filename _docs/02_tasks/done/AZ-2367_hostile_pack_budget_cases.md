---
loop: 20
branch: dev
---

# Hostile pack cases for the output budget, the repeat cap and the loop 20 parity shapes are added and replayed by all six loaders

**Task**: AZ-2367_hostile_pack_budget_cases
**Name**: Hostile pack cases
**Description**: Hostile pack cases for the output budget, the repeat cap and the loop 20 parity shapes are added and replayed by all six loaders.
**Complexity**: 2 points
**Dependencies**: AZ-2354, AZ-2355, AZ-2356, AZ-2360
**Component**: fixtures/hostile (wave 2, one worker); loader test files only if a stage name is new
**Tracker**: AZ-2367
**Epic**: AZ-2069

## Problem

Loop 20 wave 2. The hostile `pack` stage stops at the count (`pack_times_count_over_limit`); F28 asks for `pack_lone_utf8_under_times_over_budget` and `pack_element_times_over_budget`.

## Outcome

- New cases in `fixtures/hostile/cases.txt`: `pack_lone_utf8_under_times_over_budget`, `pack_element_times_over_budget`, `pack_slots_over_limit`, `pack_repeat_over_limit`, `pack_split_count_zero_after_byte_list`, `pack_flags_skipped_count_with_values`; C++ skips the budget cases with a reason (caller buffer). `check-cases.sh` and the README of the set updated.

## Acceptance Criteria

**AC-1: replayed**
Given the new cases
When the six hostile loaders run
Then each package gives the case's expected outcome (or a recorded skip with reason)

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | six loaders | expected outcomes |

## Constraints

- Wire bytes of every accepted row are unchanged.
