# Batch Report

**Batch**: 6
**Tasks**: AZ-2106_cpp_wide_counts (security fix found by the loop 10 audit)
**Date**: 2026-10-05

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2106 | Done | `cpp/src/core/unpack.cpp`, `cpp/tests/core/counted_tests.cpp` | `wide_count_is_not_truncated` crashed the Cortex-M3 QEMU run before the fix; after it: host (clang, gcc:16) pass, M0+/M3/M4F/s390x PASS, vectors 214/214 | None |

The fix (`clamp_count`): a count read from the packet is clamped just under `SIZE_MAX` before it is narrowed to `size_t`; the `bits`/`packed` byte length is computed in 64 bits; the capacity check compares in `int64`. `sized` lengths and `times` counts no longer wrap to a smaller value on 32-bit targets.

## Code Review Verdict: PASS

Self-review of a 20-line change against the security finding F0 (`_docs/05_security/security_report.md`). The independent review of batch 5 covered the surrounding code. The proof is the test that failed on the real 32-bit target.

## Test Suite

| Target | Result | Evidence |
|--------|--------|----------|
| Host (Apple clang 21) | PASS | `all tests passed` |
| Host (gcc:16 container) | PASS | `all tests passed` |
| Cortex-M0+ build | PASS | 0 warnings, `__cxa_*` 0, heap 0 |
| Cortex-M3 QEMU | PASS | vectors 214 = 214 (before the fix: runner exit 120, vectors run 0) |
| Cortex-M4F | PASS | flash 7728 B of 8192; stack 488 B of 512; `.data`/`.bss` 0 |
| s390x | PASS | 214/214 |
| Six language suites and `language-pair.sh` | PASS before this fix | the fix touches only C++ unpack of counted kinds; the C++ pair and suite ran again in the host suite above |

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | A 64-host fuzz cannot show 32-bit narrowing faults | AZ-2106 | The vector runs on Cortex-M3 QEMU in CI; add a 32-bit fuzz build (arm QEMU user) to the embedded job later | clear |
| 2 | The pack side casts row counts the same way, but rows are caller data, not packet data | AZ-2106 | Not changed | clear |

## Commit

`[AZ-2106] Clamp wide packet counts before narrowing on 32-bit targets`

## Next Batch: none
