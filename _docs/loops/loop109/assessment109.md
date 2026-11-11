# Feature assessment — loop 109

loop: 109
feature: embedded-arm-dns-cause (AZ-4198)
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-11-11
**Implement pass**: no batch report (one 3-point CI task, two commits `8aefec7`, `412ccc4`, findings commit `c812ff3`); evidence in `_docs/06_metrics/embedded-arm-dns_2026-11-11.md`
**Verdict**: COMPLETE — 8 covered / 0 out-of-scope / 0 gap-clear / 0 gap-unclear

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | the owner dispatches the workflow on `dev` | covered | AC-1, AC-2; runs 43098620838 and 43100819627 (three config blocks, 246 and 248 lookups per path) | scenarios.md 1 |
| S2 | dispatched again at another time | covered | run 43100819627, 21:13 to 21:25 UTC, after run 43098620838 | scenarios.md 2 |
| S3 | dispatched while a push CI run goes | covered | run 43100819627 ran beside `test.yml` run 43100805944 (success 20 of 20); no shared state | scenarios.md 3 |
| S4 | a lookup fails during the window | covered | no lookup failed on the runner; the failure branch ran on the Mac trial (the host path printed `result=fail exit=127` and the loop went on); the `-e` bug found by run 1 is fixed (`412ccc4`) and run 2 is green | scenarios.md 4 |
| S5 | a fork or an outside contributor | covered | `workflow_dispatch` only, `permissions: contents: read`, no `secrets.`, no `uses:` (lite record) | scenarios.md 5 |
| S6 | the minutes input is empty or out of range | covered | local test of the validation block: `''`, `abc`, `5`, `25` give 12 with a message; `10`, `15`, `20` pass | scenarios.md 6 |
| S7 | the structure checks of `.github/workflows/*.yml` | covered | `publish-pins`, `publish-workflow`, `publish-readonly` self-tests exit 0 | scenarios.md 7 |
| S8 | no failure shows in any run | covered | findings say `not reproduced`; the host-network build stays with that reason; comments in `run.sh` and the `Dockerfile` quote it | scenarios.md 8 |

### Gaps that need a decision (gap-unclear)

None.

### Gaps that are clear (gap-clear)

None.

### Not walked

- none

### Harness gaps

- none; the loop has no batch report. The C# task AZ-4199 (owner's own `/implement` in a side session) has its own batch report and is outside this assessment.
