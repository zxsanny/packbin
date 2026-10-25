# Batch Report

**Batch**: 2
**Tasks**: AZ-3202_frame_golden_vectors
**Date**: 2026-10-25

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-3202 | Done | 12 files (scripts/frame, fixtures/frame, CI wiring) | 154 rows re-derived; 4 corrupted copies fail; generator deterministic; independent check ok | None |

## Code Review Verdict: not run per batch (owner preference: one total review and one step 11 run per loop)

## Test Suite

- `fixtures/frame/check-vectors.test.sh`: 7 PASS (committed, deterministic, reproduces the committed file, body, tag, result, results corrupted)
- `independent_check.py`: E1 to E5, a 236-byte seal, a 255-byte three-part MAC, a previous-slot open: ok
- CI-parity: PASS (`publish-jobs.test.sh`, `loop-tests.test.sh`)

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | Rust cannot build direction 0 or 4 (`Direction` has three values) | AZ-3202 coverage refusals | the fixture keeps the rows (other packages take integers); the Rust test expects BadValue for them without a call | clear |
| 2 | Open with an `ad` of 256 bytes: the contract names the check but not the kind | AZ-3200 | the reference returns TooLong as seal does; no fixture row pins it | unclear (a one-line contract decision; no row depends on it) |
| 3 | `clear_len` one too small for E1 and E2 (empty clear part) has no value | AZ-3202 tamper rows | skipped for E1 and E2, present for E3 (README says so) | clear |

## Commit

`06206b1 [AZ-3202] Frame mode golden vectors, reference generator and checks` (Loop: 69)

## Next Batch: AZ-3203
