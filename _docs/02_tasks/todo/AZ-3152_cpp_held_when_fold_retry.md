---
loop: 57
branch: dev
---

# C++ held-`when` fold retry

**Task**: AZ-3152_cpp_held_when_fold_retry
**Name**: C++ held-`when` single path, retry
**Description**: The `When` and `FlagBit` handling of `unpack_children` and `unpack_one` is one function within the flash and stack budgets, or not made with the figures recorded.
**Complexity**: 3 points
**Dependencies**: AZ-3151
**Component**: `cpp/src/core/unpack.cpp`, `cpp/embedded/`, `cpp/tests/core`
**Tracker**: AZ-3152
**Epic**: AZ-2645

## Problem

The held-`when` and flag-bit handling exists twice (review #1 of loop 55, Medium). The loop 56 fold (one NOINLINE `unpack_held`) cost +60 B of flash and 676 B net stack, because each `when` level got its own frame.

## Outcome

- One function owns the handling and both callers use it, with `unpack_held` inlined into `unpack_children` and no larger frame; or the fold is restored and the figures recorded.

## Scope

### Included
- The fold try after AZ-3151; the stack and flash figures of the try.

### Excluded
- Any wire change; a depth limit (owner decision); other packages.

## Acceptance Criteria

**AC-3: Fold kept only within budget** — Given the Cortex-M4F image, When the fold is built, Then it is kept only if flash is at most 8,080 B and the stack of the 3-deep chain, the flag-byte chain and the round chain is not above 504 B, 500 B and 436 B.

**AC-4: Not kept** — Given the fold does not fit, When tried, Then the code is restored by hand and the report gives the flash and stack figures; that is an accepted outcome.

**AC-5: Packets unchanged** — Given the hostile and differential corpora, When run, Then host, `gcc:16` and arm stages pass with no new skip, whichever way AC-3 goes.

## Non-Functional Requirements

**Compatibility**: no wire change.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-3, AC-4 | arm embedded stage flash and stack figures | within bounds, or recorded and restored |
| AC-5 | host, `gcc:16`, arm suites; corpora | pass, 0 differences |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The fold may fail again (flash or stack) | allowed outcome: not made | open | Medium |
| Stack margin 8 B | measure before commit | open | Medium |
