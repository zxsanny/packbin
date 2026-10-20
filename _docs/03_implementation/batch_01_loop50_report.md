# Batch Report

**Batch**: 1 (loop 50)
**Tasks**: AZ-2749_rust_nostd_core
**Date**: 2026-10-20

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2749_rust_nostd_core | Done | 17 files (7 new source, 3 new test files, `Cargo.toml`, `lib.rs`, `run-suite.sh`, `run-suite.test.sh`, docs) | 14 new pass (11 flat, 3 differential), full suite 789 pass / 0 fail | None |

## Code Review Verdict: not run per batch

Owner rule (2026-10-06): one total review per loop, after the last batch. `cargo clippy` with `deny(unwrap_used, expect_used, panic, indexing_slicing, arithmetic_side_effects)` on the `nostd` module is clean, and a probe (index, `+`, `unwrap`) proved the lints fire.

## Test Suite

- `cargo test` (default features): 27 targets, 789 tests passed, 0 failed, 52 s
- `cargo test --no-default-features --test nostd_flat_tests`: 10 passed (11 with `alloc`)
- Mutants caught: big-endian reverse removed (differential test fails), trailing-byte check inverted (cut/extended test fails)
- CI-parity: PASS. Commands: `cargo test` (the CI suite step), the new `--no-default-features` step, `bash .github/workflows/run-suite.test.sh`, `ring-wiring.test.sh`, `ring-wiring-rows.test.sh`, `scripts/loop-tests.test.sh`, `report-row.test.sh`. The ring and the release speed steps run once in step 11.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | A module named `core` would shadow the Rust `core` crate | AZ-2749 | Renamed to `packbin::nostd` (docs and specs updated) | clear |
| 2 | `bool` is a flag bit in the std API (an empty `group`), not a byte | AZ-2749 outcome | Moved to AZ-2752 (flags); spec text fixed | clear |
| 3 | The golden packet's last byte is a flags byte; the flat core reads it as `u8` | AZ-2749 AC-1 | The test comment says so; AZ-2752 reads it as `flags` | clear |
| 4 | A failed `unpack` may leave fields already read in the row | AZ-2749 AC-4 | Documented on `unpack` (C++ does the same) | clear |
| 5 | The `rust` suite step count in `run-suite.test.sh` (2 and 4) changed to 3 and 5 | AZ-2749 AC-1 | Updated; the new step runs the heap-free tests with default features off | clear |
| 6 | Docker `rust` image is `rust:1.98`, this Mac has 1.79 | AZ-2751 | Both build the new code; the embedded target install is asked in AZ-2751 | clear |

## Commit

`[AZ-2749] Rust nostd core: features, flat schemes, differential test`. Body: one line + `Loop: 50`.

## Next Batch: AZ-2751_rust_core_embedded_profile
