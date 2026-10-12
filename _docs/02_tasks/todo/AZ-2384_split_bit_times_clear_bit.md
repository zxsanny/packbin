---
loop: 21
branch: dev
---

# Split-bit times with count above 0 after the byte and an absent body packs a clear bit everywhere

**Task**: AZ-2384_split_bit_times_clear_bit
**Name**: Split-bit times with count above 0 after the byte and an absent body packs a clear bit everywhere
**Description**: Java packs a clear bit like TypeScript and Python; C# and Rust are probed and aligned.
**Complexity**: 2 points
**Dependencies**: none
**Component**: java (change), csharp and rust (probe, align), typescript and python (pin)
**Tracker**: AZ-2384
**Epic**: AZ-2069

## Problem

Owner decision U4 of loop 21 (option A). Java refuses a split-bit `times` with count above 0 after the byte and the body absent or `[]` (pre-existing); TypeScript and Python pack a clear bit.

## Outcome

- Every growable package packs a clear bit for that shape; wire bytes equal TypeScript's.

## Scope

### Included
- The split-bit `times` pack path.

### Excluded
- C++ (refuses by its late rule, AZ-2385).

## Acceptance Criteria

**AC-1: clear bit**
Given a split-bit `times` and the body absent or `[]` with a count above 0 after the byte
When packed in each package
Then the bytes equal TypeScript's row

**AC-2: body present**
Given the body present
When packed
Then unchanged

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | absent and [] body | equal bytes |
| AC-2 | body present | unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | hostile `pack` stage | `pack_split_times_absent_body` (AZ-2394) | packs in five | — |

## Constraints

- Wire bytes of accepted rows unchanged.

## Loop 21 result

TypeScript and Python pin the clear bit `0102025a00`; Java was changed to pack it (it refused); C# and Rust were probed and pack it. C++ is excluded: a count above 0 with an empty `Array` is a count mismatch (`BadValue`). Tests: `ClearBitProbesTest`, `SplitTimesClearBitTests`, `loop21_parity_probes_tests.rs`, `test_loop21_parity_probes.py`, `loop21-parity-probes.test.ts`; hostile `pack_split_times_absent_body`.
