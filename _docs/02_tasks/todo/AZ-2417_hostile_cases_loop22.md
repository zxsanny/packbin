---
loop: 22
branch: dev
---

# Hostile cases for the loop 22 rules

**Task**: AZ-2417_hostile_cases_loop22
**Name**: Hostile cases for the loop 22 rules
**Description**: `fixtures/hostile` gains pack and unpack cases for U11, U13, U14, U15, U17 and G1, loaded by the hostile loaders, with rule-table entries in each loader.
**Complexity**: 2 points
**Dependencies**: AZ-2410, AZ-2412, AZ-2413, AZ-2414, AZ-2415, AZ-2416
**Component**: fixtures/hostile, then loaders in python, java, rust, cpp, typescript, csharp tests
**Tracker**: AZ-2417
**Epic**: AZ-2069

## Problem

Wave 2 of loop 22. The 55 hostile cases of loop 21 pin the previous rules; the loop 22 rules need cases in the shared set so the six packages (and Go) are held to one outcome. The new default `maxSlots` changes the numbers in the existing `pack_slots_over_limit` family.

## Outcome

- New cases: `pack_novalue_count_clear_when_{bits,packed,sized}` (refused in six), `pack_repeat_lists_without_groups` (Rust refuses; the rule table says what the five others pack), `pack_repeat_unequal_lists_*` (same bytes in six), `pack_times_short_list_flags` (same bytes in six), empty-`when` round body `scheme_error` rows, slots-over-limit cases at the new default.
- The existing slots-over-limit texts and any case whose totals sit between the old and new default are updated (done in AZ-2415 for package tests; this task owns the fixture files `fixtures/hostile/**`).
- Each loader's rule table gets the new rows (its own outcome per case).

## Scope

### Included
- `fixtures/hostile/cases.txt`, vector files, `README.md`, `check-cases.sh`, `cases.test.sh`; the loader test files of the six packages (one worker per directory, after the fixtures).

### Excluded
- Package sources.

## Acceptance Criteria

**AC-1: cases exist**
Given the fixture set
When `check-cases.sh` runs
Then every new case parses and the count is 55 plus the new cases.

**AC-2: six loaders agree**
Given the loaders
When each runs the full set
Then every case matches its rule-table outcome in all six.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `check-cases.sh`, `cases.test.sh` | pass |
| AC-2 | six loader suites | pass |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | hostile set | all stages | same outcome per rule table | — |

## Constraints

- Runs after wave 1 (the rules must be in).
