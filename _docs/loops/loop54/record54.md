# Autodev loop record — loop 54

loop: 54
branch: dev
plan_artifact: _docs/loops/loop54/plan54.md
tasks_shipped: [AZ-2815, AZ-2816, AZ-2823]
decisions:
  - owner (2026-10-21): the loop does the C++ `when` of a skipped source (handoff 54) and "also c# fix" (the red `main` suite of loop 53); the C# cause was read from the CI log with `gh` (same test failed in loop 49, called a flake then)
  - agent: C# keeps the last text's field inside one pack call (`PackOut.EncodeText`), as Java and the others do; the test keeps its bound and adds a 0.25 s load-aware headroom check
  - agent: C++ gives a `when` source the hold link counts have (`mark_held`), one shared `source_skipped` in `values.cpp`; unpack agrees through `when_matches`
  - agent: two corpus cases (`k == 2`, `k == 0`) run in all eight packages; seven runners by workers (Rust, Go, Swift, Java) and by the parent (Python, TypeScript, C#); no other package had the defect
  - agent: feature assessment round 1 EXTEND (the 255-entry link limit of a `when` source, AZ-2823), round 2 COMPLETE
  - agent: total review after the batches, one security review, one step 11 (owner rule 2026-10-06)
leftovers:
  - owner: Xcode licence on this Mac (`sudo xcodebuild -license`); size limits for text/ecc/session; CS-D5; first `v*` / `go/v*` tags; F44; close the epic AZ-2750; U24 in the C++ package
  - review #1 (Medium): stack depth of the `when_matches` / `source_skipped` recursion on a nested chain is not measured on the Cortex-M4F image (margin 8 B)
  - review #3: a bool or group-presence source behind a clear `when` has no test (Python agrees on the probe only)
  - L54-1 (Low): a C++ `when` source more than 255 entries behind its `when` is refused at construction; other packages have no limit
  - the repeated-text tests of the other seven packages were never timed against their CI bound
  - security Low L52-1, observations O1 to O4 (`_docs/05_security/nostd_review_loop53.md`), L51-1
  - Jira: AZ-2815, AZ-2816, AZ-2823 In Testing; epic AZ-2645 open
smoke: PASS (agent run 7/7 at aaafdf6, owner rule 2026-10-12)
smoke_artifact: _docs/loops/loop54/smoke54.md
assessment_artifact: _docs/loops/loop54/assessment54.md
step11: RESULT 13 passed, 1 skipped as unchanged, 0 failed, 836 s at 0646aaf
review: `/code-review` high, 6 findings, 2 fixed, 4 skipped (1 Medium: stack depth, in leftovers), 0 High
security: PASS, 2 Low observations, `_docs/05_security/review_loop54.md`
retro: none (complexity 6, no incident, last retro loop 53)
loop_end_merge: main
