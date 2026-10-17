# Batch 1 report — loop 32

Task: AZ-2625 (CI speed 3, 5 points), one batch. No per-batch review (owner preference: one total review before step 11). One worker (Swift strict build, files `run-suite.sh` and `run-suite-swift.test.sh`); the parent did the rest on disjoint files.

| Part | Status | Evidence |
|------|--------|----------|
| `readonly-gate` in three groups and jobs (AC-2) | Done | `ro_gate_run` + `ro_gate_good_check`, `ro_gate_bad_check`, `ro_gate_nojava_check`; groups 121, 88, 94 s on CI run 39024316436; each group run alone for real on the Mac |
| `pins` moved (AC-3) | Done | `publish-gate-rest` runs `pins`; the guard holds `pins` among the container groups (pull before the gate) |
| `phases` in two groups (AC-4) | Done, cut changed | `phases` (all but the re-run scenarios) and `phases-rerun`; the Mac profile put 128 of 272 s in `ph_rerun_checks`, so the cut is 143 against 143 s (owner's example success against failure would have been 73 against 213); CI 105 and 108 s |
| Swift strict build merged (AC-5) | Done | the worker; the one release build carries `-warnings-as-errors -strict-concurrency=complete` and the tests; both parts run for real in `swift:6.3.3`; 19 mutants of `run-suite.sh` and a planted test-file warning rejected |
| Guards (AC-6) | Done | `publish-jobs.test.sh` 66 → 77 mutant calls; `publish-timing.selftest.sh` `ph_split` + 4 mutants, `ro_split` 5; `run-suite-swift.test.sh` S2f |
| `test.yml` order and job count (AC-7) | Done | 23 jobs, longest first; queue wait read from the first run |

CI-parity: PASS (the `scaffold` job's scripts, `run-suite.test.sh`, `publish-jobs.test.sh`, `publish-timing.selftest.sh`, gate groups `static` and `workflow`, and the five new groups run for real) before the commit `c0e8019`.

## Discovered during implementation

| Scenario or question | Spec ref | Proposed handling | clear / unclear |
|----------------------|----------|-------------------|-----------------|
| `report-row.test.sh` compares the suites matrix with the languages in a fixed order; the new longest-first matrix order fails it (the `scaffold` job would have been red on CI) | AC-1, AC-7 | compare as a set; mutant check (matrix without typescript refused); done | clear |
| `publish-workflow.test.sh` names the gate and embedded jobs by hand and would name jobs that no longer exist | AC-6 | derive them from the `publish-gate-*` and `embedded-*` names; done | clear |
| The bad-fixture scenario checked that its rc file was non-empty ("the run did not finish"); a foreground run always writes it | AC-2 | check dropped, recorded in `notes32.md` | clear |
| 23 jobs against the free plan's 20 slots | AC-7 | measured on the first run: three jobs waited 30 to 63 s, none set the wall | clear |
| Pull lists carry all eight images in seven jobs (swift 4 GB) | AC-2, AC-4 | out of scope (C3 family); recorded as the next candidate | unclear (owner) |
