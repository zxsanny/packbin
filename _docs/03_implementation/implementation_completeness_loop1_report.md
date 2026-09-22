# Implementation completeness — loop 1

**Date**: 2026-09-22
**Tasks**: AZ-1866, AZ-1876, AZ-1877, AZ-1878, AZ-1879, AZ-1880, AZ-1881, AZ-1875

## Per task

| Task | Classification | Evidence |
|------|----------------|----------|
| AZ-1866 | PASS | Six roots, `fixtures/golden.hex`, `test.yml`, `publish.yml`, `docker-compose.test.yml`. No scaffold markers. |
| AZ-1876 | PASS | `csharp/Packbin.cs` `Pack.Run` / `Unpack.Run`. `csharp/tests/PackbinTests.cs` 9 passed. |
| AZ-1877 | PASS | `typescript/src/index.ts` `pack` / `unpack`. `typescript/tests/packbin.test.ts` 9 passed. |
| AZ-1878 | PASS | `python/src/packbin/__init__.py` `pack` / `unpack`. `python/tests/test_packbin.py` 9 passed. |
| AZ-1879 | PASS | `rust/src/lib.rs` `pack` / `unpack`. `rust/tests/packbin_tests.rs` 10 passed. |
| AZ-1880 | PASS | `cpp/include/packbin/packbin.hpp` `pack` / `unpack`. `cpp/tests/packbin_tests.cpp` passed. |
| AZ-1881 | PASS | `java/src/main/java/packbin/Packbin.java` `pack` / `unpack`. `java/src/test/java/packbin/PackbinTest.java` passed. |
| AZ-1875 | PASS | `.github/workflows/publish-gate.sh` calls each present package's `pack` and writes a plan only when the mismatch count is 0. `.github/workflows/publish-registries.sh` performs the registry writes after that gate. |

No `placeholder`, `TODO`, `stub`, or `not implemented` in the language sources or the workflows.

## System Pipeline Audit

| Pipeline | Path | Status |
|----------|------|--------|
| F1 Pack | caller → `pack` in the language package | WIRED |
| F2 Unpack | caller → `unpack` in the language package | WIRED |
| F3 Publish | tag → `publish-gate.sh` → each `pack` → `publish-registries.sh` | WIRED |

Tests and the position drivers are not the pipeline. Production pack and unpack are the library functions. The tag job calls those functions before any registry write.
