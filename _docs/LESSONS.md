# Lessons Log

A ring buffer of the last 15 actionable lessons extracted from retrospectives and incidents.
Downstream skills consume this file:
- `.cursor/skills/new-task/SKILL.md` (Step 2 Complexity Assessment)
- `.cursor/skills/plan/steps/06_work-item-epics.md` (epic sizing)
- `.cursor/skills/decompose/SKILL.md` (Step 2 task complexity)
- `.cursor/skills/autodev/protocols/bootstrap-lessons.md` (Bootstrap B2 — Surface Recent Lessons)

Categories: estimation · architecture · testing · dependencies · tooling · process

- [2026-10-05] [testing] Run a hostile-input fix's new test against the pre-fix tree and require it to fail; the spec's literal packets (`01ffffffff`) passed on the old code in several packages, and only a longer amplifier packet or an exact-shape assert (`needed`, `left`, kind) discriminated.
  Source: _docs/06_metrics/retro_2026-10-05_loop11.md
- [2026-10-05] [tooling] CI has no typecheck job, so tests and Docker CI pass a TypeScript type error; run `tsc --noEmit --strict` over `typescript/src` before each TypeScript commit until a CI job exists (a reviewer FAIL caught four TS2345 call sites in loop 11).
  Source: _docs/06_metrics/retro_2026-10-05_loop11.md
- [2026-10-05] [testing] Keep the auditor's cross-package fuzz generators and drivers in the repo and run them whenever unpack changes; the scratch differential over 276 855 packets per package found three Medium defects (u64 top-range exception, `__proto__` dict key, `when` in `repeat`) that eight reviewer reports missed.
  Source: _docs/06_metrics/retro_2026-10-05_loop11.md
- [2026-10-06] [estimation] Give every task that changes the shape an unpack returns an amplification check (a 1 MiB packet of one-byte rounds with 1 and 36 names, peak memory and time): padding each name per round took TypeScript from 130 to 401 MB, C# from 93 to 525 MB and Rust from 36 to 311 MB.
  Source: _docs/06_metrics/retro_2026-10-06_loop13.md
- [2026-10-06] [testing] Re-derive every hex string and example row in a spec by hand or from a reference build before the batch starts; AZ-2087 AC-4, AZ-2177 AC-2 and two AZ-2178 hex strings were wrong, and only fresh-reviewer oracles caught them.
  Source: _docs/06_metrics/retro_2026-10-06_loop13.md
- [2026-10-06] [estimation] Size a CI or publish restructure by the scripts and tests it touches, not by its AC count: AZ-2096 was 3 points and became 15 files and +1 313 lines (two new scripts, a checker and a test harness).
  Source: _docs/06_metrics/retro_2026-10-06_loop14.md
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
