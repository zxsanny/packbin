# Test run report — loop 32 (AZ-2625, CI speed 3)

TEST RESULTS: 10 stages passed, 0 failed, 0 skipped by decision, 0 errors (no suite needed the serial re-run)
SUITE: specified 13 / executed 10 / not-run 0 (the stages `scripts/loop-tests.sh` selected for the changed files: the 8 language suites, `scaffold`, `publish-gate`; `cpp-embedded-arm`, `ring` and `ac10` were unchanged since 6249fdc and 8d4f1a8 and skipped by the stamp rule)

Verdict: PASS. Not-run inside the gate (as on every Mac run): the two vcpkg checks (`NOT RUN: vcpkg supports check, vcpkg consumer check`), no vcpkg tool on this host; the CI `publish-gate-rest` job runs them.

CI-parity: PASS (see the batch report). CI run 39024316436 (`c0e8019`, batch 1): 23 of 23 jobs green, 275 s.

## Step 11 (commit eb1da7d, clean tree, Mac arm64, `scripts/loop-tests.sh`, 902 s in total)

| Stage | Result | Time |
|-------|--------|------|
| typescript, java, rust, cpp | PASS | 12, 24, 34, 36 s |
| csharp, python | PASS | 67, 70 s |
| go | PASS | 137 s |
| scaffold | PASS | 240 s |
| swift | PASS | 404 s, all 9 steps of the new single run in one container run (one release build) |
| publish-gate | PASS | 391 s |

No stage needed the serial retry this time (load 20 to 69 during the pool and the gate).

## AC-8 (parallel Mac gate): the numbers of the real run

| Share (`--groups` of the `publish-gate-*` jobs in `test.yml`) | Result | Time |
|-------|--------|------|
| readonly,gate | PASS | 282 s |
| readonly-gate-good | PASS | 238 s |
| readonly-gate-bad | PASS | 237 s |
| readonly-gate-nojava | PASS | 224 s |
| phases | PASS | 372 s |
| phases-rerun | PASS | 384 s |
| readonly-full + pins + 9 small groups | PASS (NOT RUN: the two vcpkg checks) | 391 s |
| swift | PASS | 267 s |

`publish-gate shares: wall 391s, sum of shares 2395s` → ratio 0.16 against the 0.7 bound (met; was 0.32 in loop 31 with five shares). `TREE the same before and after the shares (1712 paths)`: no share wrote into the tree; eight shares at once, no Docker memory failure (exit 137), no compose clash.

## Mutation proofs

`publish-jobs.test.sh` 77 layout mutant calls; `publish-timing.selftest.sh` 5 read-only split and 4 phase split mutants, 2 trap mutants; `run-suite-swift.test.sh` S2f plus 19 mutants of `run-suite.sh` run by the worker (flags dropped one by one, flags moved, `--build-tests` dropped, a second release build, a release build in `gates` or `tests`, the failure ignored); a matrix-without-typescript mutant of `report-row.test.sh`; all rejected (details in `_docs/loops/loop32/notes32.md`).

## CI proof

Run 39024316436 (`dev`, commit `c0e8019`): 23 of 23 jobs `success`, wall 275 s (was 344 and 369 s); per job in `_docs/04_deploy/reports/ci_metrics_2026-10-16.md` section 8. The second run (AC-1, median of two) is the close push of `dev`.
