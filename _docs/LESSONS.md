# Lessons Log

A ring buffer of the last 15 actionable lessons extracted from retrospectives and incidents.
Downstream skills consume this file:
- `.cursor/skills/new-task/SKILL.md` (Step 2 Complexity Assessment)
- `.cursor/skills/plan/steps/06_work-item-epics.md` (epic sizing)
- `.cursor/skills/decompose/SKILL.md` (Step 2 task complexity)
- `.cursor/skills/autodev/protocols/bootstrap-lessons.md` (Bootstrap B2 — Surface Recent Lessons)

Categories: estimation · architecture · testing · dependencies · tooling · process

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
- [2026-10-20] [testing] Time a new speed case in every package before the criterion names one bound for all of them: the 1 s of 200 repeated 65,535-character texts held in Python, TypeScript, Go, Swift, Rust and C# but failed in Java (2.9 s) and C++ (1.9 s) in loop 46, costing a production change, an owner decision and AZ-2742.
  Source: _docs/06_metrics/retro_2026-10-20_loop46.md
- [2026-10-20] [testing] A load factor from a short reference loop under-reports a loaded pool (1.11 while the C++ case ran 2.1 times its idle time at load 45), so a pool-run bound below about 2.5 times the idle figure fails the first run and passes only on the serial retry.
  Source: _docs/06_metrics/retro_2026-10-20_loop46.md
- [2026-10-20] [process] When several tasks share package directories, spawn one worker per package with every task id for that package in its prompt: loop 46 ran 5 tasks over 8 packages and the CI scripts as 9 workers in two waves of four with no overlapping write and no merge repair.
  Source: _docs/06_metrics/retro_2026-10-20_loop46.md
- [2026-10-20] [estimation] Before sizing a "port package X's design" task, grep the target's public types for owned heap types and decide whether the requested property (no heap, no panic) is a switch or a second API: AZ-2749 was 5 points on the handoff and 34 after reading the Rust sources (a `HashMap<Rc<str>, Value>` API cannot be made `no_std` by a feature).
  Source: _docs/06_metrics/retro_2026-10-20_loop50.md
- [2026-10-20] [testing] Prove "no heap, no panic" on the linked image with a seeded defect that must fail the check: the lint deny list was clean while the image held three panic paths (`copy_from_slice`, `slice::reverse`, a range index).
  Source: _docs/06_metrics/retro_2026-10-20_loop50.md
- [2026-10-20] [tooling] Read a list that a loop feeds to docker, QEMU or cargo on a spare file descriptor (`read -u 3 ... 3< <(list)`), or the first child that reads stdin eats the remaining lines and later items are silently never run.
  Source: _docs/06_metrics/retro_2026-10-20_loop50.md
