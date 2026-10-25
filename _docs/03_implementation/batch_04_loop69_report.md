# Batch Report

**Batch**: 4
**Tasks**: AZ-3204_rust_frame_embedded_set
**Date**: 2026-10-25

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-3204 | Done | 13 files (probe, feature set, limits, checks, docs, run-suite) | embedded stage 0 failed targets; checks.test.sh and run-suite.test.sh pass; doc test passes | None |

## Code Review Verdict: not run per batch (owner preference: one total review and one step 11 run per loop)

## Test Suite

- Embedded stage (Cortex-M4F, host cargo 1.79, QEMU): frame 19,772 B flash / 1,896 B stack (limits 20,480 B / 1,991 B); base 14,700 B / 456 B, text 26,632 B / 2,760 B, ecc 17,980 B / 760 B, session 18,404 B / 1,832 B: identical to the same stage run on a tree copy of 06206b1 (before AZ-3203)
- rust-mutants: seeded panic and heap defects caught
- rust:1.98 matrix as batch 3 plus the doc test: all green
- CI-parity: PASS

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | The CI runner (Rust 1.98, Linux) reports larger figures than this Mac (cargo 1.79): loop 68 CI base 15,060 B, text 27,156 B, ecc 18,692 B, session 18,812 B | AZ-3204 AC-2 | the CI figure of the `frame` set is read after the push; limits stay at the Mac figures (the 20,480 B bound is the owner's) | unclear (CI may need a higher frame flash limit; read after the push) |
| 2 | The probe holds one session, not a node and a peer (a session seals and opens) | AZ-3204 AC-1 | one session; a second would add 600 B of stack | clear |

## Commit

`[AZ-3204] Rust frame mode on the device: embedded frame set, stream-symbol check and docs` (Loop: 69)

## Next Batch: All tasks complete
