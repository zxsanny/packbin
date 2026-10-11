# Lessons Log

A ring buffer of the last 15 actionable lessons extracted from retrospectives and incidents.
Downstream skills consume this file:
- `.cursor/skills/new-task/SKILL.md` (Step 2 Complexity Assessment)
- `.cursor/skills/plan/steps/06_work-item-epics.md` (epic sizing)
- `.cursor/skills/decompose/SKILL.md` (Step 2 task complexity)
- `.cursor/skills/autodev/protocols/bootstrap-lessons.md` (Bootstrap B2 — Surface Recent Lessons)

Categories: estimation · architecture · testing · dependencies · tooling · process

- [2026-10-06] [testing] Under `set -o pipefail`, `cmd | grep -q .` reads an early grep exit as a failure (SIGPIPE) or a network error as an empty answer; capture the output first. The worker's tests passed and only the high-effort review found it.
  Source: _docs/06_metrics/retro_2026-10-06_loop14.md
- [2026-10-06] [dependencies] Pin or hash-check every tool the credentialed publish job installs (pip tools, `npm@11`, `NuGet/login`), and let the build step see no write access to the scripts the host runs next with the tokens.
  Source: _docs/06_metrics/retro_2026-10-06_loop14.md
- [2026-10-06] [process] Prototype a design against each package's existing suite while writing the spec: the first draft of the eager `times` check broke three existing assertions, and the spec pass found it at the cost of one resumed writer instead of an implementation round.
  Source: _docs/06_metrics/retro_2026-10-06_loop15.md
- [2026-10-06] [testing] Before writing "bounded" in the README, grep every counted field type: after the round limits the audit still found `bits` and `packed` at 36 to 257 times the packet, so the claim "memory is bounded by the round limits, not by the packet" had to be narrowed.
  Source: _docs/06_metrics/retro_2026-10-06_loop15.md
- [2026-10-06] [process] A fix for something only the Linux runner shows (root-owned files, mount modes, Compose version) cannot be proven on Docker Desktop: list its Linux-only parts in the batch report, push `dev` and watch the first CI run before any tag, as loop 14's `chmod` failure showed.
  Source: _docs/06_metrics/retro_2026-10-06_loop15.md
- [2026-10-06] [process] Run the workers' own suites per batch, then ONE total review and ONE total test run for the loop; per-batch reviewers, fix passes and Docker overlay runs were most of loop 16's wall time, and every assessment round added specs until the owner stopped it.
  Source: _docs/06_metrics/retro_2026-10-06_loop16.md
- [2026-10-06] [estimation] Before asking the owner an all-packages question, check in each package that the rule is decidable and run a differential for who breaks: Java has no field names (only `Access.set(String)` can be named) and the claim "no break for schemes that unpack today" for Python element accessors was false (pack-only callers break).
  Source: _docs/06_metrics/retro_2026-10-06_loop16.md
- [2026-10-06] [testing] For every pack-side rule add an unpack-random-bytes then repack differential against the HEAD export: the Rust round-name regression (`0101000007` repacked to `Missing`) was invisible to forward tests and found only by repacking unpacked packets.
  Source: _docs/06_metrics/retro_2026-10-06_loop16.md
- [2026-10-06] [tooling] A subagent shell command must end on its own (stdin from `/dev/null`, a `timeout`, no leftover background processes): a bare `cat > /dev/null` sat 2.5 hours and showed as a running task; put the shell-hygiene paragraph in every worker and reviewer prompt.
  Source: _docs/06_metrics/retro_2026-10-06_loop16.md
- [2026-10-07] [testing] After rewriting a conversion path, probe it once with a hostile value outside the member's range (a u32 above `int.MaxValue` into a `List<int>`): a differential over 1.4 million random inputs ran only schemes whose member types matched their fields and missed the `OverflowException` that one 7-byte packet shows.
  Source: _docs/06_metrics/retro_2026-10-07_loop17.md
- [2026-10-07] [estimation] Before writing a speed-up into an acceptance criterion, measure the floor of the part the change keeps: the dictionary engine costs 130 ms cold of the 570 ms typed round trip, so AZ-2092's "3x" needed a second walker and the loop delivered 2.1x cold and 2.3x warm.
  Source: _docs/06_metrics/retro_2026-10-07_loop17.md
- [2026-10-07] [testing] Put a timing assertion in its own non-parallel xunit collection: the AC-10 test takes 340 to 390 ms alone and 790 ms to 1 s inside the full suite on a fast laptop and failed CI at 1 618 ms, so a local pass is not CI parity for a timing bound.
  Source: _docs/06_metrics/retro_2026-10-07_loop17.md
- [2026-10-11] [tooling] A green `make -C cpp test` on the Mac (Apple clang) does not prove the CI build (GCC 16, `-Wall -Wextra -Werror`): the loop 18 C++ tests failed the container on `-Warray-bounds` and `-Wformat-truncation`, so a C++ task ends with `docker run gcc:16 make test` and, for `cpp/src/core`, the arm embedded stage (a one-line inlining change moved the Cortex-M4F stack by 64 B against a 512 B budget).
  Source: _docs/06_metrics/retro_2026-10-11_loop18.md
- [2026-10-11] [testing] When one rule must give the same bytes in six packages, have one package implement it first and write a hex-pinned reference table (scheme, row, packet, unpacked row), then align the others in parallel against the table: five workers matched 60 cases in loop 18 with no divergent reading.
  Source: _docs/06_metrics/retro_2026-10-11_loop18.md
- [2026-10-11] [architecture] Bound a broadcast rule in the change that adds it: loop 18 made Rust send a lone scalar to every `times` round and the audit found `pack` loops for any count in five packages (4 GiB at a 4-billion count), so a new broadcast comes with the rounds cap on pack and a hostile `pack` case.
  Source: _docs/06_metrics/retro_2026-10-11_loop18.md
- [2026-10-11] [process] Check each AC of a cross-package spec against the reference rows it must keep before the specs are written: AZ-2331 AC-3 contradicted the loop 18 row `W-split-false-body-given`, six workers read it two ways, and it cost one owner question plus three follow-up workers. Put one cross-package table in front of the owner after the first wave
  Source: _docs/06_metrics/retro_2026-10-11_loop19.md
- [2026-10-11] [testing] Tell every reviewer to probe with a hostile value outside the type's range and with a row that packed before the change: the loop 19 review found Java `intValue()` ahead of the round cap, a C# count-0 regression and a C++ legitimate row now refused, all green in the package suites
  Source: _docs/06_metrics/retro_2026-10-11_loop19.md
- [2026-10-11] [architecture] A cap on one count does not bound the output: the audit measured 4.29 GB written for a 64 KB request through a lone `utf8` under one `times` (F28). Bound the bytes written per call, not only each count
  Source: _docs/06_metrics/retro_2026-10-11_loop19.md

