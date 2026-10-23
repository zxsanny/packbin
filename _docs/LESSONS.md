# Lessons Log

A ring buffer of the last 15 actionable lessons extracted from retrospectives and incidents.
Downstream skills consume this file:
- `.cursor/skills/new-task/SKILL.md` (Step 2 Complexity Assessment)
- `.cursor/skills/plan/steps/06_work-item-epics.md` (epic sizing)
- `.cursor/skills/decompose/SKILL.md` (Step 2 task complexity)
- `.cursor/skills/autodev/protocols/bootstrap-lessons.md` (Bootstrap B2 — Surface Recent Lessons)

Categories: estimation · architecture · testing · dependencies · tooling · process

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
- [2026-10-22] [process] A test-only cleanup loop whose own review finds as many Lows as it fixed (4, 4, 4 in loops 58 to 60) is a treadmill: accept test-code Lows in the handoff and open a cleanup loop only for a Low that can hide a failure (loop 60).
  Source: _docs/06_metrics/retro_2026-10-22_loop60.md
- [2026-10-22] [testing] Compute the expected count of a corpus AC with the rule's own command and one real run, not `grep -c .` on the file (a comment line made it 34 where the rule says 33), and run the broken copies before the AC wording is final (loop 60).
  Source: _docs/06_metrics/retro_2026-10-22_loop60.md
- [2026-10-22] [process] With the Jira connector absent, write task specs as `AZ-PENDING_*` with one create-leftover holding the replay payload, and replay the In Testing leftovers first when the connector returns (loops 59 and 60).
  Source: _docs/06_metrics/retro_2026-10-22_loop60.md
- [2026-10-23] [tooling] Measure flash and stack candidates on tree copies in the scratchpad with a driver that sources `cpp/embedded/lib.sh` and `arm.sh` and calls `target_m4f` in `packbin-embedded:local` (about 5 s a shape against 3 minutes for the stage, and the repo stays at HEAD); run the real stage once on the kept shape (loop 63).
  Source: _docs/loops/loop63/record63.md
- [2026-10-23] [estimation] Copy stack and flash baselines into an AC from the latest stage log, not from the previous loop's table: AC-3 named the loop 61 pack figures (412 / 448 / 500 B) when HEAD measured 404 / 440 / 492 B after loop 62 (loop 63).
  Source: _docs/loops/loop63/record63.md
