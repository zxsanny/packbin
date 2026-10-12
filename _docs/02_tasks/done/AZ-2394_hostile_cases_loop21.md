---
loop: 21
branch: dev
---

# Hostile pack cases for the loop 21 parity rules and empty round bodies

**Task**: AZ-2394_hostile_cases_loop21
**Name**: Hostile pack cases for the loop 21 parity rules and empty round bodies
**Description**: `fixtures/hostile` gains the `pack` cases named in the loop 21 specs, replayed by the six loaders.
**Complexity**: 2 points
**Dependencies**: AZ-2381 to AZ-2391 (the rules), wave 2
**Component**: fixtures
**Tracker**: AZ-2394
**Epic**: AZ-2069

## Problem

Each parity rule of loop 21 needs a shared fixture so a seventh package (Go) inherits it.

## Outcome

- Cases added: `pack_round_slots_*`, `pack_flags_short_list`, `pack_split_times_absent_body`, `pack_late_when_in_bit_body`, `pack_count_one_clear_when`, `pack_bits_count_clear_when` (and two siblings), `pack_empty_round_body`; the file stays valid for all six loaders.

## Scope

### Included
- `fixtures/hostile/**`.

### Excluded
- Loader code except a new stage name.

## Acceptance Criteria

**AC-1: cases replay**
Given the new cases
When the six loaders run
Then each passes with the outcome in the case row

**AC-2: existing cases**
Given the 40 existing cases
When run
Then unchanged

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | new cases | pass in six |
| AC-2 | existing cases | pass |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | hostile stage | new rows | six loaders pass | — |

## Constraints

- Owns `fixtures/hostile/**` only.

## Loop 21 result

`fixtures/hostile/cases.txt` holds 55 cases (40 + 15): `pack_round_slots_at_limit`, `_over_limit`, `_flags_at_limit`, `_flags_over_limit`, `pack_flags_short_list`, `pack_flags_short_list_filled`, `pack_split_times_absent_body`, `pack_late_when_in_bit_body`, `pack_count_one_clear_when`, `pack_bits_count_clear_when`, `pack_packed_count_clear_when`, `pack_sized_count_clear_when` and the `construct` cases `construct_empty_times_body`, `construct_empty_repeat_body`, `construct_empty_round_body_list_element`. C++ skips seven and Rust two, each with a stated reason in the fixture README; `check-cases.sh` reports `hostile cases ok: 55`. Open (batch report row 11): check the older TypeScript `row4_packed_*` schemes against the fixture README width.
