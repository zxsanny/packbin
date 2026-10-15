# Test run — loop 27 (step 11)

Date: 2026-10-15. Commit `506717c`. One run: `scripts/loop-tests.sh` (host load 1.9 at the start; Python 3.14 and `PACKBIN_CXX_SYSROOT` per `AGENT_GOTCHAS.md`).

SUITE: 13 specified / 11 executed / 2 not-run (unchanged since their last pass) — PASS

| Stage | Result | Time |
|-------|--------|------|
| typescript | PASS | 9 s |
| csharp | PASS | 50 s |
| python | PASS | 61 s |
| rust | PASS | 28 s |
| java | PASS | 21 s |
| cpp | FAIL in the pool, PASS on the serial retry | 36 s / 21 s |
| go | PASS | 124 s |
| scaffold | PASS | 210 s |
| swift | PASS (340 tests in 56 suites plain, 27 in 3 suites sanitized) | 385 s |
| ring | PASS | 52 s |
| publish-gate | PASS | 1 077 s |
| cpp-embedded-arm | skipped, unchanged since `682fe52` | — |
| ac10 | skipped, unchanged since `1b15718` | — |

Total 1 626 s. Exit 0.

## The cpp pool failure

The first `cpp` run failed in the pool: `ld: cannot open output file build/packbin_tests: No such file or directory` (`cpp.first.log`). `cpp/build/` is shared with the `scaffold` stage (which builds C++ in a container at the same time); one stage removed the directory while the other linked. No file of `cpp/` changed in this loop. The script's own rule (re-run alone, keep both results) applied; this is not a clean pass and is carried as a leftover (pool race, pre-existing).

## CI

CI of `94834ef` (run 38694589648): all three jobs green, gate 1 322 s. CI of `00ad75f` (run 38700362252): `ring` and `embedded` green, `suites` 860 s (was 1 238 s), `publish gate` running at the time of writing.

CI-parity: PASS (the same stages `test.yml` runs).
