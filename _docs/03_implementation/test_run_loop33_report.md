# Test run report — loop 33 (AZ-2626, CI speed 4)

TEST RESULTS: 3 stages passed, 0 failed, 0 errors (no serial re-run)
SUITE: specified 13 / executed 3 / not-run 0 (the stages `scripts/loop-tests.sh` selected for the changed files: `scaffold`, `ring`, `publish-gate`; the eight language suites, `cpp-embedded-arm` and `ac10` were unchanged since eb1da7d, 6249fdc and 8d4f1a8 and skipped by the stamp rule: the loop changed only CI scripts and the workflow)

Verdict: PASS. Not-run inside the gate (as on every Mac run): the two vcpkg checks (`NOT RUN: vcpkg supports check, vcpkg consumer check`), no vcpkg tool on this host; the CI `publish-gate-rest` job runs them.

## Step 11 (commit 19f4c33, Mac arm64, `scripts/loop-tests.sh`, 613 s in total, load 5 to 45, swap 6.9 of 8 GB at the start)

| Stage | Result | Time |
|-------|--------|------|
| scaffold | PASS | 258 s (with `ring-prepare.test.sh` and `ring-wiring-swift.test.sh`; loop 32: 240 s) |
| ring | PASS | 63 s (`language-pair.sh`, the drivers already current from the real `ring-prepare.sh` run) |
| publish-gate | PASS | 291 s: the eight shares at once (`phases` 270, `phases-rerun` 279, `readonly,gate` 202, `readonly-gate-good` 174, `-bad` 176, `-nojava` 174, the rest 289, `swift` 176 s); sum 1 740 s, ratio 0.17; tree unchanged |

## Before step 11 (focused, batch and review fixes)

- `ring-prepare.test.sh`: all checks, 5 mutants caught; repeated 8 times after the review fixes: one failure in the first five (the wait gave up up to 1 s early, a real defect, fixed), then clean.
- `ring-wiring.test.sh`, `ring-wiring-swift.test.sh` (w3, w7 to w12), `publish-jobs.test.sh` (86 mutant calls), `publish-timing.selftest.sh`, `scripts/loop-tests.test.sh`, `publish-gate.test.sh --groups workflow,static`: PASS.
- Real `ring-prepare.sh` run on the Mac (batch report): all six builds exit 0; the Mac's Docker Desktop pulled the present images in 156 and 422 s (IPv6-first registry path), not representative of the runners.

## Proof still owed by CI (after the owner's push)

AC-1 (median of two `dev` runs at most 250 s), AC-2 (`ring` at most 180 s on both), AC-5 (the `ring preparation timing` notice), AC-7 (the five-image pull steps shorter than 57 to 59 s), and the first runner run of background processes across steps.
