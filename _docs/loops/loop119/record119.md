# Autodev loop record - loop 119

loop: 119
branch: dev
plan_artifact: _docs/loops/loop119/plan119.md
tasks_shipped: [AZ-4253]
origin: operator
decisions:
  - operator: D10 A (refuse at build), 2026-11-13
  - agent: mechanism D13 A applied (the factory makes one child at build; each member's accessors run once on it; a ClassCastException is refused; any other failure on the empty child builds as before); no API change
  - agent: two factory-count tests of `TypedNestedRowTest` count from after the build (their intent: unpack's calls); a factory that returns null builds as before
measurements:
  - new tests fail 10 times on the old code, pass on the new
  - `bash scripts/probes/element-row/run.sh java`: 22 lines; exactly `other-row` and `nested-other-row` changed (`threw: ClassCastException` to `refused: IllegalArgumentException: utf8 0: declared for another row class; this row is Comment`)
  - step 11 `scripts/loop-tests.sh` at `352ae3d`: java 16 s, ring 82 s, publish-gate 396 s (vcpkg checks NOT RUN, N2); 3 passed, 12 skipped, 0 failed, 495 s, host load 4 to 23
  - smoke `smoke119.sh` 5/5 PASS at `352ae3d`, 17 s
review: "PASS_WITH_WARNINGS (`_docs/03_implementation/reviews/batch_01_loop119_review.md`): 1 Medium queued (top-level typed row), 1 Low fixed"
feature_assessment: COMPLETE, round 1 (`assessment119.md`)
security: "`_docs/05_security/lite_loop119.md` CLEAN"
retro: none (next due by loop 123)
leftovers:
  - _docs/02_tasks/backlog/hygiene.md (entry `java-top-level-row-class`, Medium)
  - _docs/OPERATOR_TODO.md D13 (applied, may be overturned); N1, N2, N4, D5, D6, D9, D11 unchanged
smoke: PASS (agent-verified)
smoke_artifact: _docs/loops/loop119/smoke119.md
assessment_artifact: _docs/loops/loop119/assessment119.md
loop_end_merge: main
