# Autodev loop record — loop 80

loop: 80
branch: dev
plan_artifact: none (short loop on the launcher: no new-task, no plan, no feature-assess)
tasks_shipped: [AZ-3369_ring_names_refused_row]
decisions:
  - owner (2026-10-28, intake): "accept all recommended": loop 80 is D5 of handoff80.md, a short loop; `_docs/_autodev_state.md` is tracked from now on (its line is out of `.gitignore`); the owner-held items stay held
  - agent: Jira AZ-3369 created by the agent (Task, Low, project AZ) because the short loop skips new-task; In Progress, then In Testing after the first batch (read back from the transition result)
  - agent: two batches on one ticket: c7af798 (the two `except ff.Fault` blocks, two cases, the traceback check in `run`) and 56eb43f (`stamp_pass` ignores the position file, found at step 11 when the plan listed 12 stages because no stamp had been written since loop 78); AC-5 added to problem.md for it
  - agent: step 11 ran the `scaffold` and `ring` stages only (`--only`), not `--all`: the loop 79 push is green on all 20 CI jobs (dev run 40667471630, main run 40682339673) and this diff is 4 files read by those stages and the publish gate; the smoke then ran `scaffold`, `ring` and `publish-gate` against stamps at 692edcc, the commit of loop 79's total run
  - agent: no per-batch code review (owner preference); the parent read the 4-file, 30-line diff; security lite escalated by T1 (`.github/workflows/ring-frame.test.sh`) and answered with a diff-scoped pass (`_docs/05_security/lite_loop80.md`): 0 new findings, the Info of loop 79 closed
measurements:
  - probe on HEAD 69b02b8 (python 3.14.8): `seal E1` with kind 16 and `mac E4` with n 5 each end in a `framefmt.Fault: BadValue` traceback with no file, line or case
  - `ring-frame.test.sh`: 32 PASS on HEAD; with the two new cases and the old `ring_frame.py` 32 PASS, 2 FAIL (a traceback in each output); with the fix 34 PASS, 0 FAIL
  - real ring with the 8 drivers: 21 s, `ring-frame: 64 pairs, mismatched: 0`, `refusals <lang>: 43 rows, 0 mismatched` x 8
  - `loop-tests.test.sh` on the loop-start script with the new case: `FAIL: execution: the autodev position file blocked the stamp`; with the fix: all checks passed
  - step 11 (`--only scaffold,ring` at c7af798, load 6 to 20): scaffold 298 s, ring 76 s, 374 s, 2 passed, 0 failed
  - smoke `smoke80.sh` 8 of 8 on the first trial (1,086 s, load 20 to 105): scaffold 267 s, ring 65 s, publish-gate 633 s (shares wall 632 s, sum 3,450 s, tree the same before and after)
  - CI of the loop 79 push, read at the start of this loop: dev 4 min 38 s, main 3 min 33 s, all green; `suites (csharp rust)` 252 s (286 s on the loop 78 push)
  - `test-results/stamps/*` are all at b7b8140 (loop 78): loop 79's step 11 wrote none (cause not established; the state file was ignored then); the default plan names 12 stages
review: "no per-batch code review (owner preference); feature assessment skipped by the short loop rule (worktree-isolation.md § Short loop on launcher)"
retro: not due (loops 75 to 79 done in loop 79; next after loop 84)
leftovers:
  - owner (unchanged): CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; whether to drop the M4F row; the release notes of the next 0.x; meshbell renames its Rust `Session` to `FrameSession`; whether the vcpkg port should drop `supports: linux | osx`; a public-key pairing step
  - closed this loop: the state file is tracked (owner answer); D5
  - ring, open: multi-part MAC messages (a new driver line format); key and msg_id length refusals (U1 of loop 77)
  - candidates from loop 76 still open: the AVR runtime check of `chacha20_xor`
  - open: L76-1 (timing-selftest flake cause unproven); Go intermittent failure L74-3; the stage stamps of `scripts/loop-tests.sh` are stale (b7b8140): one run that is clean apart from the state file and `_docs/` refreshes them
  - Jira: AZ-3369 In Testing; AZ-3356, AZ-3357, AZ-3354, AZ-3355 and earlier In Testing
lessons:
  - A decision that changes what git tracks or ignores needs a grep of every reader of `git status --porcelain`: tracking the state file made `scripts/loop-tests.sh` stamp nothing for the rest of the loop.
  - A smoke script that runs the publish gate fixes its own inputs first: state, notes and the checklist are written before it starts, because the gate fails when any file in the repository changes while its shares run.
smoke: PASS
smoke_artifact: _docs/loops/loop80/smoke80.md
loop_end_merge: main
