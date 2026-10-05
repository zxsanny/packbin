# Test run — loop 10

**Date**: 2026-10-05
**Mode**: functional
**Verdict**: PARTIAL

TEST RESULTS: 0 failed, 0 skipped, 0 errors
SUITE: specified 106 / executed 85 / not-run 21

Six language suites ran in their containers (`docker compose -f docker-compose.test.yml run --rm <lang>`), all exit 0: C# 52 passed; TypeScript 44 passed; Python 44 passed; Rust 32 + 6 + 10 passed (three result lines); Java printed `All tests passed`, `Scheme tests passed`, `Field id binding tests passed`, `All session tests passed`; C++ `make test` printed `all tests passed` on gcc:16 with 9 compile-fail cases and 17 hostile cases. The same C++ suite passed on Apple clang 21.

Embedded job (`docker compose … run --rm cpp-embedded`, run again after the security fix AZ-2106; the new vector `wide_count_is_not_truncated` crashed the Cortex-M3 run before the fix): Cortex-M0+ build PASS (0 warnings, `__cxa_*` 0, heap 0); Cortex-M3 QEMU PASS (vectors run 214 = asserted 214, wrapper calls 0, session vectors 22); Cortex-M4F PASS (flash 7728 B of 8192, deepest stack 488 B of 512, `.data`/`.bss` 0); s390x PASS (214/214, all-kinds packet equals Cortex-M3 bytes).

Cross-language pairs: `PACKBIN_CXX_SYSROOT=$(xcrun --show-sdk-path) bash .github/workflows/language-pair.sh` printed `language pairs passed`. Hostile case check: `bash fixtures/hostile/cases.test.sh` printed `hostile case tests passed` on bash 3.2 and Ubuntu 24.04.

## Not run

| id | rows | reason |
|----|------|--------|
| FT-E-12 | cpp-microcontroller AC-12 | needs a published tag and PlatformIO / ESP-IDF registry tokens (maintainer) |
| FT-E-13 | cpp-microcontroller AC-13 (the GitHub job itself) | the `embedded` job runs in GitHub Actions; its targets ran locally above |
| FT-P-08, FT-P-09, FT-P-10, FT-N-03, FT-N-04, NFT-SEC-01 | as in `test-run09.md` | tag publish, GitHub push job, registry credentials: unchanged since loop 9 (19 rows) |

The ESP-IDF builds and the packaged examples were not re-run in this pass: no ESP, Pico or Arduino file changed after batch 4, where they passed.

CI-parity: PASS — host suites in containers for all six languages, the embedded ARM job, the pair script and the hostile format check.
