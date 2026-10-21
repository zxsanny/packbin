# Lessons Log

A ring buffer of the last 15 actionable lessons extracted from retrospectives and incidents.
Downstream skills consume this file:
- `.cursor/skills/new-task/SKILL.md` (Step 2 Complexity Assessment)
- `.cursor/skills/plan/steps/06_work-item-epics.md` (epic sizing)
- `.cursor/skills/decompose/SKILL.md` (Step 2 task complexity)
- `.cursor/skills/autodev/protocols/bootstrap-lessons.md` (Bootstrap B2 — Surface Recent Lessons)

Categories: estimation · architecture · testing · dependencies · tooling · process

- [2026-10-20] [estimation] Before sizing a "port package X's design" task, grep the target's public types for owned heap types and decide whether the requested property (no heap, no panic) is a switch or a second API: AZ-2749 was 5 points on the handoff and 34 after reading the Rust sources (a `HashMap<Rc<str>, Value>` API cannot be made `no_std` by a feature).
  Source: _docs/06_metrics/retro_2026-10-20_loop50.md
- [2026-10-20] [testing] Prove "no heap, no panic" on the linked image with a seeded defect that must fail the check: the lint deny list was clean while the image held three panic paths (`copy_from_slice`, `slice::reverse`, a range index).
  Source: _docs/06_metrics/retro_2026-10-20_loop50.md
- [2026-10-20] [tooling] Read a list that a loop feeds to docker, QEMU or cargo on a spare file descriptor (`read -u 3 ... 3< <(list)`), or the first child that reads stdin eats the remaining lines and later items are silently never run.
  Source: _docs/06_metrics/retro_2026-10-20_loop50.md
- [2026-10-20] [architecture] In a heap-free port, link the device image after the first nested kind and read flash and stack before writing the next one: on-the-fly reference lookups took the Rust image from 2.6 KB to 11 KB against an 8 KB limit, seen only at the end of the slice (loop 51).
  Source: _docs/06_metrics/retro_2026-10-20_loop51.md
- [2026-10-20] [testing] Place every container kind under every presence context (`flags` member, flag bit, `when` body) in a differential layout list: a `repeat`-in-`flags` divergence passed 27 layouts and 80,000 random rows and was found by the review (loop 51).
  Source: _docs/06_metrics/retro_2026-10-20_loop51.md
- [2026-10-20] [estimation] Before sizing a slice of a port, check that each kind in it can be decided with the code already there: dictionaries sat in the lists slice, but key order is compared on decoded text, which only the text slice brings (loop 51).
  Source: _docs/06_metrics/retro_2026-10-20_loop51.md
- [2026-10-20] [tooling] A clippy-clean `no_std` module can still link a panic path: `slice::split_at_mut` (and `rotate_left`, `copy_within`) panic out of line, found only by the link check on the device image; use `get_mut` ranges and run the embedded stage after the first new kind of code, not at the end (loop 52).
  Source: _docs/06_metrics/retro_2026-10-20_loop52.md
- [2026-10-20] [testing] Pair every "refused when the feature is off" test with the same scheme accepted when it is on: a wrong table size (`list(0, 2)` for a one-entry element) made the refusal test pass for the wrong reason, and a wire-string test with the same mistake failed (loop 52).
  Source: _docs/06_metrics/retro_2026-10-20_loop52.md
- [2026-10-20] [process] Under host load above 25 the publish gate fails on environment flakes (NuGet "resource temporarily unavailable", a timing self-test pipe, a SwiftPM cache path); read the failing share's log before assuming a regression, re-run the stage alone, and run it when the load is below 15 (loop 52: three runs, green on the third).
  Source: _docs/06_metrics/retro_2026-10-20_loop52.md
- [2026-10-21] [testing] Replay the whole shared hostile corpus on every new port, including the cases the reference port skips: the core passed every differential test of loops 50 to 52 and still packed an unwritten count as absent; only the case file and its skipped neighbours showed it (loop 53).
  Source: _docs/06_metrics/retro_2026-10-21_loop53.md
- [2026-10-21] [performance] Measure the case an acceptance bound names (TW-5: 200 rounds of 65,535 characters) before closing a codec slice; a port that drops the original's memo is 600 times slower (5.96 s against 10 ms) and every functional test still passes (loop 53).
  Source: _docs/06_metrics/retro_2026-10-21_loop53.md
- [2026-10-21] [tooling] Slice iterators (`chunks_mut`, `chunks_exact`) link a division and a panic at opt-level z that clippy and the host build do not show; read bytes by index with `get` in code the device image links, and run the embedded stage after the first use (loop 53).
  Source: _docs/06_metrics/retro_2026-10-21_loop53.md
- [2026-10-21] [performance] Measure the stack of a recursive walker on the device image with the deepest shape the AC allows before trusting the handoff's suspect: the 3-deep `when` chain was 780 B and the flag-byte chain 668 B against 512 B, and the cost was the tree walk (130 to 144 B per nested level), not the `when_matches` recursion the review had named (loop 55).
  Source: _docs/06_metrics/retro_2026-10-21_loop55.md
- [2026-10-21] [process] When a fix leaves a carve-out path (a held `when` that reads a flag byte still recursed), write it in the batch report's discoveries table: the assessment turned that one row into AZ-3141 and found the second over-budget shape (loop 55).
  Source: _docs/06_metrics/retro_2026-10-21_loop55.md
- [2026-10-21] [tooling] Check `xcode-select -p` before applying a host recipe from AGENT_GOTCHAS: with Xcode.app selected (Swift 6.4) the Command Line Tools flags for swift-testing break the build, and a plain `swift test` works (loop 55).
  Source: _docs/06_metrics/retro_2026-10-21_loop55.md
