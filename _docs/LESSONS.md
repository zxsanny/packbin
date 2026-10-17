# Lessons Log

A ring buffer of the last 15 actionable lessons extracted from retrospectives and incidents.
Downstream skills consume this file:
- `.cursor/skills/new-task/SKILL.md` (Step 2 Complexity Assessment)
- `.cursor/skills/plan/steps/06_work-item-epics.md` (epic sizing)
- `.cursor/skills/decompose/SKILL.md` (Step 2 task complexity)
- `.cursor/skills/autodev/protocols/bootstrap-lessons.md` (Bootstrap B2 — Surface Recent Lessons)

Categories: estimation · architecture · testing · dependencies · tooling · process
- [2026-10-13] [architecture] A container sized by a count taken from the scheme (declared members) instead of the bytes read multiplies a small packet by the scheme width: Go's list of `Nested` rows peaked at 1.16 GB for a 64 KB packet with 256 members (F41). Size from bytes already read, and measure peak allocation for every collection of rows in the review, not by estimate.
  Source: _docs/06_metrics/retro_2026-10-13_loop24.md
- [2026-10-13] [testing] A timing bound belongs to the build it describes: the 1 s AC-10 loop was asserted under the race detector (about 5x slower) and failed at load 80 and 87; assert it in a second run without `-race` and let the race run check races only.
  Source: _docs/06_metrics/retro_2026-10-13_loop24.md
- [2026-10-13] [tooling] A docker image cache is not durable between loops (the embedded image was gone after a Docker restart: 260 s instead of 8 s), and a retry window counted in whole bash `SECONDS` needs at least 3 s to guarantee two tries (a 1 s window flaked 2 of 8 runs); budget a cold build and do not read a quiet log as a hang.
  Source: _docs/06_metrics/retro_2026-10-13_loop24.md
- [2026-10-14] [process] A ticket key comes from the tracker, never from counting: the first three commits and eight specs of loop 25 named AZ-2452 to AZ-2459, existing Jira issues of other work in the shared project; New Task step 7 creates the tickets before any spec or commit uses a key.
  Source: _docs/06_metrics/retro_2026-10-14_loop25.md
- [2026-10-14] [testing] A refusal test passes for the wrong reason unless its input falls into a state that is otherwise valid (3 of 4 C++ count cases and the `when` anchor passed without the fix); make the mutation proof part of the worker's acceptance: revert the fix in a scratch copy, every case must go red.
  Source: _docs/06_metrics/retro_2026-10-14_loop25.md
- [2026-10-14] [tooling] A launcher that starts a toolchain per call costs minutes when a harness calls it hundreds of times (the ring: 239 s, about 150 s of it `dotnet run` 40 times and a C++ recompile 32 times; 43 s when built once into a private per-run directory); multiply the launch cost by the call count before accepting a harness time.
  Source: _docs/06_metrics/retro_2026-10-14_loop25.md
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
