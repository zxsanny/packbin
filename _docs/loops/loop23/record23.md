# Autodev loop record — loop 23

loop: 23
branch: dev
plan_artifact: _docs/loops/loop23/plan23.md
tasks_shipped: [AZ-2431, AZ-2432, AZ-2433, AZ-2434, AZ-2435, AZ-2436, AZ-2437]
leftovers:
  - owner rows U24 (C++ unbound counted member, U11), U25 (C++ ids outside int16, F39), U26 (C# nested-row group in dictionary rows, F40), review23 Low 1 (Python RuntimeError) — `_docs/loops/loop24/handoff24.md`
  - Go package AZ-2222 follows the loop 24 decisions
  - AZ-2068 (C++ AVR stretch) stays in `todo/`
  - ESP targets of `cpp-embedded-esp` not run locally (CI `embedded` job runs them on the push)
  - F10 and F12 stay open (Medium) in the security report
smoke: PASS
smoke_artifact: _docs/loops/loop23/smoke23.md
assessment_artifact: _docs/loops/loop23/assessment23.md
loop_end_merge: main
