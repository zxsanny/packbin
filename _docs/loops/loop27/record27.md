# Autodev loop record — loop 27

loop: 27
branch: dev
plan_artifact: _docs/loops/loop27/plan27.md
tasks_shipped: [AZ-2556]
leftovers:
  - CG-3: the gate is green in 2 of 3 consecutive runs (38694589648, 38700362252); the third is the CI run of this loop's close push (`dev`, and `main` on the same commit): read it first at the start of loop 28 (Actions API with `curl`)
  - the `f30c87e` gate failure (1 of 2 runs, before `aefaf37`) is unexplained; it was not reproduced in the Mac or Linux runs
  - cpp stage race in the step 11 pool: `cpp/build/` is shared with the `scaffold` stage (chip `task_29aaaea6`, not started)
  - review27 #5 skipped (two-heredoc stand-in); the sanitizer list in `swift_sanitized` is closed (a new thread-using suite must join it; a guard fails the step for a threaded file outside it)
  - open owner rows: F44 (tag ruleset, the owner applies it); the first tags (the first `vX.Y.Z` with the Swift check, the first `go/vX.Y.Z`); S3 stays B (a Swift 6.0 consumer unproven, not yet written into the README/ADR-005 as a documented limit)
  - from loop 26 still open: review26 #5 peak memory of the max-slots unpack, #8 README says Linux before a first Linux run; the unverified parts (Swift 6.0, Xcode 16.0, tvOS, watchOS, Android, Windows, WASI); the small items of handoff26
  - AZ-2068 (C++ AVR stretch) stays in `todo/`; the epic AZ-2223 stays open until the first tag resolves
smoke: PASS (agent walk 5 PASS / 1 NOT RUN [CG-3 third run]; owner PASS 2026-10-15)
smoke_artifact: _docs/loops/loop27/smoke27.md
assessment_artifact: _docs/loops/loop27/assessment27.md
loop_end_merge: main
