# Lessons Log

A ring buffer of the last 15 actionable lessons extracted from retrospectives and incidents.
Downstream skills consume this file:
- `.cursor/skills/new-task/SKILL.md` (Step 2 Complexity Assessment)
- `.cursor/skills/plan/steps/06_work-item-epics.md` (epic sizing)
- `.cursor/skills/decompose/SKILL.md` (Step 2 task complexity)
- `.cursor/skills/autodev/protocols/bootstrap-lessons.md` (Bootstrap B2 — Surface Recent Lessons)

Categories: estimation · architecture · testing · dependencies · tooling · process

  Source: _docs/06_metrics/retro_2026-10-28_loop79.md
  Source: _docs/06_metrics/retro_2026-10-28_loop79.md
  Source: _docs/06_metrics/retro_2026-10-28_loop79.md
- [2026-10-30] [estimation] A zero-margin byte pin makes a no-behaviour file split an owner decision: a second translation unit cost 32 B on the Cortex-M4F image and 40 B on the Cortex-M33F one (shared literal pool, alignment), so run the arm stage at intake when a task touches a pinned image (loop 84).
  Source: _docs/06_metrics/retro_2026-10-30_loop84.md
- [2026-10-30] [tooling] A worker told to build the project's own embedded image (`cpp/embedded/Dockerfile`, about 3.5 min) found the M33F pin failure that no host build shows; "NOT RUN, no toolchain" is the wrong stop when the stage has a documented image (loop 84).
  Source: _docs/06_metrics/retro_2026-10-30_loop84.md
- [2026-10-30] [process] A review cleanup in a handoff is a lead, not a defect: two of four from loop 83 did not exist on HEAD (`kMax` is read by two parts, `frame_hex` differs on purpose) and the include prune removed nothing, so probe each before it gets a spec line (loop 84).
  Source: _docs/06_metrics/retro_2026-10-30_loop84.md
- [2026-10-30] [process] A candidate the owner declined can come back: loop 89 took the CI clippy job declined in loops 86 and 87, so the handoff keeps the decline and the numbers measured then (0 warnings, 9 sets) instead of dropping the candidate.
  Source: _docs/06_metrics/retro_2026-10-30_loop89.md
- [2026-10-30] [tooling] A gate step added to `run-suite.sh` moves pinned counts in `run-suite.test.sh` (the expected-call block, the step count in the notice row 21 to 22) and needs a fake of its tool (`rustup`): grep `-eq N` and the call lists before the first test run (loop 89).
  Source: _docs/06_metrics/retro_2026-10-30_loop89.md
- [2026-10-30] [testing] Prove a failing gate on the real path with one injected defect, reverted at once (a lint in `rust/src/lib.rs` ran through the `rust` compose service: exit 1, set named), besides the stubbed shell case (loop 89).
  Source: _docs/06_metrics/retro_2026-10-30_loop89.md
- [2026-10-31] [tooling] simavr 1.6 prints nothing for its console register and its `avr_mcu_section.h` does not compile as C++: report over the UART (`UDR0`), strip the colour codes, and treat each line end shown as a dot (loop 92).
  Source: _docs/06_metrics/retro_2026-10-31_loop92.md
- [2026-10-31] [testing] An emulator gate that diffs the whole report against an expected file fails on a changed line, a missing line and no output alike; prove it with five injected runs (changed byte, defect, hang, tool missing, silent fake tool), each reverted (loop 92).
  Source: _docs/06_metrics/retro_2026-10-31_loop92.md
- [2026-10-31] [estimation] Name the reach limit of a runtime check in the spec first: the 16-bit `size_t` wrap needs a buffer near 64 KiB and an ATmega328P has 2 KB of RAM, so the run checks the arithmetic, not the wrap (loop 92).
  Source: _docs/06_metrics/retro_2026-10-31_loop92.md
- [2026-11-01] [process] State the rule for the off or zero value of a new setting in the spec and in every worker prompt: four workers read "percentage 0" four ways, and the unprotected path had no 254-byte limit that the first criteria assumed (loop 97).
  Source: _docs/06_metrics/retro_2026-11-01_loop97.md
- [2026-11-01] [testing] A new row word in a shared fixture gets its own file when other loaders read the old file by position: grep every reader first, or the first commit breaks eight suites (loop 97).
  Source: _docs/06_metrics/retro_2026-11-01_loop97.md
- [2026-11-01] [estimation] Count the lines of every touched file at the batch gate: adding 160 lines to a 437-line header crossed the 500-line cap and cost a split task; and read `git log -1` after each commit command, a failed `git add` left a no-op commit while Jira had moved (loop 97).
  Source: _docs/06_metrics/retro_2026-11-01_loop97.md
- [2026-11-11] [testing] A builder that keys maps by node identity must be tested with one field object used in two places (a shared member list): 1,887 tests missed it and a random differential run against TypeScript found a High; give every new language one reviewer slice of random schemes against the reference (loop 99).
  Source: _docs/06_metrics/retro_2026-11-11_loop99.md
- [2026-11-11] [testing] Never assert elapsed time in a unit test that the loop runs under load (624 ms against 500 ms at host load 30): count the operation instead (keyed reads on the map), and keep time bounds for the compiled speed program (loop 99).
  Source: _docs/06_metrics/retro_2026-11-11_loop99.md
- [2026-11-11] [process] Mint a short-lived credential in the step that uses it and compare its lifetime with the run order (an OIDC token minted before a build and a Maven wait expires before the upload); a Docker `network is unreachable` is an environment fault: restart Docker Desktop (restart policy was no on all 18 containers: start them again) and rerun only the failed stages (loop 99).
  Source: _docs/06_metrics/retro_2026-11-11_loop99.md
