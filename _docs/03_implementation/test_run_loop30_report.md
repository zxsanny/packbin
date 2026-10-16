# Test run report — loop 30 (AZ-2600, CI speed)

TEST RESULTS: 10 stages passed, 0 failed, 0 skipped by decision, 0 errors (2 suites needed a serial re-run, see below)
SUITE: specified 10 / executed 10 / not-run 0 (the stages `scripts/loop-tests.sh` selected for the changed files: the 8 language suites, `scaffold`, `publish-gate`; `cpp-embedded-arm`, `ring`, `ac10` were unchanged since 8d4f1a8 and skipped by the stamp rule)

Verdict: PASS. Not-run inside the gate (as on every Mac run): the two vcpkg checks, no vcpkg tool on this host; the CI `publish-gate-rest` job runs them.

CI-parity: PASS (the `scaffold` job's script steps run locally inside the `scaffold` stage; the gate test inside the `publish-gate` stage; CI run 38921222391 on `4281aa9` had 15 of 15 jobs green).

## Step 11 (commit 7cfa49e + docs commits, Mac arm64, load average 10 to 21 from another project and from this run's own pool)

| Stage | Result | Time |
|-------|--------|------|
| typescript, python, java, cpp, csharp | PASS | 14 to 80 s |
| scaffold | PASS | 286 s |
| swift | PASS | 428 s |
| rust | PASS on the serial retry | first run failed `nfr_round_trips_under_one_second` (a 1 s timing bound) beside other suites; alone 22 s |
| go | PASS on a separate `--only go` run (117 s) | failed twice in the first run (pool, then the serial retry) on `TestAC3RaisedSlotLimit...`: "the refusal took 1.087 s" against a 1 s bound at load 11 to 21; no Go source and no `run-suite.sh go` step changed in this loop |
| publish-gate | PASS | 1 141 s at load 10 to 21 (754 s at load 10 to 16 in loop 29) |

The two timing-bound failures are the known load effect (`deployment_procedures.md`: the Go and Swift speed bounds are timing bounds; CI is their proof). They are not caused by the loop: the CI run on the same code was green.

## Mutation proofs

See `_docs/loops/loop30/notes30.md`: 45 layout mutants rejected, 8 Swift part mutants, 9 group-selection mutants, 6 Go proxy mutants, all rejected after one test was strengthened.

## CI proof

Run 38921222391 (`dev`, commit 4281aa9): 15 of 15 jobs `success`, wall 418 s (was 980 to 1 095 s); per job in `_docs/04_deploy/reports/ci_metrics_2026-10-16.md` section 6.
