---
loop: 37
branch: dev
---

# Compact text: guard against a large local Scratch in C++

**Task**: AZ-2674_scratch_frame_guard
**Name**: Compact text: guard against a large local Scratch in C++
**Description**: Compact text: guard against a large local Scratch in C++
**Complexity**: 2 points
**Dependencies**: None
**Component**: compact-text
**Tracker**: AZ-2674
**Epic**: AZ-2645

## Problem

`Scratch<65535>` is a 786 KB object; declared as a local it overflows the stack of a server thread or a Raspberry Pi (review35 finding 2).

## Outcome

- A large `Scratch` as a local variable fails the host C++ build.

## Scope

### Included
- `cpp/Makefile` flag `-Wframe-larger-than=<limit>` (limit above the largest legitimate frame, measured); a comment in `core.hpp` and a line in the C++ README section ("make a large scratch static"); a check script with a mutant.

### Excluded
- Any code change in `cpp/include` or `cpp/src/core` (Cortex-M4F margins 60 B flash, 20 B stack); the embedded builds.

## Acceptance Criteria

**AC-1: Local large Scratch is refused**
Given a file with `Scratch<65535>` as a local and one with it static
When each is compiled with the Makefile flags
Then the first fails and the second passes (RL-1)

**AC-2: Existing build stays green**
Given the flag
When `make -C cpp test` runs on the host and in `gcc:16`
Then it passes with flash 8,132 B and stack 492 B unchanged

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | check script + mutant (flag removed) | fails without the flag |
| AC-2 | full C++ test | pass |


## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none beyond `problem.md` | — | resolved | Low |
