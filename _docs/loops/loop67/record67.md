# Autodev loop record — loop 67

loop: 67
branch: dev
plan_artifact: _docs/loops/loop67/plan67.md
tasks_shipped: [AZ-3185_cpp_unpack_flag_scope_stack]
decisions:
  - owner (2026-10-25, AskUserQuestion): loop 67 = "Stack of flag scope in times round" (recommended option of four); win = stack at most 548 B with flash at most 7,724 B, otherwise a measured no-go (recommended option of three)
  - agent: shape V5 kept (`unpack_children` keeps the outer flag bytes of a `when` itself, `keep` pointer, null for a group); shapes B2, B3, B4, B4b, B4c measured and recorded in the batch report and `AGENT_GOTCHAS.md`
  - agent: `flash_pin` lowered to 7712 with the stack pin (AC-5 named only `stack_pin`; the flash pin follows the figure, as in loops 62 and 63)
  - agent: Jira AZ-3185 created under AZ-2645 (type Task, 3 points as "Story point estimate"; the field "Story Points" does not exist in this project), moved to In Testing and read back
leftovers:
  - owner: CS-D5 (deferred); first `v*` / `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package
  - candidates: stack of the session `open` frame (528 B, now 12 B under the pin; any further unpack saving stops there); `Result` returned through a hidden pointer puts a 16 B temporary in every walk frame (a smaller `Result` is a wide change); Go window floor of 10 s if a stall shows in CI; `item` pointer removal; out-of-line error helpers in `unpack.cpp` / `values.cpp`; session stack; `session_core` clippy; ring driver for `nostd`
  - open: the cause of the container `pip install` failure of loop 65 (no repeat in loops 66 and 67)
  - Jira: AZ-3185 In Testing at close (read back); epic AZ-2645 open
  - CI: loop 66 pushes read at the start of this loop, green on `dev` (run 40083812392, 3 m 32 s) and `main` (run 40083819498, 7 m 12 s); the CI of this loop's push is read at the next loop start
smoke: PASS (agent run 5/5, owner rule 2026-10-12)
smoke_artifact: _docs/loops/loop67/smoke67.md
assessment_artifact: _docs/loops/loop67/assessment67.md
step11: `scripts/loop-tests.sh` one run at `642f139`: cpp, scaffold, cpp-embedded-arm, rust-embedded, ring PASS (5 passed, 9 skipped as unchanged, 0 failed, 376 s, load 5 to 9); the arm stage log shows stack 540 B, flash 7,712 B
review: feature-assess COMPLETE (8 of 8 rows covered or out-of-scope, one residual risk); no per-batch code review (owner preference)
security: not in plan
retro: not in plan (last retro loops 61 to 63; next after loop 68)
loop_end_merge: main
