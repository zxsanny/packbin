---
loop: 10
branch: loop/10-cpp-microcontroller
---

# C++ core on 8-bit AVR (stretch)

**Task**: AZ-2068_cpp_avr_build
**Name**: C++ AVR build
**Description**: The core builds with avr-gcc for an Arduino Uno, with `f64` refused at compile time.
**Complexity**: 3 points
**Dependencies**: AZ-2066_cpp_target_ci
**Component**: cpp
**Tracker**: AZ-2068
**Epic**: AZ-2059

## Problem

avr-gcc 7.3 has no C++ standard library and a 4-byte `double`, so the core's remaining standard headers block an Uno build. Decision D-3 A makes this a stretch task outside the release criteria.

## Outcome

- The core builds with avr-gcc without `<type_traits>` / `<array>`.
- An Uno example builds in CI.

## Scope

### Included
- Removing the remaining standard-library use from the core for AVR; avr-gcc build in the AZ-2066 job; Uno example.

### Excluded
- Running on an AVR emulator; release criteria.

## Acceptance Criteria

**AC-1: AVR build**
Given the core and an Uno example using only `f32` and integer kinds
When it is compiled with avr-gcc
Then the build has 0 errors and 0 warnings.

**AC-2: f64 refused**
Given the same build and a scheme with `f64`
When it is compiled
Then compilation fails with a message naming `f64` (feature AC-9).

## Non-Functional Requirements

**Compatibility**
- The 32-bit targets from AZ-2066 stay green.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-2 | compile-fail with `f64` | message names `f64` |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | avr-gcc in CI image | build Uno example | pass | — |

## Constraints

- Decision D-3 A: stretch; not in the release criteria.

## Risks & Mitigation

**Risk 1: Hand-rolled traits**
- *Risk*: replacing `<type_traits>` adds code.
- *Mitigation*: only the traits the core uses; the 32-bit size budget (AZ-2066 AC-5) must still hold.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none | — | resolved | Low |
