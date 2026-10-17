# Test run report — loop 31 (AZ-2607, CI speed 2)

TEST RESULTS: 11 stages passed, 0 failed, 0 skipped by decision, 0 errors (3 suites needed the serial re-run, see below)
SUITE: specified 13 / executed 11 / not-run 0 (the stages `scripts/loop-tests.sh` selected for the changed files: the 8 language suites, `scaffold`, `cpp-embedded-arm`, `publish-gate`; `ring` and `ac10` were unchanged since 8d4f1a8 and skipped by the stamp rule)

Verdict: PASS. Not-run inside the gate (as on every Mac run): the two vcpkg checks (`NOT RUN: vcpkg supports check, vcpkg consumer check`), no vcpkg tool on this host; the CI `publish-gate-rest` job runs them. The embedded ESP parts and the Pico example cannot run on this Mac; CI is their proof.

CI-parity: PASS (batch 1 and batch 2 gates in the batch reports; the `scaffold` stage here runs the `scaffold` job's scripts including the new `cpp/embedded/run-parts.test.sh`). CI runs: 39012012655 (`29c0ab6`, batch 1) 17 of 17 jobs green, 375 s; 39014663944 (`0fc35f8`, batch 2) 20 of 20 jobs green, 344 s.

## Step 11 (commit 6249fdc, clean tree, Mac arm64, `scripts/loop-tests.sh`, 1 341 s in total)

| Stage | Result | Time |
|-------|--------|------|
| java, cpp, csharp, python | PASS | 19, 47, 110, 109 s |
| cpp-embedded-arm | PASS | 10 s (4 targets, 1 to 3 s each) |
| scaffold | PASS | 340 s (includes `run-parts.test.sh`, 73 checks) |
| swift | PASS | 436 s, all 10 steps in one container run, speed bounds met |
| typescript | PASS on the serial retry (6 s) | first run failed 2 timing bounds beside other suites: "NFR 100000 round trips ≤ 1.4 s" took 6.86 s, "times(65535) within 2x the 100-field time" |
| rust | PASS on the serial retry | first run failed `nfr_round_trips_under_one_second` (a 1 s timing bound) |
| go | PASS on the serial retry (115 s) | first run failed `TestAC3RaisedSlotLimitUnpacksTheOldWorstPacketAndTheDefaultRefusesIt`: "the refusal took 2.46 s" against a 1 s bound |
| publish-gate | PASS | 613 s (loop 30: 1 141 s at load 10 to 21; loop 29: 754 s) |

The three first-run failures are the known load effect: timing bounds in tests that run beside other suites on a Mac that also carries another project's containers (load 25 to 100 during the pool). Both the first and the retry logs are kept. No Go, Rust or TypeScript source changed in this loop (`run-suite.sh` only gained the timing notice and the Swift parts), and CI was green on the same code.

## AC-4 (parallel Mac gate): the numbers of the real run

| Share (`--groups` of the `publish-gate-*` jobs in `test.yml`) | Result | Time |
|-------|--------|------|
| readonly,gate | PASS | 309 s |
| readonly-gate,pins | PASS | 326 s |
| phases | PASS | 612 s |
| swift | PASS | 254 s |
| readonly-full + 9 small groups | PASS (NOT RUN: the two vcpkg checks) | 400 s |

`publish-gate shares: wall 612s, sum of shares 1901s` → ratio 0.32 against the 0.7 bound of AC-4 (met). `TREE the same before and after the shares (1702 paths)`: no share wrote into the tree. Up to five gate runs plus the container runs of `readonly-gate` (three gate runs at once) ran at the same time: no Docker memory failure (exit 137), no compose-project clash. The longest share on the Mac is `phases`; on CI it is `readonly-gate`. The heartbeat showed each share's log bytes and `done`; `readonly-full` printed nothing for minutes, as expected for a group that writes only at its end.

## Watcher failure of this run

The monitor on the step 11 log ended its pipe in `cut -c1-260`, a buffering stage, so it delivered no event for the 30 minutes of the run and expired; the run itself was healthy and had finished. The result was read from the log file at the expiry. Lesson in `_docs/LESSONS.md` (loop 31).

## Mutation proofs

See `_docs/loops/loop31/notes31.md` and the batch reports: 66 layout mutant calls (`publish-jobs.test.sh`), 4 read-only split and 2 trap mutants (`publish-timing.selftest.sh`), 14 timing-notice mutants (`run-suite.sh`), 33 Swift part mutants, 26 embedded part mutants (`run-parts.test.sh`), 12 Mac gate mutants (`loop-tests.test.sh`); all rejected.

## CI proof

Run 39014663944 (`dev`, commit `0fc35f8`): 20 of 20 jobs `success`, wall 344 s (was 418 and 382 s); per job in `_docs/loops/loop31/notes31.md` and `_docs/04_deploy/reports/ci_metrics_2026-10-16.md` section 7. The second run (AC-1, median of two) is the close push of `dev`.
