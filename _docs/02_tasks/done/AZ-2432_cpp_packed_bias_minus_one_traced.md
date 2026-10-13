---
loop: 23
branch: dev
---

# C++ packed with bias -1 behind a clear when: trace, then document or align

**Task**: AZ-2432_cpp_packed_bias_minus_one_traced
**Name**: C++ packed with bias -1 behind a clear when: trace the refusal and document or align (U20)
**Description**: C++ refuses `packed` with bias -1 in every cell of the U11 grid where the five pack; find why, then write a README exception or align.
**Complexity**: 2 points
**Dependencies**: AZ-2431 (same worker, same files)
**Component**: cpp
**Tracker**: AZ-2432
**Epic**: AZ-2069

## Problem

Owner decision U20 A (2026-10-13). In the loop 22 U11 grid (`reference_loop22.md`), C++ refuses `packed` with bias -1 in every cell, including count 1 with no value behind a clear `when`, which TypeScript, Python, Java, C# and Rust pack as `010000`. The cause was not traced. C++ rows are typed structs, so "no value" may not be spellable, which would make the refusal a typed-row consequence rather than a divergence.

## Outcome

- The cause is traced to a line and written in the batch report (`_docs/03_implementation/batch_01_loop23_report.md` input from the worker).
- If the cause is the typed row (the member is always present, or the bias -1 row is refused for a reason that also holds for a present value), the parent writes it as a C++ exception in the README (step 13) and a standing C++ test pins the observed outcome.
- If it is a real divergence on a row C++ can spell, C++ is aligned to `010000` when the arm stage stays within 8 192 B flash and 512 B stack; else the change is dropped and the saving needed is recorded.

## Scope

### Included
- Reading `cpp/include/packbin/*.hpp`, `cpp/src/core/*`; C++ tests; a fix in C++ only if AC-2 alignment applies.

### Excluded
- Other packages; any byte change to rows C++ packs at HEAD.

## Acceptance Criteria

**AC-1: cause traced**
Given the U11 grid cells for `packed` bias -1 in C++
When the refusal is traced
Then the refusing check, its message/id, and whether the row is spellable with no value are recorded.

**AC-2: documented or aligned**
Given the traced cause
When it is the typed row
Then a README exception text is handed to the parent; when it is a divergence on a spellable row, C++ packs `010000` like the five (flash-gated).

**AC-3: pinned**
Given the decided outcome
When the C++ suite runs
Then a standing test asserts it (refusal with its id, or the `010000` bytes).

**AC-4: footprint (only if source changed)**
Given the arm embedded stage
When run
Then flash at most 8 192 B and stack at most 512 B; numbers recorded.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-3 | bias -1 count 0/1/3 behind clear and holding `when` | decided outcome |
| AC-4 | arm stage | within budget |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | U11 grid rows from `reference_loop22.md` | C++ column | matches the decided outcome | flash 8 192 B |

## Constraints

- Same end checks as AZ-2431 (host, `gcc:16`, arm stage).
