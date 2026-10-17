# Loop 32 handoff — written 2026-10-17 while loop 31 was closing

Read `_docs/loops/loop31/record31.md`, `notes31.md`, `assessment31.md`, `_docs/04_deploy/reports/ci_metrics_2026-10-16.md` section 7, `_docs/03_implementation/test_run_loop31_report.md` and `_docs/06_metrics/retro_2026-10-17_loop31.md`. Owner preferences from `_docs/loops/loop26/handoff27.md` stand; the decision-batch form ("accept all recommended" first) worked again.

## State when loop 31 closes
- `test.yml` 344 s and 369 s on two runs of the final code (runs 39014663944 and 39018150736, 20 jobs each; median 356.5 s); `dev` is pushed (`fbce19f`), `main` is not. Mac `publish-gate` stage 613 s (5 shares at once).
- Timing notices exist for every suite, gate and embedded job: read them with `scratchpad/ci_timings.sh <run id>` style calls (`runs/<id>/jobs`, then `check-runs/<job id>/annotations`), no token.
- Watch out: `scripts/loop-tests.sh` fails its gate stage when the repository changes while it runs; and a Monitor pipe must end in `grep --line-buffered` (both are in `AGENT_GOTCHAS.md`).

## Candidate work (owner picks)
- Another CI round: `publish-gate-readonly-gate` as three jobs, `pins` out of it, `phases` in two groups, Swift `gates` split, one pull for several gate jobs (C3); target about 5 minutes.
- Owner only: F44 (tag ruleset), the first `v*` and `go/v*` tags (they also prove T1 and T3).
- `AZ-2068` (C++ AVR, stretch) stays in `todo/`; the flash margin is 32 B.
