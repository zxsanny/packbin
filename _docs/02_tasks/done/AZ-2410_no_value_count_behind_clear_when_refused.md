---
loop: 22
branch: dev
---

# No-value count behind a clear when is refused for bits, packed and sized in all six packages

**Task**: AZ-2410_no_value_count_behind_clear_when_refused
**Name**: No-value count behind a clear when is refused for bits, packed and sized in all six packages
**Description**: A `bits`/`packed`/`sized` member whose count sits in the row behind a clear `when`, with no value for the member, is refused like the same shape under `times`.
**Complexity**: 3 points
**Dependencies**: none
**Component**: typescript (reference), python, java, csharp, rust, cpp
**Tracker**: AZ-2410
**Epic**: AZ-2069

## Problem

Owner decision U11 of loop 22 (option A, same rule as U6). Row 56 of `_docs/03_implementation/reference_loop21_slots.md`: scheme `u8(0,mode), when(1, eq(0,1), [u8(1,c)])` then a `bits(2,v,1)`, `packed(1,2,v,1)` or `sized(2,v,1)` member in a split bit or a combined `flags`, row `{mode:0, c:3}` with no value, packs the clear bit `010000` in six packages. The same shape under `times` is refused since loop 21 (U6). The no-value row and the with-value row (rows 53 to 55) must follow one rule.

## Outcome

- The no-value row is refused in all six packages with a named error that says the count `c` is 3 in the row but no field wrote it (the when that holds it is clear); no bytes.
- Count 0 and the count left out still pack unchanged. The with-value rows (53 to 55) and every accepted row keep their bytes.

## Scope

### Included
- The pack walk for `bits`, `packed`, `sized` in a split bit and in a combined `flags`, and the plain position (probe: plain already refuses `count c was not written`).
- TypeScript first: it writes `_docs/03_implementation/reference_loop22.md` (scheme, row, outcome, hex, error text) for U11; other packages align to it.

### Excluded
- Unpack. A new wire byte. C++ flash beyond the 40 B margin (C++ probes first; if it differs and the arm stage passes 8 192 B / 512 B it changes, else the saving needed goes to the loop 23 handoff).

## Acceptance Criteria

**AC-1: refused**
Given the row 56 shape for each of `bits`, `packed`, `sized`, in a split bit and in a combined `flags`
When packed in each package
Then an error naming the count and the clear `when`, and no bytes.

**AC-2: count 0 and left-out count pack**
Given the same schemes with count 0, or with the count left out
When packed
Then `0100025a00`-style bytes unchanged from HEAD.

**AC-3: with-value rows unchanged**
Given rows 53 to 55
When packed
Then the outcomes of loop 21 (refused or the same hex).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | 3 members x 2 positions | error, no bytes |
| AC-2 | count 0, count absent | HEAD bytes |
| AC-3 | rows 53 to 55 | unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | hostile `pack` stage | `pack_novalue_count_clear_when_*` (AZ-2417) | error in six | — |

## Constraints

- Wire bytes of accepted rows unchanged. TypeScript lands first and writes the reference rows; the other five align to them.

## Parent decision after the TypeScript reference (2026-10-12)

Reference section 1. The text is `<m>: the count <c> is <N> in the row, but no field wrote it (the when that holds it is clear), so the member reads nothing; give the count 0, leave it out, or make the when hold`. Only the six no-value `c:3` cells (3 kinds x split bit and combined `flags`) change; count 0, count left out, a holding `when` with no value (`01010300`) and rows 53 to 55 are unchanged; `packed` compares the count after the bias.

## Loop 22 result

Refused in six (C++ already refused every such row: a typed row has no "no value" for a `bits`, `packed` or `sized` member, so it also refuses count 0, no count and a holding `when`, which the other five pack). `<m>: the count <c> is <N> in the row, but no field wrote it (the when that holds it is clear), so the member reads nothing; give the count 0, leave it out, or make the when hold`; count 0, count left out, a holding `when` and rows 53 to 55 pack as before; `packed` compares the count after the bias. TypeScript, Python, Java, C#, Rust changed. Tests: `loop22-novalue-count.test.ts`, `test_loop22_parity.py`, `ClearBitProbesTest`, `CountBehindClearWhenTests`, `loop22_parity_tests.rs`, `held_count_nested_late_host_tests.cpp`; hostile `pack_novalue_count_clear_when_{bits,packed,sized}`. Open: nested positions are not pinned (gap G3), TypeScript bigint count above 2^53 (U23).
