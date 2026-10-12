---
loop: 21
branch: dev
---

# bits, packed and sized counts behind a clear when are refused in all six

**Task**: AZ-2387_bits_packed_sized_count_behind_clear_when
**Name**: bits, packed and sized counts behind a clear when are refused in all six
**Description**: C#, Python, Java and Rust are probed for a `bits`/`packed`/`sized` count behind a clear `when` and aligned to refuse, as C++ and TypeScript do.
**Complexity**: 3 points
**Dependencies**: AZ-2386 (same walk in Python)
**Component**: csharp, python, java, rust
**Tracker**: AZ-2387
**Epic**: AZ-2069

## Problem

Owner decision U7 of loop 21 (option A). `bits`/`packed`/`sized` counts behind a clear `when`: C++ and TypeScript refuse; C#, Python, Java and Rust were not probed.

## Outcome

- Probe results per package in the batch report; every package that differs refuses with a named error.

## Scope

### Included
- The pack walk for the three count kinds.

### Excluded
- Wire bytes.

## Acceptance Criteria

**AC-1: refused**
Given a `bits`, `packed` or `sized` count behind a clear `when`
When packed in each package
Then an error and no bytes

**AC-2: set `when` packs**
Given the `when` set
When packed
Then unchanged

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | three kinds per package | error |
| AC-2 | set `when` | unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | hostile `pack` stage | `pack_bits_count_clear_when` and two siblings (AZ-2394) | error in six | — |

## Constraints

- Wire bytes of accepted rows unchanged.

## Loop 21 result

A `bits`, `packed` or `sized` given a value while its count sits behind a clear `when` is refused in all six (TypeScript `v: count c was not written`; Java `IllegalStateException`, Python `RuntimeError`, accepted differences). With no value a split bit or combined `flags` packs a clear bit (`01 00 00`) in all six, while the `times` shape is refused: owner row U11 for loop 22. Tests as AZ-2386; hostile `pack_bits_count_clear_when`, `pack_packed_count_clear_when`, `pack_sized_count_clear_when`.
