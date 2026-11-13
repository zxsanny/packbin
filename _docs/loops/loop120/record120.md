# Autodev loop record - loop 120

loop: 120
branch: dev
plan_artifact: _docs/loops/loop120/plan120.md
tasks_shipped: [AZ-4255]
origin: operator
decisions:
  - operator: D12 B (refuse at unpack, no API change), 2026-11-13
  - agent: the setter's rejection is told apart by the `ClassCastException` message naming the unpack collection as the cast source (`class java.util.ArrayList cannot be cast` / `class java.util.LinkedHashMap cannot be cast`); any other message is rethrown unchanged
  - agent: the error names the kind (`list` / `dict`), not the field: a Java field has no name (the KeySetter naming branch of the first version could never run, removed)
  - agent: the code was written before the intake files; the Jira key was guessed (AZ-4254) and the create call returned AZ-4255; references fixed before the commit
measurements:
  - the two refusal tests fail on the old unpack path with the raw `ClassCastException`
  - `bash scripts/probes/element-row/run.sh java`: 22 lines; exactly `coll-linkedlist` and `coll-treemap` changed (unpack `threw: ClassCastException` to `refused: IllegalArgumentException`), pack hex identical, the other 20 lines byte-identical
  - step 11 `scripts/loop-tests.sh` at `51a33ff`: java 17 s, ring 82 s, publish-gate 317 s (vcpkg checks NOT RUN, N2); 3 passed, 12 skipped, 0 failed, 416 s, host load 10 to 20
  - smoke `smoke120.sh` 4/4 PASS at `51a33ff`, 16 s
review: "PASS_WITH_WARNINGS (`_docs/03_implementation/reviews/batch_01_loop120_review.md`): 3 Low (field name unavailable; code before intake files, key fixed; message-based test accepted)"
feature_assessment: COMPLETE, round 1 (`assessment120.md`)
security: "`_docs/05_security/lite_loop120.md` CLEAN (the 9 T2 matches are `hash` in `LinkedHashMap`)"
retro: none (next due by loop 123)
leftovers:
  - _docs/02_tasks/backlog/hygiene.md (entry `java-top-level-row-class` from loop 119, unchanged)
  - _docs/OPERATOR_TODO.md D13 (applied); N1, N2, N4, D5, D6, D9, D11 unchanged
smoke: PASS (agent-verified)
smoke_artifact: _docs/loops/loop120/smoke120.md
assessment_artifact: _docs/loops/loop120/assessment120.md
loop_end_merge: main
