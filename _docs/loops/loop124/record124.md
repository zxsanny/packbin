# Autodev loop record - loop 124

loop: 124
branch: dev
plan_artifact: _docs/02_tasks/done/AZ-4288_run_suite_split.md (short loop on the launcher: no plan file)
tasks_shipped: [AZ-4288]
origin: operator
decisions:
  - operator: "Run the split" (2026-11-14), the held agent-made hygiene entry `run-suite-split`, now operator-made
  - agent: Swift's helpers stay in run-suite.sh, because the CI Swift cache key hashes that file and three checks pin the key
measurements:
  - run-suite.sh 500 to 397 lines; run-suite.test.sh 521 to 485 (the cpp sanitizer checks moved to run-suite-cpp.test.sh)
  - 102 lines moved word for word; mutants without run-suite-cpp/go/rust.sh fail the self-test 4/19/21 times
  - step 11 `scripts/loop-tests.sh --jobs 3` at `935deaa`: 11 passed, 4 skipped as unchanged, 0 failed, 1,272 s, load 4 to 18, no retry
  - smoke `smoke124.sh` 6/6 PASS at `935deaa`
  - the app quit during the first close attempt; the close was redone in the next session (lock taken over from the exited process)
review: "PASS (inline, a word-for-word move; batch_01_loop124_report.md)"
security: "`_docs/05_security/lite_loop124.md` ESCALATE (T1) answered in the same file: PASS, no finding"
retro: none (next due by loop 128)
leftovers:
  - the first CI run after this push misses the Swift build cache once (its key hashes run-suite.sh)
  - AZ-4278 AC-1: dev runs 1 and 2 green (39db95b, c649d0e); run 3 is this push
  - _docs/OPERATOR_TODO.md: N1, N2, N4, D5, D6, D9, D11 unchanged
smoke: PASS (agent-verified)
smoke_artifact: _docs/loops/loop124/smoke124.md
loop_end_merge: main
