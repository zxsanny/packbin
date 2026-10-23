# Autodev loop record — loop 64

loop: 64
branch: dev
plan_artifact: _docs/loops/loop64/plan64.md
tasks_shipped: []   # a documents-only loop: the retrospective of loops 61 to 63
decisions:
  - owner (2026-10-23, AskUserQuestion, recommended option): loop 64 is the "Retrospective loops 61-63" (handoff64 action 2)
  - agent: short loop with no code (`worktree-isolation.md` §Short loop): no task spec, no plan row for implement or assess, so no Jira key is owed; plan64 has retrospective, step 11, smoke
  - agent: `_docs/LESSONS.md` held 17 entries (the close of loop 63 appended 2 without the trim); trimmed to 15 after adding 2 lessons (dropped the four oldest, all 2026-10-20: architecture, testing, estimation, tooling; the `split_at_mut` one also lives in `AGENT_GOTCHAS.md`)
  - agent: the third recurrence of "a figure in an AC not read from a run on HEAD" went to `AGENT_GOTCHAS.md` as one line instead of a third LESSONS bullet (retrospective Step 4.4)
  - agent: no push of a record-only commit (retro improvement 3): the CI read of this push is handoff65 action 0
leftovers:
  - owner (retro improvements 2 and 3): a named consumer for the 468 B flash margin before another flash loop (or a stack-targeted candidate, margin 16 B); whether `test.yml` gets `paths-ignore: ["_docs/**"]` on `push`
  - candidates (unchanged): `item` pointer removal (needs offset + stride, 4 B more per entry), out-of-line error helpers in `unpack.cpp` and `values.cpp` (unmeasured), flag-byte chain inside a `times` round, loop 53 items (session stack, `session_core` clippy, ring driver for `nostd`)
  - owner (unchanged): size limits for text/ecc/session; CS-D5; first `v*` / `go/v*` tags; F44; close the epic AZ-2750; U24 in the C++ package
  - L63-1: Cortex-M4F flash margin 468 B (pin 7,724 B), stack margin 16 B; the error-path stack of the out-of-line `bad` is bounded by arithmetic (about 492 B), not measured
  - Jira: connector absent (no Jira tool found at loop 64 start). AZ-3163 and AZ-3164 are To Do (`2026-10-22_loop59_jira_in_testing.md`); five tasks have no key yet (`2026-10-22_loop60_jira_create_tasks.md`); epic AZ-2645 open; this loop created no task
  - CI: loop 63 push read at loop 64 start, green on `dev` and `main` for `7923b0b` and for the record commit `3619a2d`; the CI of this loop's push is read at the next loop start (`handoff65.md` action 0)
smoke: PASS (agent run 7/7, owner rule 2026-10-12)
smoke_artifact: _docs/loops/loop64/smoke64.md
step11: RESULT 0 passed, 14 skipped as unchanged, 0 failed, 0 s at d65adcf (only `_docs/` changed)
review: none (no source change)
security: not in plan
retro: done in this loop, `_docs/06_metrics/retro_2026-10-23_loop64.md` (loops 61 to 63; next due after loop 68 or an incident)
loop_end_merge: main
