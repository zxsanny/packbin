# Autodev loop record — loop 32

loop: 32
branch: dev
plan_artifact: _docs/loops/loop32/plan32.md
tasks_shipped: [AZ-2625]
leftovers:
  - AC-1 (median of two runs at most 330 s): run 1 (39024316436, `c0e8019`) 275 s; run 2 is the close push, recorded in `notes32.md` after it ran
  - next long poles of test.yml (275 s): `ring` 273 s (unchanged since loop 28), `suites (swift, tests)` 246 s; every job the loop cut is under 250 s
  - image pulls: seven gate jobs pull all eight images (swift 4 GB); the phases jobs use five, and `publish-jobs.test.sh` demands all eight in the pull line; with the C3 caches the candidate for the next round (not asked)
  - 23 jobs per push against the free plan's 20 slots: three jobs waited 30 to 63 s on run 1 and none set the wall; a `dev` + `main` push is 46 jobs, queueing not measured
  - the strict release build (SW-9) now fails inside the Swift `speed` part (and late in the Mac single run); the label does not say SW-9
  - the two vcpkg checks are NOT RUN on the Mac (no vcpkg tool); CI runs them
  - the loop 31 docs commit 48ffe99 had not been pushed and went to origin with this loop's first push (asked as "2 commits", it was 3)
  - from loop 31 and earlier: T3 (Go proxy wait) and T1 (tag run skips the repeated test) unproven until the next `v*` / `go/v*` tag (owner's go); F44 (tag ruleset) and the first tags owner only; AZ-2068 in `todo/`
smoke: PASS (agent run 8/8, owner rule 2026-10-12)
smoke_artifact: _docs/loops/loop32/smoke32.md
assessment_artifact: _docs/loops/loop32/assessment32.md
loop_end_merge: main (not executed this loop: the owner said no push of `main`)
