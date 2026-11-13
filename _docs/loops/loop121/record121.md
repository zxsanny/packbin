# Autodev loop record - loop 121

loop: 121
branch: dev
plan_artifact: _docs/loops/loop121/plan121.md
tasks_shipped: [AZ-4257, AZ-4258, AZ-4259, AZ-4260, AZ-4261]
origin: agent
decisions:
  - agent: the hygiene queue item (8 entries) ran as one loop of five tasks by package group (work-queue.md §Agent-made work rule 1); four parallel workers on disjoint directories (Java; Python; C# and Go; C++), the Dart task by the parent
  - agent: D14 applied (Java top-level row class checked with the no-argument constructor unpack uses), D15 applied (C++ timing checks print and do not assert under a sanitizer), D16 applied (scalar missing members keep `missing field N`)
  - agent: a typed Java row says `missing utf8 1` (an accessor lambda has no name); only Map rows and Python say `missing text`
  - agent: the loop 119 row-class check now refuses only a ClassCastException about the row (found by the Java worker)
measurements:
  - chain of nested `when`s after a repeat: Java 4,000 deep 0.123 s to 3 to 5 ms; C# 16,000 deep 3.17 s to 5.4 ms; Go 16,000 deep 1.80 s to 1.9 ms; differential tests (Java 30,000, C# 3,000, Go 20,000 random trees) 0 differences
  - new tests fail on the old code (Python 10 of 16, Java 5 and 9, C++ stubs 4 of 6 and 4 of 5, the chain timing tests); Dart suite 2,088 passed, also at host load up to 56
  - `bash scripts/probes/element-row/run.sh java`: 22 lines, only `null-member` and `null-member-map` changed; Python: `null-member` and `null-item` changed
  - step 11 `scripts/loop-tests.sh` at `40a8f71` (all 15 stages: the shared pin file covers every suite): 15 passed, 0 failed, 1,236 s, host load 10 to 25; `dart` failed once in the pool (the loop 113 test `repeat_last_cost_test.dart`, 869 ms against a scaled 514 ms, load factor 1.72) and passed on the runner's serial retry; re-run at `88df315` of `cpp`, `scaffold`, `cpp-embedded-arm`: 3 passed, 421 s; vcpkg checks NOT RUN (N2)
  - smoke `smoke121.sh` 8/8 PASS at `88df315` (a first run failed step 7: two real SC2016 notes and a bar stricter than the project's; fixed)
review: "PASS_WITH_WARNINGS (`_docs/03_implementation/reviews/batch_01_loop121_review.md`): 7 Low, all accepted or fixed"
feature_assessment: COMPLETE, round 1 (`assessment121.md`)
security: "`_docs/05_security/lite_loop121.md` ESCALATE (T1, T3, T4, T5) -> `security_report_loop121.md` PASS, 1 Low (L1: the ESP core download is not hash-checked beyond the package index, as before)"
retro: none (next due by loop 123)
leftovers:
  - _docs/02_tasks/backlog/hygiene.md (2 entries: `dart-repeat-last-cost-test-flake`, `cpp-sanitizer-ci-job`)
  - _docs/OPERATOR_TODO.md D14, D15, D16 (applied, may be overturned); N1, N2, N4, D5, D6, D9, D11 unchanged
smoke: PASS (agent-verified)
smoke_artifact: _docs/loops/loop121/smoke121.md
assessment_artifact: _docs/loops/loop121/assessment121.md
loop_end_merge: main
