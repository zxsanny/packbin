# Feature assessment — loop 29

loop: 29
feature: gate-cut
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-10-16
**Implement pass**: one task (AZ-2582) in four commits (178349f, 0ebe414, e20e8fd, 1ce48a2); no batch report files (the loop used one total review and one step 11 run); evidence: `_docs/loops/loop29/notes29.md`, `_docs/03_implementation/test_run_loop29_report.md`, `_docs/04_deploy/reports/deploy_status_report.md` "Loop 29", CI run 38888934994.
**Verdict**: COMPLETE — 17 covered / 1 out-of-scope / 0 gap-clear / 0 gap-unclear

FEATURE ASSESSMENT loop 29 round 1: COMPLETE — 17 covered / 1 out-of-scope / 0 gap-clear / 0 gap-unclear

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| GC-1 | gate job at most 1 080 s median of 3, none above 1 200 s | covered (run 1 of 3) | run 38888934994: 689 s; runs 2 and 3 are the close pushes of `dev` and `main` (leftover: read them after the push) | AC |
| GC-2 | 14 timing lines and total in CI; Mac sum at most 800 s | covered | annotation of run 38888934994 (14 lines + total 593 s); `loop-tests.sh` publish-gate PASS 754 s | AC |
| GC-3 | workflow end to end not longer than loop 28 | covered | `suites` 888 s is the longest job, about 14 min 50 s (loop 28: 22 min 51 s) | AC |
| GC-4 | no unique assertion and no mutant lost | covered | ledger in notes29.md (3 assertions moved, 3 with twins); swift 30 of 30 mutants rejected at 1, 4 and 8 jobs | AC |
| GC-5 | one mutant per changed scenario, rejected | covered | M1, M2, M3 (2, 1, 1 FAIL, run on the final parallel version), identity swift mutant, timing-notice mutants, missing exit-code file mutant | AC |
| GC-6 | files at most 500 lines, 0 new shellcheck warnings | covered | the 6 changed files are 475 (`publish-gate.test.sh`), 438, 388, 370, 53 and 76 lines; `publish-phases.test.sh` (501 lines at f78553e, not touched by this loop) is the one file over the cap; shellcheck finding lists equal or shorter than at f78553e for all 6 changed files | AC |
| GC-7 | per-call timings recorded before the first cut; cut list within 20 % of the gain | covered with one miss | notes29.md tables (per function, per call); each cut matched its prediction (145 / 87 / about 65 of 85 / 103 s) except the real-swift overlap (about 24 % under); the aggregate predicted about 400 s against a measured 321 s (1 075 s at load 19 to 29 to 754 s at load 10 to 16: the loads differed) | AC |
| GC-8 | CI document carries the new gate timings, no stale figure as current | covered | `ci_cd_pipeline.md` (`long_running`, the gate paragraph); loop 28 figures are labelled as the earlier run | AC |
| GC-9 | state under the run's own mktemp; 2 runs at once pass; 0 dirs this loop added left | covered | two gate tests at once: 989 s and 990 s, both pass; repo clean; 0 readonly tree copies, 0 status directories, 0 mutant copies left. Amended: an aborted run leaves its temp directories as before | AC |
| GC-10 | timing line format and the 14 group names unchanged, selftest passes | covered | `publish-timing.selftest.sh` passes; the 14 names asserted in the selftest; a notice mutant rejected | AC |
| S1 | whole gate on the Mac, all tools | covered | step 11: 754 s, `no failures`, NOT RUN only vcpkg | scenarios |
| S2 | gate run twice in a row | covered | step 11 run, then the pair run, then a second CI run; nothing reused (mktemp) | scenarios |
| S3 | two gates at once | covered | the pair run | scenarios |
| S4 | a group aborts midway | out-of-scope | amended: temp directories of an aborted run stay, as before; the aborted timing line and the notice on abort are tested by the selftest | scenarios |
| S5 | a tool is missing | covered | the two vcpkg checks print NOT RUN and the last line says so, in all Mac runs | scenarios |
| S6 | a guarded behaviour broken after a cut | covered | M1 to M3 | scenarios |
| S7 | cold runner | covered | run 38888934994 includes a 90 s image pull in its 689 s | scenarios |
| S8 | loop test script and timing selftest read the gate | covered | `loop-tests.test.sh` and `publish-timing.selftest.sh` pass | scenarios |

## Discovered during the loop

| Angle | Handling |
|-------|----------|
| GitHub keeps 10 notice annotations per step, so a notice per timing line lost the last five groups (found on CI run 1) | fixed: one notice with all lines (batch 2) |
| The mutant throttle counted the real-swift job as a slot; a missing exit-code file read as a refusal (review) | fixed (e20e8fd) |
| `suites` (888 s) is now the longest job; the gate job is 689 s | leftover: a matrix of one job per language is the next speed step |
| The phases group still builds nine targets six times one after another (158 s on the runner) | leftover |
| 745 old `mktemp` directories sit in the Mac temp directory (the gate's older calls leave them, as on abort) | leftover |
| Runs 2 and 3 of the median of 3 are the close pushes | read after the push, recorded in the handoff |

## Not walked

none
