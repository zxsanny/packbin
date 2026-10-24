# Autodev loop record — loop 66

loop: 66
branch: dev
plan_artifact: _docs/loops/loop66/plan66.md
tasks_shipped: [AZ-3171_publish_gate_load_aware]
decisions:
  - owner (2026-10-24, AskUserQuestion): loop 66 = "Publish gate under load" (recommended option of three)
  - agent: the Go window is sized in the test from three probe asks (`gt_window`: 3 s plus four times the slowest, whole seconds); `publish-go.sh` `proxy_check` is unchanged
  - agent: the "pip error not kept" defect is the two failure messages quoting `tail -n 3`; they quote 25 lines now through `ph_quote`; the cause of the pip failure itself is unknown, `publish-inside.sh` is unchanged (AC-6)
  - agent: Jira connector returned in this session: AZ-3163 and AZ-3164 moved to In Testing; AZ-3165 to AZ-3171 created under AZ-2645 (searched the key range first, none existed), AZ-3165 to AZ-3170 moved to In Testing; the two leftover files are deleted
  - agent: the spec Outcome said "however slow one ask is"; changed to what AC-1 proves, the residual risk is in the assessment
leftovers:
  - owner: CS-D5 (deferred); first `v*` / `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; a named consumer for the 468 B flash margin or a stack-reduction loop for the 612 B case
  - candidates: stack of a flag scope inside a `times` round; Go window floor of 10 s if the stall risk shows in CI; `item` pointer removal; out-of-line error helpers in `unpack.cpp` / `values.cpp`; session stack; `session_core` clippy; ring driver for `nostd`
  - open: the cause of the container `pip install` failure of loop 65 (no repeat in this loop)
  - Jira: AZ-3171 moved to In Testing at close (read back); epic AZ-2645 open
  - CI: loop 65 push read at the start of this loop, green on `dev` (run 39997286503) and `main` (39997291793); the CI of this loop's push is read at the next loop start
smoke: PASS (agent run 5/5, owner rule 2026-10-12)
smoke_artifact: _docs/loops/loop66/smoke66.md
assessment_artifact: _docs/loops/loop66/assessment66.md
step11: `scripts/loop-tests.sh` run 1 at `3b8fed6`: scaffold PASS, publish-gate FAIL (share 7: phase-split self-test, `ph_quote` not in `ph_harness`); run 2 at `682a5c8` (`--only publish-gate`): 8 of 8 shares PASS, 378 s, load 6 to 29 (37 in run 1); 12 stages skipped as unchanged; `phases` group alone 240 s, `publish-go.test.sh` alone 32 s
review: feature-assess COMPLETE (7 of 7 ACs covered, one residual risk); no per-batch code review (owner preference)
security: not in plan
retro: not in plan (last retro loops 61 to 63; next after loop 68)
loop_end_merge: main
