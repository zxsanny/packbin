# Lessons Log

A ring buffer of the last 15 actionable lessons extracted from retrospectives and incidents.
Downstream skills consume this file:
- `.cursor/skills/new-task/SKILL.md` (Step 2 Complexity Assessment)
- `.cursor/skills/plan/steps/06_work-item-epics.md` (epic sizing)
- `.cursor/skills/decompose/SKILL.md` (Step 2 task complexity)
- `.cursor/skills/autodev/protocols/bootstrap-lessons.md` (Bootstrap B2 — Surface Recent Lessons)

Categories: estimation · architecture · testing · dependencies · tooling · process
- [2026-10-17] [testing] Hold every list that is split across jobs (gate groups, embedded targets, Swift steps) to exactly one place with a guard that derives the set from the files (`publish-gate-*`, `embedded-*`, the `source` lines) and a mutant per rule: it survived two regroupings with only list edits, where a guard that names jobs by hand breaks at each one.
  Source: _docs/06_metrics/retro_2026-10-17_loop31.md
- [2026-10-17] [testing] A fake toolchain cannot prove a command that moved to a new place: the Swift speed part's `swift test list -c release --skip-build` ran only against a fake `swift` until one real container run (accepted, SpeedTests listed); run each new real command path once before the push, and expect timing bounds to miss on a loaded Mac (read the failed bound, then the serial retry).
  Source: _docs/06_metrics/retro_2026-10-17_loop31.md
- [2026-10-17] [estimation] Profile the functions of a gate group on the Mac before cutting it: the group notice is too coarse, and the cut the owner suggested (success against failure scenarios) was 73 s against 213 s while the cut by the profile was 143 against 143 s (CI 105 and 108 s); one scratch run with a `prof` wrapper per function takes about 5 minutes.
  Source: _docs/06_metrics/retro_2026-10-17_loop32.md
- [2026-10-17] [testing] Run the commands of the cheap CI jobs locally before the first push of a CI change and compare lists as sets: the `scaffold` script `report-row.test.sh` checked the suites matrix in a fixed order and would have turned the job red the moment the matrix was reordered longest first.
  Source: _docs/06_metrics/retro_2026-10-17_loop32.md
- [2026-10-17] [process] More jobs than the plan's concurrent slots (23 against 20) cost 30 to 63 s of waiting for three jobs on the first run, and the jobs that waited were not the last in the file; none set the wall because the cuts left every job under 250 s, but measure the start times (`created_at`, `started_at`) of the first run instead of trusting a file-order assumption.
  Source: _docs/06_metrics/retro_2026-10-17_loop32.md
- [2026-10-17] [estimation] Split a combined CI step's time per command before estimating a cut: the ring's "driver builds" step (76 to 101 s) hid an 84 s Swift driver build, and two image pulls at the same time took 73 and 68 s against 21 to 31 and about 42 to 52 s alone, so the 150 to 170 s estimate came out at 209 s.
  Source: _docs/06_metrics/retro_2026-10-17_loop33.md
- [2026-10-17] [testing] A bounded wait on whole seconds (`date +%s`) with `-lt` gives up up to 1 s early: compare with `-le`, assert at least the limit, and repeat a new timing test five times before the commit (one run in five showed it).
  Source: _docs/06_metrics/retro_2026-10-17_loop33.md
- [2026-10-17] [tooling] Docker Desktop on this Mac pulls even images it already has in minutes (156 and 422 s for gcc and swift, IPv6-first registry path) while the runners take 21 to 73 s: never estimate CI pull time from a Mac pull, read the job's step times.
  Source: _docs/06_metrics/retro_2026-10-17_loop33.md
- [2026-10-17] [testing] Before committing a change to a shape other scripts read (the `suites` matrix entries became "csharp rust"), `git grep` every reader of it and run them, not only the guards you edited: `report-row.test.sh` also parsed the matrix, and the step 11 scaffold stage caught it after the batch commit.
  Source: _docs/06_metrics/retro_2026-10-17_loop34.md
- [2026-10-17] [tooling] A cache spike must restore the way the real cache does: GNU tar's default format keeps file times to the second, so a plain `tar` round trip made SwiftPM rebuild all 372 BoringSSL C files and I designed ccache around it; `actions/cache` (posix format, nanosecond times) rebuilt none, ccache was asked 0 times on CI and was removed. Round-trip with `tar --posix` (or the real action) and check one CI run before adding a tool on a spike's word.
  Source: _docs/06_metrics/retro_2026-10-17_loop34.md
- [2026-10-17] [tooling] The unauthenticated GitHub API allows 60 calls an hour: a 30 s run watcher plus the notices of two runs used them up mid-run, and the failed polls read as "still running". Poll at 60 s with one call per tick, read jobs and annotations once at the end, and check `/rate_limit` when a poll fails; the public run page shows the run's result and total duration without the API.
  Source: _docs/06_metrics/retro_2026-10-17_loop34.md
- [2026-10-17] [tooling] An exact-key cache that saves only on a miss keeps whatever built its entries: after ccache was removed, the `v1` entries (built with `CC=ccache`) made every hit recompile all 372 BoringSSL files with plain clang (75 s instead of 17 s). Put the script that sets the build (`run-suite.sh`, `ring-swift.sh`) in the key, and bump the key whenever the build changes otherwise.
  Source: _docs/06_metrics/retro_2026-10-17_loop34.md
- [2026-10-19] [testing] When a review names a cross-package inconsistency in some packages, tabulate that rule (call x check x package) for all eight before the first fix: the dispatch check order took loops 39 and 40 because each review found more packages that differed (Java, C# and Python surfaced only in loop 40's survey).
  Source: _docs/06_metrics/retro_2026-10-19_loop41.md
- [2026-10-19] [testing] Give every suite timing bound a reference loop run in the same process (as Python AC-10 in `75b1d39`) instead of a fixed number of seconds: fixed bounds passed only on the serial retry in 6 suite runs of loops 38 to 40 and turned CI red twice when loop 38 added about 5 % to pack and unpack.
  Source: _docs/06_metrics/retro_2026-10-19_loop41.md
- [2026-10-19] [process] Put a carried owner-run skill (`/security`, `/feature-assess`, the retro) into the next intake's hopper question instead of the record's leftovers: AZ-2666 and the retro were carried in five records and the owner took them at once when loop 41 offered them.
  Source: _docs/06_metrics/retro_2026-10-19_loop41.md
