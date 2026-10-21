# Test run — loop 55 (step 11)

Date: 2026-10-21. Command: `scripts/loop-tests.sh` (every stage planned: the fixtures, `cpp/` and test files changed since loop 54).

RESULT: 14 passed, 0 skipped as unchanged, 0 failed, 1049 s. Verdict: PASS.

| Stage | Result | Seconds |
|-------|--------|---------|
| typescript | PASS | 14 |
| csharp | PASS | 61 |
| python | PASS | 169 |
| go | PASS | 197 |
| java | PASS | 27 |
| rust | PASS | 200 |
| cpp | PASS | 74 |
| scaffold | PASS | 303 |
| swift | PASS | 404 |
| cpp-embedded-arm | PASS | 15 |
| rust-embedded | PASS | 8 |
| ring | PASS | 59 |
| ac10 | PASS | 7 |
| publish-gate | PASS (shares: phases 341, phases-rerun 342, readonly,gate 231, good 227, bad 225, nojava 217, readonly-full... 296, swift 132) | 343 |

Specified / executed / not run: all 14 stages specified and executed. NOT RUN inside a stage: `vcpkg supports check` and `vcpkg consumer check` (no vcpkg tool on this host; prints NOT RUN, which is not a pass; CI runs them).

Cortex-M4F (arm stage log of this run): flash 8,120 of 8,192 B (margin 72 B), stack 504 of 512 B (margin 8 B), `CHAIN_FAILURES 0`, `FLAG_CHAIN_FAILURES 0`.

Host: load 3 to 47 during the run (the gate shares ran at the same time); no stage needed a re-run alone. The test-run found no failing test, so no fix was made.
