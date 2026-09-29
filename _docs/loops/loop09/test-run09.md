# Test run — loop 9

**Date**: 2026-09-29
**Mode**: functional
**Verdict**: PARTIAL

TEST RESULTS: 0 failed, 0 skipped, 0 errors
SUITE: specified 86 / executed 67 / not-run 19

C# 52 passed. TypeScript 44 passed, 0 failed, 0 skipped. Python 44 passed. Rust 52 passed (`nfr` 373.6 ms). C++ `make test` printed `all tests passed` (`nfr` 114.039 ms) after `cpp/build` was removed so the container compiled `session.cpp`. Java printed `All tests passed`, `Scheme tests passed`, `Field id binding tests passed`, and `All session tests passed` (`NFR` 0.102 s). `publish-gate.test.sh` printed `publish gate tests passed`. `report-row.test.sh` printed `report row tests passed`.

Session checks inside those suites: opener pack and waiter unpack, waiter pack, a second packet, two sessions, bad lengths, pack before open, and the README example text. The six-language session ring is `language-pair.sh`, which this workflow job does not run.

## Executed

Library byte scenarios FT-P-01 through FT-P-07, FT-N-01, FT-N-02, FT-U-01 through FT-U-04, FT-L-01 through FT-L-04, FT-D-01 through FT-D-05, FT-H-01 through FT-H-03, FT-S-01 through FT-S-07, FT-B-01 through FT-B-05, FT-C-01 through FT-C-05, and FT-O-01 through FT-O-06 ran inside the six language containers against real pack and unpack. NFT-SEC-02 and the one-second bound ran in each suite. NFT-RES-LIM-01 ran as the no-GPU check.

## Not run

These rows are the tag publish and the GitHub push job. This laptop did not push a tag and has no registry credentials. `publish-gate.test.sh` stub-checks the workflow; it does not publish.

| id | rows | reason |
|----|------|--------|
| FT-P-08 | AC-12, AC-13, AC-16, R-04, R-06, R-07, R-09, R-10, R-15, R-16 | version tag and registry credentials |
| FT-P-09 | AC-11, R-13, R-14 | suite-on-push is the GitHub workflow |
| FT-P-10 | R-09, R-15 | vcpkg publish rides the tag job |
| FT-N-03 | AC-14 | a disagreeing tag is a CI publish job |
| FT-N-04 | AC-15, R-05, R-17, R-18 | a missing language publish is a CI publish job |
| NFT-SEC-01 | R-19 | no published archive to scan on this laptop |

CI-parity: PASS — `docker compose -f docker-compose.test.yml run --rm` for csharp, typescript, python, rust, cpp, and java, then `bash .github/workflows/publish-gate.test.sh` and `bash .github/workflows/report-row.test.sh`.
