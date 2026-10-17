# Feature assessment — loop 31

loop: 31
feature: ci-speed-2
rounds: 1
verdict: COMPLETE (AC-1 needs its second run at the close push; AC-4's real proof is step 11; `scenarios.md` absent: no new-task Step 4.7 for this loop, the spec ACs and the batch reports are the baseline)

FEATURE ASSESSMENT loop 31 round 1: COMPLETE — 10 covered (3 with a measurement still to come) / 2 out-of-scope / 0 gap-clear / 0 gap-unclear

| id | scenario | status | evidence |
|----|----------|--------|----------|
| AC-1 | CI wall at most 360 s as the median of two `dev` runs | covered, run 1 of 2 | run 39014663944 (`0fc35f8`): 344 s, 20 jobs green; baseline 418 and 382 s; run 2 is the close push (same code, docs only) |
| AC-2 | one timing notice per gate job and per suite job, readable without a token | covered | `run-suite.test.sh` N1 to N6, `run-suite-swift.test.sh` S2e, `run-parts.test.sh`; the annotations of run 39014663944 hold the seconds of every group, step and embedded target |
| AC-3 | no check lost; each group, Swift step and embedded target in exactly one place | covered | `publish-jobs.test.sh` (66 mutant calls), `publish-timing.selftest.sh` `ro_split` (7 read-only checks) and the trap rule, `run-suite-swift.test.sh` S2d (33 mutants), `run-parts.test.sh` (26 mutants) |
| AC-4 | the Mac gate runs the CI shares at the same time, fails on a failing share or a changed tree | covered, proof at step 11 | `scripts/loop-tests.sh` `gate_shares`, `run_gate_shares`, `tree_manifest`; `loop-tests.test.sh` 16a to 16e (12 mutants); the ratio `wall / sum of shares` is printed and read at step 11 |
| AC-5 | `publish-phases.test.sh` at most 500 lines, same 9 checks | covered | 323 and 193 lines; function inventory identical to HEAD; `phase_checks` unchanged |
| AC-6 | host-delete audit | covered | `notes31.md`: 0 harmful sites |
| D1 | the owner's follow-up decision C4 (embedded split) | covered | `embedded` 360 s became `embedded-esp-core` 209, `embedded-esp-packages` 157, `embedded-arm` 52 s; 73 checks and 26 mutants of `run-parts.test.sh` |
| D2 | `GITHUB_ACTIONS=true` now reaches the suite and publish containers | covered | two green CI runs with every suite and the gate; no tool in the repo reads it |
| D3 | the real `swift test list -c release --skip-build` of the speed part | covered | CI: `suites (swift, speed)` 227 s green; container run on the Mac listed SpeedTests |
| D4 | the Mac shares use the same compose project, host `~/.platformio` and caches at the same time | covered, proof at step 11 | read-only analysis in the batch 1 report (no write into the tree; shared caches only); step 11 shows it |
| O1 | a group that prints only at its end keeps the Mac heartbeat flat (a "started" line) | out-of-scope | not asked; recorded in the handoff |
| O2 | splitting `publish-gate-readonly-gate` (three gate runs), `pins`, `phases` further, caches (C3), the PlatformIO install in the Arduino target | out-of-scope | the owner's batch left C3 out; the next long poles are listed in `notes31.md` |
