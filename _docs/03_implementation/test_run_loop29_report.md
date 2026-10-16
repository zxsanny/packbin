# Test run report — loop 29 (AZ-2582, publish gate cut)

TEST RESULTS: 2 stages passed, 0 failed, 0 skipped by decision, 0 errors
SUITE: specified 2 / executed 2 / not-run 0 (the stages `scripts/loop-tests.sh` selected for the changed files; the 7 others were unchanged since 8d4f1a8 and skipped by the stamp rule)

Verdict: PASS. Not-run inside the gate (as on every Mac run): the two vcpkg checks, no vcpkg tool on this host (`publish gate: no failures, NOT RUN: vcpkg supports check, vcpkg consumer check`); the CI `publish-gate` job runs them.

CI-parity: PASS (the `scaffold` job's script steps run locally: report-row, hostile cases, run-suite, embedded lib, ring-wiring, loop-tests; the full gate test; the timing selftest).

## Step 11 (commit e20e8fd, Mac arm64, load average 10 to 16 from other projects)

| Stage | Result | Time |
|-------|--------|------|
| scaffold | PASS | 163 s |
| publish-gate | PASS | 754 s (was 1 059 to 1 075 s at loop 28; goal at most 800 s met) |

## GC-9: two complete gate tests at the same time (same host, same repository)

Both passed: total 989 s and 990 s, 14 timing lines each, `no failures`, the same two vcpkg NOT RUN notes. Group seconds A / B: gate 94 / 100, go 14 / 15, swift 181 / 170, pins 32 / 34, phases 334 / 334, readonly 311 / 312. `git status` clean afterwards; no directory added by this loop was left (readonly tree copies, real-swift status directory, mutant copies: 0 of each); the gate's older `mktemp` calls left 9 directories for the two runs, as before the loop.

## Mutation proofs (GC-5)

See `_docs/loops/loop29/notes29.md`: M1, M2, M3 on `ro_gate_checks` (2, 1, 1 FAIL; re-run on the parallel version), the identity swift mutant (reported), the timing notice mutants (single-notice helper: 5 FAIL; no notice on abort: 1 FAIL), a missing exit-code file of the bad-fixture run (1 FAIL), and 30 of 30 swift mutants rejected at 4 jobs.
