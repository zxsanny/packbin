# Autodev loop record — loop 32

loop: 32
branch: dev
plan_artifact: _docs/loops/loop32/plan32.md
tasks_shipped: [AZ-2625]
leftovers:
  - AC-1 met: runs 39024316436 (`c0e8019`) 275 s and 39025925515 (`73ba412`, the close push) 264 s, 23 of 23 jobs green each, median 269.5 s against the 330 s bound (loop 31: 356.5 s); the goal of about 5 minutes is met by both runs
  - next long poles of test.yml (264 and 275 s): `ring` 261 and 273 s (unchanged since loop 28), then `suites (swift, speed)` 218 s and 224 s, `suites (swift, tests)` 180 and 246 s; every job the loop cut is under 250 s
  - image pulls: seven gate jobs pull all eight images (swift 4 GB); the phases jobs use five, and `publish-jobs.test.sh` demands all eight in the pull line; with the C3 caches the candidate for the next round (not asked)
  - 23 jobs per push against the free plan's 20 slots: three jobs waited on each run (30 to 63 s, then 60 to 67 s), not the same jobs, and none set the wall; a `dev` + `main` push is 46 jobs, queueing not measured
  - the strict release build (SW-9) now fails inside the Swift `speed` part (and late in the Mac single run); the label does not say SW-9
  - the two vcpkg checks are NOT RUN on the Mac (no vcpkg tool); CI runs them
  - the loop 31 docs commit 48ffe99 had not been pushed and went to origin with this loop's first push (asked as "2 commits", it was 3)
  - from loop 31 and earlier: T3 (Go proxy wait) and T1 (tag run skips the repeated test) unproven until the next `v*` / `go/v*` tag (owner's go); F44 (tag ruleset) and the first tags owner only; AZ-2068 in `todo/`
smoke: PASS (agent run 8/8, owner rule 2026-10-12)
smoke_artifact: _docs/loops/loop32/smoke32.md
assessment_artifact: _docs/loops/loop32/assessment32.md
loop_end_merge: main (not executed this loop: the owner said no push of `main`)
