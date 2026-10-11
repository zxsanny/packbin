---
loop: 19
branch: dev
---

# A C++ test pins `flags(group(flag_byte(0), flag_bit(0,x)))` with only `x` to `01 01 01 05`

**Task**: AZ-2340_cpp_present_result_pinned
**Name**: C++ present() result pinned
**Description**: A C++ test pins `flags(group(flag_byte(0), flag_bit(0,x)))` with only `x` to `01 01 01 05`.
**Complexity**: 1 points
**Dependencies**: AZ-2128 (done)
**Component**: cpp
**Tracker**: AZ-2340
**Epic**: AZ-2069

## Problem

Owner decision clear gap (assessment U4) of loop 19 (2026-10-11, option A, accepted as recommended). The AZ-2128 `present()` change closed U4 but no test pins the result.

## Outcome

- The test exists and passes.

## Scope

### Included
- One host test.

### Excluded
- Any behavior change.

## Acceptance Criteria

**AC-1: lone flag member packs**
Given `flags(group(flag_byte(0), flag_bit(0,x)))` with only `x`
When packed in C++
Then `01 01 01 05`

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | pack | hex equal |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | probe | C++ | hex | — |

## Constraints

- Host recipe gcc:16 `make test`.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none | coordinator | resolved | Low |

## Loop 19 result (2026-10-11)

Done in loop 19: C++ test pins `flags(group(flag_byte(0), flag_bit(0,x)))` with only `x` to `01010105`.
