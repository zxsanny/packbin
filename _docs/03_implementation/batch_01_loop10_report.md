# Batch Report

**Batch**: 1
**Tasks**: AZ-2060_cpp_core_scalars
**Date**: 2026-10-04

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2060_cpp_core_scalars | Done | 7 files | core suite pass; 1 compile-fail case pass; old host suite pass | None |

## Code Review Verdict: PASS

`reviews/batch_01_loop10_review.md`

## Test Suite

- `make test` in `cpp/` (Apple clang 21 with `PACKBIN_CXX_SYSROOT`): old suite `all tests passed` (nfr 145 ms), `core tests passed`, both compile-fail cases rejected.
- CI-parity: PASS — `docker compose -f docker-compose.test.yml run --rm cpp` (gcc:16, `run-suite.sh cpp`, clean `build/`): same three results, nfr 117 ms.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | A host cannot make `double` 4 bytes, so AC-5 cannot be compiled for real on the host | AZ-2060 AC-5 | `put_f64<D>` checks `sizeof(D) == 8`; the host compile-fail case passes `float` as a stand-in. The real 4-byte double build is AZ-2068 (avr-gcc) | clear (spec allows "a stand-in compile check where the host has no such flag") |
| 2 | A shared `cpp/build/` from the Mac breaks the Linux container run | none | Run the container on a clean `build/`; CI checks out clean | clear |

## Commit

`[AZ-2060] Add the C++ core buffers, scalars and error values`

## Next Batch: AZ-2061_cpp_core_schemes
