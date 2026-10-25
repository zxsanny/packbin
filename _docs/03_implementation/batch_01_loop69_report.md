# Batch Report

**Batch**: 1
**Tasks**: AZ-3200_frame_mode_contract_and_adr, AZ-3201_primitive_vectors_python_and_rust
**Date**: 2026-10-25

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-3200 | Done | 8 files (contract, ADR, 4 project files, README, adr index) | E1 to E5 recomputed by an independent script: 5 of 5 | None |
| AZ-3201 | Done | 14 files (fixture, scripts, Rust test, CI wiring) | python check ok; 7 corrupted-copy tests pass; Rust 5 passed (cargo 1.79 and rust:1.98) | None |

## Code Review Verdict: not run per batch (owner preference: one total review and one step 11 run per loop)

## Test Suite

- Python: `check_vectors.py` 27 rows ok on 3.9 and 3.14; `check-vectors.test.sh` 7 PASS
- Rust (rust:1.98): `crypto_vectors` 5 passed, `session_core` 3 passed, no_std builds without warnings
- CI-parity: PASS (cargo test crypto_vectors, cargo build --no-default-features with and without session; `publish-jobs.test.sh`, `loop-tests.test.sh` pass)

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | The Rust suite under `--no-default-features --features session` does not compile (existing in-crate tests use `String`/`Vec`) | AZ-3201 blackbox row | the new test is gated on `std`, as the other in-crate test modules are; the no_std builds are proven by `cargo build` | clear (existing practice) |
| 2 | The README Rust example of AZ-3200 cannot compile before the code exists | AZ-3200 outcome | the section ships with the rule in bold; the example comes with AZ-3204 | clear |

## Commit

`80999ef [AZ-3200] [AZ-3201] Frame mode contract 2.0.0 and ADR 008; primitive reference vectors` (Loop: 69)

## Next Batch: AZ-3202
