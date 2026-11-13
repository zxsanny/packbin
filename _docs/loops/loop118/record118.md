# Autodev loop record - loop 118

loop: 118
branch: dev
plan_artifact: _docs/loops/loop118/plan118.md
tasks_shipped: [AZ-4251]
origin: agent
decisions:
  - agent: queue classified under the agent-made rule of 2026-11-13 at bootstrap: 7 agent-found Low/Medium items folded into `backlog/hygiene.md`; `csharp-flags-in-flags-presence` kept alone (High: a value dropped with no error); the two Java items are operator-made (D10, D12)
  - agent: `_docs/AGENT_GOTCHAS.md` split into `_docs/gotchas/` (46 files, bootstrap B2 migration, one worker); `_docs/00_problem/tracker.md` written from the Jira gotcha
  - agent: AZ-4242 and AZ-4243 moved In Testing to Done at bootstrap (their loops were closed; tracker rule of 2026-11-13); D6 kept open for the older tickets
  - agent: security lite escalated by T1 (comment lines in two CI scripts) and T4 (probe manifests); scoped full audit PASS
measurements:
  - C# before the fix: `flags(flags(u8 x), bool b)` with both values packs `0102` (TypeScript `01030109`); the new tests fail 5 of 13 and the split-form tests 2 of 6 on the old code
  - C# suite after the fix: 5,491 passed, 0 failed, on `net10.0` and on the `netstandard2.0` build
  - `bash scripts/probes/flags-in-flags/run.sh`: 40 lines, all `same`, 29 s and 26 s, byte-identical, tree clean; only C# differed before the fix (`_docs/06_metrics/flags-in-flags-probe_2026-11-13.md`)
  - step 11 `scripts/loop-tests.sh` at `1f19fb0`: 9 passed (csharp 66 s, cpp 75 s, rust 117 s, scaffold 391 s, cpp-embedded-arm 17 s, rust-embedded 2 s, ring 78 s, ac10 5 s, publish-gate 318 s), 6 skipped as unchanged, 0 failed, 878 s, host load 3 to 37; publish gate NOT RUN for the two vcpkg checks (N2)
  - smoke `smoke118.sh` 6/6 PASS at `1f19fb0`, 36 s, host load 12
review: "PASS_WITH_WARNINGS (`_docs/03_implementation/reviews/batch_01_loop118_review.md`): 1 Low fixed (split flag-byte test), 1 Low kept (four packages probed in map-row form only)"
feature_assessment: COMPLETE, round 1 (`assessment118.md`)
security: "`_docs/05_security/lite_loop118.md` ESCALATE (T1, T4) -> `security_report_loop118.md` PASS, no finding"
retro: "`_docs/06_metrics/retro_2026-11-13_loop118.md` (loops 114 to 118; next due by loop 123)"
leftovers:
  - _docs/OPERATOR_TODO.md N1, N2, N4, D5, D6, D9, D11 (unchanged; N4 verify path corrected)
smoke: PASS (agent-verified)
smoke_artifact: _docs/loops/loop118/smoke118.md
assessment_artifact: _docs/loops/loop118/assessment118.md
loop_end_merge: main
