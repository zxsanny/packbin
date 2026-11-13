# Autodev loop record - loop 117

loop: 117
branch: dev
plan_artifact: _docs/loops/loop117/plan117.md
tasks_shipped: [AZ-4243]
decisions:
  - agent: the queue item went straight to a spec (2 points); implemented by the parent
  - agent: removed the redundant `java/src/test/*` pattern of `is_test_path` (pre-existing shellcheck SC2221/SC2222 in the modified file; `*/test/*` matches the same paths)
measurements:
  - `scripts/loop-tests.test.sh`: passes in 58 s; against a copy with the old rule the new checks fail (`a dirty _docs/ blocked the stamp`, `rust not skipped after the documents were committed`)
  - step 11 `scripts/loop-tests.sh` at `65bee8b` with `_docs/loops/loop117/smoke117.sh` untracked (`tree: 1 changed paths`): `scaffold` PASS (831 s, host load 35 to 98: another session's .NET tests and the Docker VM), 14 skipped as unchanged, 0 failed; the `scaffold` stamp was written at `65bee8b` (before this loop no stamp would have been written)
  - smoke `smoke117.sh` 5/5 PASS at `65bee8b`, host load 41
review: "PASS (`_docs/03_implementation/reviews/batch_01_loop117_review.md`): 1 Low fixed"
feature_assessment: COMPLETE, round 1 (`assessment117.md`)
security: not in plan (trivial: one line of a local test runner and its test)
retro: none (due by loop 118)
leftovers:
  - _docs/OPERATOR_TODO.md D10, D11 (open since loop 116); N1, N2, N4, D5, D6, D9 (unchanged)
smoke: PASS (agent-verified)
smoke_artifact: _docs/loops/loop117/smoke117.md
assessment_artifact: _docs/loops/loop117/assessment117.md
loop_end_merge: main
