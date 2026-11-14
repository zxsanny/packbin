---
loop: 127
branch: dev
---

# Rust: depth is checked before round_width in times/repeat, and the nostd depth check is linear

**Task**: AZ-4308_rust_depth_round_width_linear
**Name**: Rust: depth is checked before round_width in times/repeat, and the nostd depth check is linear
**Description**: Two follow-ups of AZ-4302.
**Complexity**: 3 points
**Dependencies**: AZ-4302 (done)
**Component**: rust
**Tracker**: AZ-4308
**Epic**: AZ-4133

## Problem
1. The `times(...)` and `repeat(...)` constructors call `round_width`, which recurses over their members before `MapScheme::new`; a very deep `when` chain inside one `times` can overflow the stack there, before the depth check (loop 126 worker report; the probe only tested 5,000 elements of a typed times).
2. The heap-free depth check descends once per level-opening entry (`parent_and_levels`): quadratic in the container count of a table of up to 32,768 entries.

## Outcome
- A `times` / `repeat` body nested deeper than 256 levels is refused with the contract text at construction (or `round_width` is iterative), never a stack overflow, at 1,000 / 5,000 / 50,000 levels.
- Measure the nostd check on a table of 32,768 container entries (a flat run of empty `when`s, and a wide tree); if it takes more than 50 ms on this Mac make it linear (one pass, no heap); otherwise record the measured figure in the test and leave it.

## Acceptance Criteria
**AC-1** Given a body of `when` chain 1,000 / 5,000 / 50,000 deep inside one `times` and one `repeat`, when the constructor runs, then it refuses with the text, quickly.
**AC-2** Given a 32,768-entry nostd table of containers, when validated, then it finishes within the measured bound (stated in the test) and the refusals of 257 levels are unchanged.
**AC-3** Given the device rows, when run, then pins hold, or move by 64 B of stack / 256 B of flash at most (set to the measured figure and report), else stop and report.
**AC-4** The whole Rust suite passes the way CI runs it.

## Constraints
Owns `rust/` only. No new public name or enum variant. `RUST_MIN_STACK` is set by CI; the new tests must pass without relying on it where they only construct.

## Flagged concerns
none
