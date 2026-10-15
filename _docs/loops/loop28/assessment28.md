# Feature assessment — loop 28 (round 1)

FEATURE ASSESSMENT loop 28 round 1: COMPLETE with one measurement pending — 15 covered / 1 pending the second CI run / 0 gap-clear / 0 gap-unclear

Intent baseline: `_docs/02_task_plans/ci-split-and-leftovers/` (`problem.md`, `acceptance_criteria.md`, `scenarios.md`). Evidence: `_docs/03_implementation/test_run_loop28_report.md`, `review28.md` (inline review, 6 findings, 2 fixed), `deploy_status_report.md` "Loop 28" sections, `_docs/05_security/swift_peak_memory_loop28.md`.

| Row | Status | Evidence |
|-----|--------|----------|
| SP-1 five jobs green, publish still gated | covered | run 38731123341: 5 of 5 `success`; `publish.yml` unchanged; `publish-jobs.test.sh` 13 mutants rejected |
| SP-2 wall time at most 25 min, gate step at most 1 500 s | pending (1 of 2) | run 38731123341: 22 min 51 s, gate step 1 269 s; the close push gives the second run, read at the next loop's start if not done at close |
| SP-3 no check removed | covered | same commands in exactly one job (`publish-jobs.test.sh` rules for the 6 static scripts, the 8-suite loop, the gate); plus `mkdir test-results` and `pull images` steps added |
| SP-4 guards follow and bite | covered | `publish-jobs.test.sh` (13 mutants); `ring-wiring`, `run-suite`, `report-row`, `ring-wiring-swift` pass on the new file |
| SP-5 14 timing lines, 0 assertions changed | covered | step 11 log: 14 lines + total; `publish-timing.selftest.sh` 2 mutants rejected; gate passes with unchanged assertions |
| CR-1 cause named | covered | status report "Loop 28: cause of the `cpp` pool stage failure": host `rm -rf` then immediate container start, 6 of 12 alone |
| CR-2 3 pool runs, 0 retries; guard rejects the old command | covered | worker runs 174/172/172 s, 0 retries; step 11 cpp PASS 42 s; check 15 mutant rejected. Amended: the cause was not a second stage |
| DO-1 limit stated in 3 places | covered | README language line and Swift section, ADR-005 Negative and Notes |
| DO-2 claims match runs | covered | README names `swift:6.3.3` CI and one `swift:6.4.1` publish position run only; no `swift:5.9` |
| PM-1 two figures recorded | covered | 731 MB / 154 MB macOS, 738 MB / 147 MB container; no finding |
| S-1..S-14 scenarios | covered/out-of-scope as recorded | S-13, S-14 out of scope by decision |

## Discovered during the loop

| Angle | Handling |
|-------|----------|
| The cpp failure was a host-delete / container-start timing effect, not a pool race | cause corrected in the loop 27 test report; AGENT_GOTCHAS rule added |
| The gate's 14 groups: four are 93 % of its time | leftover for the next loop: swift 284, readonly 263, phases 251, gate 191 |
| Pattern "delete a mounted path on the host, then start a container" not audited elsewhere (review #4) | leftover |
