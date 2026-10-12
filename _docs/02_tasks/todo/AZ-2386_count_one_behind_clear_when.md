---
loop: 21
branch: dev
---

# Count 1 behind a clear when with no rounds is refused everywhere

**Task**: AZ-2386_count_one_behind_clear_when
**Name**: Count 1 behind a clear when with no rounds is refused everywhere
**Description**: Python refuses count 1 behind a clear `when` with no rounds, as C++ does; the other packages are probed and aligned.
**Complexity**: 2 points
**Dependencies**: none
**Component**: python (change), typescript, java, csharp, rust (probe, align)
**Tracker**: AZ-2386
**Epic**: AZ-2069

## Problem

Owner decision U6 of loop 21 (option A). Count 1 behind a clear `when` with no rounds: Python packs `0100025a00`, C++ refuses.

## Outcome

- Refused in every package with a named error; wire bytes of accepted rows unchanged.

## Scope

### Included
- The pack walk for a count behind a clear `when`.

### Excluded
- Unpack.

## Acceptance Criteria

**AC-1: refused**
Given count 1 behind a clear `when` and no rounds
When packed in each package
Then an error and no bytes

**AC-2: count 0 packs**
Given count 0
When packed
Then unchanged

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | the shape | error |
| AC-2 | count 0 | unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | hostile `pack` stage | `pack_count_one_clear_when` (AZ-2394) | error in six | — |

## Constraints

- Wire bytes of accepted rows unchanged.

## Loop 21 result

Pack refuses a `times` count above 0 that no field wrote (its `when` is clear) in a split bit and in a combined `flags` (`pt: the count c is 1 in the row, but no field wrote it (the when that holds it is clear), so its times reads no round; give the count 0, leave it out, or make the when hold`). TypeScript and Python changed, Java, C# and Rust were aligned; C++ already refused it. A count of 0 or none still packs a clear bit. Tests: `loop21-parity-probes.test.ts`, `test_loop21_parity_probes.py`, `ClearBitProbesTest`, `CountBehindClearWhenTests`, `count_behind_clear_when_tests.rs`; hostile `pack_count_one_clear_when`.
