---
loop: 19
branch: dev
---

# C++ accepts `eq(emptyGroup, true)` as a `when` source, as Rust does

**Task**: AZ-2334_cpp_empty_group_when_source
**Name**: C++ empty group as a when source
**Description**: C++ accepts `eq(emptyGroup, true)` as a `when` source, as Rust does.
**Complexity**: 1 points
**Dependencies**: None
**Component**: cpp
**Tracker**: AZ-2334
**Epic**: AZ-2069

## Problem

Owner decision 6 (assessment U5) of loop 19 (2026-10-11, option A, accepted as recommended). C++ refuses an empty group as a `when` source; Rust accepts it.

## Outcome

- C++ builds and packs the scheme; the group counts as present when it has members written.

## Scope

### Included
- Accept the source kind, tests, host recipe (gcc:16 `make test`).

### Excluded
- Other packages.

## Acceptance Criteria

**AC-1: empty group source accepted**
Given `eq(emptyGroup, true)` as a `when` source
When built in C++
Then accepted, same bytes as Rust

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | scheme build and pack | equals Rust hex |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | probe | C++ vs Rust | equal | — |

## Constraints

- Stack budget of the arm embedded stage stays within 512 B (loop 18: 456 B).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Embedded stack margin is 56 B; the change must be measured | coordinator | open | Medium |
