# Lessons Log

A ring buffer of the last 15 actionable lessons extracted from retrospectives and incidents.
Downstream skills consume this file:
- `.cursor/skills/new-task/SKILL.md` (Step 2 Complexity Assessment)
- `.cursor/skills/plan/steps/06_work-item-epics.md` (epic sizing)
- `.cursor/skills/decompose/SKILL.md` (Step 2 task complexity)
- `.cursor/skills/autodev/protocols/bootstrap-lessons.md` (Bootstrap B2 — Surface Recent Lessons)

Categories: estimation · architecture · testing · dependencies · tooling · process
- [2026-10-12] [architecture] A slot budget is a memory ceiling of maxSlots times the per-slot cost, and the cost differs by package (the same 4.3 MB packet: TypeScript 1 072 MB, Python 548 MB); removing Python's first-round surcharge raised its worst case from 90 MB to 548 MB. Change any charge only with a measured worst-case memory A/B in the same loop.
  Source: _docs/06_metrics/retro_2026-10-12_loop21.md
- [2026-10-12] [process] A parity decision must name the constructs it covers and both the with-value and no-value rows: U3 was built for repeat only and U7's no-value row (010000) stayed inconsistent with U6 until the reference worker flagged it.
  Source: _docs/06_metrics/retro_2026-10-12_loop21.md
- [2026-10-12] [testing] Fixtures first, then one loader worker per package: the loaders found two parity gaps (Rust late when in a bit body, C++ absent split body) that each package's own pins missed.
  Source: _docs/06_metrics/retro_2026-10-12_loop21.md
- [2026-10-12] [tooling] A stage timeout written as `perl alarm` counts wall time across laptop sleep and its alarm survives `exec` into `docker compose`, which ignores it: step 11 stage 1 died with rc 142 and the ESP stage ran hours over its limit; check `uptime` and `sysctl vm.swapusage` before a total run (a swapping host turned a 107 s ring into 11 296 s and flaked three timing tests).
  Source: _docs/06_metrics/retro_2026-10-12_loop22.md
- [2026-10-12] [architecture] A lowered limit lowers peak memory by less than its ratio: a quarter of the slots gave 29 to 33 % of the old peak because the runtime and the packet stay; state memory acceptance in absolute MB per package and give a test bound 50 % slack.
  Source: _docs/06_metrics/retro_2026-10-12_loop22.md
- [2026-10-12] [testing] A hostile construct case whose scheme another rule refuses first passes for the wrong reason: the empty-when cases were refused by the scope rule in five packages; check which rule fires per package when a case is added and pin it.
  Source: _docs/06_metrics/retro_2026-10-12_loop22.md
- [2026-10-12] [architecture] Validation state stored on a user's node leaks between schemes: Python kept `count_source` on the shared leaf and the last scheme won; copy the node at bind, as a `times` already was.
  Source: _docs/06_metrics/retro_2026-10-12_loop22.md
- [2026-10-12] [process] Probe the 'the other packages do X' premise of a parity spec before writing the AC: two of the loop 22 premises (U14, U15) were false or ambiguous and the reference probe section caught them.
  Source: _docs/06_metrics/retro_2026-10-12_loop22.md
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

