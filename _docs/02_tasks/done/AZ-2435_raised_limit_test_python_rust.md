---
loop: 23
branch: dev
---

# Raised maxSlots unpacks the old worst packet: Python and Rust

**Task**: AZ-2435_raised_limit_test_python_rust
**Name**: Raised maxSlots unpacks the old worst packet: standing test in Python and Rust (G1)
**Description**: AZ-2415 AC-3 has a test in TypeScript, Java and C#, none in Python and Rust.
**Complexity**: 1 point
**Dependencies**: none
**Component**: python, rust (tests only)
**Tracker**: AZ-2435
**Epic**: AZ-2069

## Problem

Assessment22 gap G1. AZ-2415 lowered the default `maxSlots` to 1 048 576; AC-3 says a scheme with limits raised to 4 194 304 still unpacks the old worst packet. TypeScript (`loop22-max-slots.test.ts` AC-3), Java (`RoundLimitsTest`) and C# (`PackSlotBudgetTests.Ac3_..`) pin it; Python and Rust do not.

## Outcome

- Python: the F10 packet unpacks with `max_slots=4_194_304` and gives the same rows as at HEAD; the default limit refuses it.
- Rust: the 64-wide `times` packet unpacks with `with_limits(65_535, 4_194_304)`; the default refuses it.
- Test-only; no source change.

## Scope

### Included
- `python/tests/` (one test file), `rust/` test module (one file).

### Excluded
- Source changes; memory measurements (done in loop 22).

## Acceptance Criteria

**AC-1: raised limit unpacks**
Given the old worst packet and limits raised to 4 194 304 slots
When unpacked in Python and Rust
Then ok, rows as at HEAD.

**AC-2: default refuses**
Given the same packet and the default limits
When unpacked
Then the slot-limit error.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | raised limit, Python and Rust | unpacks |
| AC-2 | default limit | refused |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| — | covered by unit tests | — | — | resource limits |

## Constraints

- Mark the tests slow if the package has a slow marker; they allocate several hundred MB (loop 22 timing flakes under host load).
