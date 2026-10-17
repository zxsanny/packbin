# Feature assessment — loop 32

loop: 32
feature: ci-speed-3
rounds: 1
verdict: COMPLETE (AC-1 median of two runs 269.5 s (275 and 264 s) against the 330 s bound; `scenarios.md` absent: no new-task Step 4.7 for this CI loop, the spec ACs and the notes are the baseline)

FEATURE ASSESSMENT loop 32 round 1: COMPLETE — 10 covered / 3 out-of-scope / 0 gap-clear / 0 gap-unclear

| id | scenario | status | evidence |
|----|----------|--------|----------|
| AC-1 | CI wall, median of two `dev` runs at most 330 s | covered | run 39024316436 (`c0e8019`): 275 s; run 39025925515 (`73ba412`, the close push): 264 s; both 23 of 23 jobs green; median 269.5 s, against 344 and 369 s (median 356.5 s) in loop 31 |
| AC-2 | `readonly-gate` as three groups and three jobs, each at most 220 s | covered | `ro_gate_run` + three check functions; groups 121, 88, 94 s; jobs 184, 176, 179 s (plus 63, 2, 30 s of waiting for a slot) |
| AC-3 | `pins` in `publish-gate-rest` | covered | `test.yml`; `pins` 26 s in a 138 s group total, job 205 s |
| AC-4 | `phases` in two groups, every phase check in one, each job at most 220 s | covered, cut changed | `phases` 105 s and `phases-rerun` 108 s (jobs 196 and 170 s); the cut is by the Mac profile (the owner's example of success against failure scenarios would have been 73 s against 213 s there); `ph_split` + 4 mutants |
| AC-5 | Swift strict build (SW-9) in exactly one part, `gates` at most 200 s, no part above 250 s | covered | `swift_strict` on the one release build; gates job 191 s (steps 157), tests 246, speed 224; `run-suite-swift.test.sh` S2f, 19 mutants of `run-suite.sh`; real container runs of both parts; a planted warning in a test file fails the speed part |
| AC-6 | no check lost, 19 groups in exactly one job, a mutant per changed rule | covered | `publish-jobs.test.sh` (77 mutant calls, was 66), `publish-timing.selftest.sh` (`ro_split` 5 mutants, `ph_split` 4), `run-suite-swift.test.sh`; one assertion of the bad-fixture scenario ("the run did not finish") cannot occur with a foreground run and is gone (recorded in the notes) |
| AC-7 | job count and queue wait read from the first run | covered | 23 jobs; three waited for a slot (63, 35, 30 s) and none set the wall; the jobs that waited are not the last in the file |
| AC-8 | the Mac gate runs the new shares from `test.yml` | covered | step 11: eight shares at once, wall 391 s against a sum of 2 395 s (ratio 0.16), tree unchanged (1 712 paths); `loop-tests.test.sh` passes |
| AC-9 | changed source files at most 500 lines | covered | largest changed file 448 lines (`publish-readonly.test.sh`) |
| D1 | `report-row.test.sh` compared the suites matrix with the languages in a fixed order | covered | found by running the scaffold checks locally before the push; the comparison is a set now, with a mutant check (matrix without typescript is refused) |
| D2 | `publish-workflow.test.sh` named the gate and embedded jobs by hand | covered | derived from the `publish-gate-*` and `embedded-*` job names |
| O1 | pulling only the images a job uses (swift 4 GB in seven jobs) | out-of-scope | review finding; the pull list is guarded to all eight images; a candidate for the next round with the C3 caches |
| O2 | `ring` (273 s) and `suites (swift, tests)` (246 s), the new floor of the wall | out-of-scope | the owner's decision D6 left `ring` out |
| O3 | a guard for the "longest job first" order of `test.yml` | out-of-scope | the order did not decide who waited (rust and the read-only jobs waited); not enforced |
