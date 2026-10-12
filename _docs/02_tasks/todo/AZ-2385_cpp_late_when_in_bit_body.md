---
loop: 21
branch: dev
---

# C++ packs a direct late when in a bit body when another child sets the bit

**Task**: AZ-2385_cpp_late_when_in_bit_body
**Name**: C++ packs a direct late when in a bit body when another child sets the bit
**Description**: C++ packs a direct late `when` in a bit body when another non-late child sets the bit, without costing flash on Cortex-M4F.
**Complexity**: 2 points
**Dependencies**: AZ-2364 (done)
**Component**: cpp
**Tracker**: AZ-2385
**Epic**: AZ-2069

## Problem

Owner decision U5 of loop 21 (option A, only if it costs no flash). C++ refuses a direct late `when` in a bit body even when another non-late child sets the bit; TypeScript packs it. The Cortex-M4F flash margin is 32 B (8160 of 8192 B).

## Outcome

- C++ packs the shape with TypeScript's bytes, or the worker stops and reports the flash cost with a saving needed first.
- The `Field::bit` and `Field::late` comments in `cpp/include/packbin/table.hpp` say what the code does (comment-only, flash-neutral).

## Scope

### Included
- `cpp/src/core` pack, `cpp/include`, C++ tests.

### Excluded
- AVR (AZ-2068).

## Acceptance Criteria

**AC-1: packs**
Given a bit body with a late `when` and another child that sets the bit
When packed in C++
Then TypeScript's bytes

**AC-2: budget**
Given the arm embedded stage
When run
Then flash at or under 8 192 B and stack at or under 512 B, or the change is dropped and recorded

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | the shape | equal bytes |
| AC-2 | arm stage | within budget |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | hostile `pack` stage | `pack_late_when_in_bit_body` (AZ-2394) | packs in six | — |

## Constraints

- `docker run --rm -v "$PWD":/src -w /src/cpp gcc:16 make test` and the arm embedded stage before the batch ends.
- No formatter on files the worker does not own.

## Loop 21 result

C++ packs a late `when` or `times` in a bit body when another non-late child sets the bit (`present(..., skip)` with `flag::Late`, `pack_flag_byte`); a body held only by late members is still refused. Rust got the same fix after the TypeScript reference (`early_on` in `walk/flag_bits.rs`). Arm stage: flash 8160 to 8152 B (margin 40 B), stack 448 to 456 B (margin 56 B). Tests: `late_source_host_tests.cpp`, `late_when_in_bit_body_tests.rs`; hostile `pack_late_when_in_bit_body` (run by all six).
