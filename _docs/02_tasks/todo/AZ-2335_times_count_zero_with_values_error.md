---
loop: 19
branch: dev
---

# A `times` count of 0 with values given is an error naming the member in every package, inside and outside `flags`

**Task**: AZ-2335_times_count_zero_with_values_error
**Name**: times count 0 with values is an error
**Description**: A `times` count of 0 with values given is an error naming the member in every package, inside and outside `flags`.
**Complexity**: 2 points
**Dependencies**: AZ-2304 (done)
**Component**: all six (probe first)
**Tracker**: AZ-2335
**Epic**: AZ-2069

## Problem

Owner decision 7 (assessment U6) of loop 19 (2026-10-11, option A, accepted as recommended). Inside `flags` and, since loop 18, in C++ outside `flags` this is an error; the other packages outside `flags` were not probed.

## Outcome

- Every package refuses count 0 with values, naming the member.

## Scope

### Included
- Probe table, refusal where it differs, tests.

### Excluded
- Count 0 with no values (packs nothing, stays valid).

## Acceptance Criteria

**AC-1: count 0 with values refused**
Given a `times` scheme, count 0 and a list with one value
When packed
Then error naming the member in all six

**AC-2: count 0 without values packs**
Given count 0 and no values
When packed
Then zero rounds written

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | count 0 + values | error |
| AC-2 | count 0, none | bytes unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | hostile `pack` stage | `pack_times_zero_with_values` | error, six packages | — |

## Constraints

- ADR-001.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Callers that pass a stale list with count 0 break (upgrade note) | owner decision 7 | resolved | Low |
