# Batch Report

**Batch**: 3
**Tasks**: AZ-3203_rust_frame_mode_core
**Date**: 2026-10-25

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-3203 | Done | 18 files (frame module, session_core pieces, tests, CI) | frame fixture 2 passed in 3 feature sets; in-crate 9 passed (10 with session); doc 4 passed; default suite 831 passed, 0 failed | None |

## Code Review Verdict: not run per batch (owner preference: one total review and one step 11 run per loop)

## Test Suite

- rust:1.98: default `cargo test` 831 passed, 0 failed; nostd flat 12; session 13 and 22; frame fixture 2 (without and with std); frame lib 9 and 10; doc 4
- Clippy (1.79, nostd denies unwrap, expect, panic, indexing, arithmetic): no finding in the new code in 5 feature combinations
- CI-parity: PASS

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | The spec says `frame` is on with `std` as `session` is; in this crate `session` is not implied by `std` | AZ-3203 outcome | `frame` is opt-in like `session` | clear (crate practice) |
| 2 | An empty `Directions` set loads a session that refuses every call | AZ-3200 | allowed; every call is BadValue | clear |
| 3 | With `session` and `frame` both on, `Session` is 704 B (588 B frame only) | AZ-3203 AC-9 | the 640 B bound is asserted for the frame-only build | clear |
| 4 | Load by value copied the 600-byte session on the stack (probe stack 2,968 B) | AZ-3204 AC-1 | added `Session::frame_unloaded` and `load_frame_in_place` (two public functions beyond the spec's shape) | clear (needed to meet the 2,048 B bound) |

## Commit

`3d9b3f9 [AZ-3203] Rust frame mode: seal, open, MacKey and ReplayWindow behind the frame feature` (Loop: 69)

## Next Batch: AZ-3204
