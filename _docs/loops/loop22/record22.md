# Autodev loop record — loop 22

loop: 22
branch: dev
plan_artifact: _docs/loops/loop22/plan22.md
tasks_shipped: [AZ-2410, AZ-2411, AZ-2412, AZ-2413, AZ-2414, AZ-2415, AZ-2416, AZ-2417, AZ-2418]
leftovers:
  - owner rows U18 to U23 (Rust `when` list in `times` and repack shift; C++ negative `eq` id; C++ `packed` bias -1; construct cases refused by the scope rule; Rust repeat blind spots; TypeScript bigint count) — `_docs/loops/loop23/handoff23.md`
  - gaps G1 to G3 of `assessment22.md` (raised-limit tests in Python and Rust, C++ empty-when shapes, U11 nested positions)
  - AZ-2068 (C++ AVR stretch) stays in `todo/`
  - ESP targets of `cpp-embedded-esp` not run locally (CI `embedded` job runs them on the push)
  - F10 and F12 stay open (Medium) in the security report
smoke: PASS
smoke_artifact: _docs/loops/loop22/smoke22.md
assessment_artifact: _docs/loops/loop22/assessment22.md
loop_end_merge: main
