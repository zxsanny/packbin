# Lessons Log

A ring buffer of the last 15 actionable lessons extracted from retrospectives and incidents.
Downstream skills consume this file:
- `.cursor/skills/new-task/SKILL.md` (Step 2 Complexity Assessment)
- `.cursor/skills/plan/steps/06_work-item-epics.md` (epic sizing)
- `.cursor/skills/decompose/SKILL.md` (Step 2 task complexity)
- `.cursor/skills/autodev/protocols/bootstrap-lessons.md` (Bootstrap B2 — Surface Recent Lessons)

Categories: estimation · architecture · testing · dependencies · tooling · process
- [2026-10-14] [tooling] A watcher keyed on log growth reports STALLED for a stage that prints only at the end (the ring, the publish gate); add a second signal (the child process changes), and check `ps` for old shells when a task outlives the run: a worker's bare `cat` sat 70 minutes although its prompt forbade it.
  Source: _docs/06_metrics/retro_2026-10-14_loop25.md
- [2026-10-14] [tooling] Verify a container image tag against the registry before writing it into a pin, a compose file and a guard: `swift:6` was in all three and does not exist on Docker Hub (`manifest unknown`); only the pull in step 11 showed it. Use the full version (`swift:6.3.3`) and run `docker pull` once when the pin is chosen.
  Source: _docs/06_metrics/retro_2026-10-14_loop26.md
- [2026-10-14] [testing] A sanitizer run changes the cost of a test 10 to 40 times (the thread sanitizer in the Linux container: a max-slot test 1 178 s, 1 MiB unpack 15 to 28 s against 0.12 s in release): single-threaded size and speed tests skip under it and time bounds are asserted in the plain runs only; find the cost by one early container run, not at the end.
  Source: _docs/06_metrics/retro_2026-10-14_loop26.md
- [2026-10-14] [estimation] A new-language loop needs one early run of its suite in the CI container (after the core task), because the host and the container differ in ways that cost three step 11 invocations (about 90 minutes) here: Swift 6 rejects `stderr` on Linux, Foundation merges dictionary keys per process, the image tag.
  Source: _docs/06_metrics/retro_2026-10-14_loop26.md
- [2026-10-14] [process] A security audit that measures finds what review cannot: F47 (dictionary keys normalized in quadratic time, 25 s for 1 MiB) was invisible in the code and appeared only when the auditor built a probe; put "build one probe per hostile-input angle" in the audit brief, with a peak-RSS and a CPU figure.
  Source: _docs/06_metrics/retro_2026-10-14_loop26.md
- [2026-10-16] [tooling] Time a duplicate before arguing about it, and read a platform limit before relying on an output channel: per-call timing showed two groups running the same three real gate scenarios (six runs of 70 to 90 s for three scenarios), and the first CI annotation per timing line lost the last five groups because GitHub keeps 10 notices per step; one notice with all lines fixed it.
  Source: _docs/loops/loop29/notes29.md
- [2026-10-17] [process] Ship the per-job timing notices before the split and regroup from the numbers: batch 1 split by estimate and its first CI run moved the floor (the 360 s embedded job and a 215 s swift gate group), so a CI speed loop is two pushes and the owner should be asked for the second round up front.
  Source: _docs/06_metrics/retro_2026-10-17_loop31.md
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
