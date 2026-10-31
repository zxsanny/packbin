# Lessons Log

A ring buffer of the last 15 actionable lessons extracted from retrospectives and incidents.
Downstream skills consume this file:
- `.cursor/skills/new-task/SKILL.md` (Step 2 Complexity Assessment)
- `.cursor/skills/plan/steps/06_work-item-epics.md` (epic sizing)
- `.cursor/skills/decompose/SKILL.md` (Step 2 task complexity)
- `.cursor/skills/autodev/protocols/bootstrap-lessons.md` (Bootstrap B2 — Surface Recent Lessons)

Categories: estimation · architecture · testing · dependencies · tooling · process

- [2026-10-27] [process] A comparison harness with only good rows passes a package that accepts forgeries: add rows that must be refused and a stand-in reader that accepts them, and show once that a real defective driver turns the harness red (the TypeScript short-packet name did, loop 77); `vectors.txt` already held the refusals per package, which is why the ring keeps only tamper rows and leaves the refusal-by-name rows to a later loop.
  Source: _docs/loops/loop77/record77.md
- [2026-10-28] [process] A CI step added to `test.yml` also goes into `scripts/loop-tests.sh` in the same commit: step 11 of loop 77 passed 14 stages without running the frame ring or its self-test, because the `ring` and `scaffold` stages list their scripts by hand (found in loop 78 by comparing the two).
  Source: _docs/loops/loop78/record78.md
- [2026-10-28] [testing] A new check over real drivers is proven by putting an old defective driver back (`git show <commit>:<file>` in a scratch copy) and seeing it fail: the lenient TypeScript and Swift drivers gave 8 FAIL; 44 of 44 green on the first run proves nothing alone (loop 78).
  Source: _docs/loops/loop78/record78.md
- [2026-10-28] [process] Measure a new CI step cold with the runner's CPU count (`docker run --cpus 4`) and name the job it lands on before agreeing the command with the owner: `cargo test --no-run` for 7 Rust feature sets added 64 s to `suites (csharp rust)`, the job that sets the CI wall, and `cargo check --tests` 8 s (loop 79).
  Source: _docs/06_metrics/retro_2026-10-28_loop79.md
- [2026-10-28] [testing] An intake probe builds every configuration the ACs will name, not a sample: loop 79's probe built 2 of the 9 Rust feature sets and blamed the default set's warning on `from_hex`; the worker, building all 9, found `take` in `counters.rs` (loop 79).
  Source: _docs/06_metrics/retro_2026-10-28_loop79.md
- [2026-10-28] [estimation] A handoff line names one instance of a defect class, not the class: "a direction above 255 wraps in the C#, C++ and Go drivers" was one field; a probe ring with every number field at its edge also found the C++ tag length and kind and the Go epoch (loop 79).
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
