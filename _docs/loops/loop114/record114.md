# Autodev loop record - loop 114

loop: 114
branch: dev
plan_artifact: none (short loop: one test line; problem in `_docs/02_task_plans/cpp-ecc-api-test-out-buffer/problem.md`)
tasks_shipped: [AZ-4237]
decisions:
  - agent: short loop on the launcher (one line of test code, no library change): no new-task, plan or feature-assess; security step not run (trivial: test code only, 1 changed line)
  - agent: the sanitizer smoke judges sanitizer reports and non-timing checks; a missed wall-clock bound in a sanitizer build is printed, not failed, until the queue item below is done
measurements:
  - before the fix, at `40171d9`: clang ASan + UBSan host suite stops with `stack-buffer-overflow ecc.hpp:172 in packbin::ecc::protect`, called from `pack_into_a_small_buffer()` `ecc_api_tests.cpp:91`
  - after the fix (`ccbbadb`): 0 sanitizer reports in three runs; the text speed check (1 s nominal) missed its bound in two of them by 3 to 13 ms (1.015 s / 1.012 s at load 10, 1.017 s / 1.004 s at load 50) and held it in the third (`all tests passed`)
  - Apple clang `make -C cpp test` and `gcc:16` `make test`: exit 0
  - smoke `smoke114.sh` 5/5 PASS at `ccbbadb`, host load 13
  - CI on the close push `db29957`: `dev` run 43283850701 success, `main` run 43283857971 success (20 of 20 jobs)
review: "none (one line of test code)"
leftovers:
  - _docs/02_tasks/backlog/cpp-wall-clock-bounds-under-sanitizers.md
  - OPERATOR_TODO N1, N2, N4, D5, D6, D9 (unchanged)
smoke: PASS (agent-verified)
smoke_artifact: _docs/loops/loop114/smoke114.md
loop_end_merge: main
