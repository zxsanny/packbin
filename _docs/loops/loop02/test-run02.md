# Test run — loop 2

**Date**: 2026-09-23
**Mode**: functional
**Verdict**: PARTIAL

TEST RESULTS: six language suites and the language-pair script passed, 0 failed, 0 skipped, 0 errors
SUITE: specified 33 / executed 13 / not-run 20

TypeScript 20 passed. Python 15 passed (`nfr` 0.73s). Rust 21 passed (`nfr` 734.3 ms). C# 22 passed. Java `java/test.sh` printed `All tests passed`. C++ `make test` printed `all tests passed`. `.github/workflows/language-pair.sh` printed `language pairs passed`.

## Executed

Library byte scenarios FT-P-01 through FT-P-07, FT-N-01, and FT-N-02 ran inside the six suites. The 100000-iteration bound ran in each suite. AZ-1941 AC-1, AC-2, and AC-3 ran in `language-pair.sh` against real `pack` and `unpack`.

## Not run

These rows share the publish and CI jobs. This laptop has no registry credentials and this loop does not push.

| id | rows | reason |
|----|------|--------|
| FT-P-08 | AC-12, AC-13, AC-16, R-03, R-09, R-10, R-15, R-16 | version tag and registry credentials |
| FT-P-09 | AC-11, R-13, R-14 | suite-on-push is the GitHub workflow |
| FT-P-10 | R-04, R-06, R-07 | vcpkg and package-metadata checks ride the tag job |
| FT-N-03 | AC-14 | a disagreeing tag is a CI publish job |
| FT-N-04 | AC-15, R-05, R-17, R-18, R-19 | a missing language publish is a CI publish job |

CI-parity: PASS — same commands as the test workflow. A later quiet run of the one-second bound passed: Python 0.75s, Rust 903ms. Earlier FAIL rows in `test-results/report.csv` are that bound while the machine was busy.
