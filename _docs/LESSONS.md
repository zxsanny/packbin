# Lessons Log

A ring buffer of the last 15 actionable lessons extracted from retrospectives and incidents.
Downstream skills consume this file:
- `.cursor/skills/new-task/SKILL.md` (Step 2 Complexity Assessment)
- `.cursor/skills/plan/steps/06_work-item-epics.md` (epic sizing)
- `.cursor/skills/decompose/SKILL.md` (Step 2 task complexity)
- `.cursor/skills/autodev/protocols/bootstrap-lessons.md` (Bootstrap B2 — Surface Recent Lessons)

Categories: estimation · architecture · testing · dependencies · tooling · process

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
- [2026-10-23] [process] Open a flash-saving loop only with a named consumer for the bytes: loop 62 took 18 min for -224 B and loop 63 took 3 h 42 min for -84 B, with 468 B of flash margin and nothing in the hopper that needs it (loops 62 and 63).
  Source: _docs/06_metrics/retro_2026-10-23_loop64.md
- [2026-10-23] [tooling] Do not push a record-only commit after a loop close: `3619a2d` (docs only) started the whole `test.yml` on `dev` and `main` (554 s and 678 s); put the CI read into the next loop's first commit instead (loop 63).
  Source: _docs/06_metrics/retro_2026-10-23_loop64.md
- [2026-10-23] [process] Read the source of a handoff candidate before offering it as an option: "flag-byte chain inside a `times` round" was an unbuilt, unmeasured case, not a stack saving, and my option text said it was; the owner had to be asked again after the first measurement (612 B against a 512 B budget) (loop 65).
  Source: _docs/loops/loop65/record65.md
- [2026-10-24] [testing] Size a wall-clock window in a test from a probe of the same stub (3 s plus four times the slowest of three asks), not from a constant: a fixed 3 s window saw one proxy ask on a loaded host; a 5 s stub delay reproduces it in 137 s and a one-try copy of `proxy_check` proves the check still bites (loop 66).
  Source: _docs/loops/loop66/record66.md
- [2026-10-24] [process] A new `ph_*` function in `publish-phases*.test.sh` must be named in `ph_harness` of `publish-timing.selftest.sh` or the phase-split guard fails the whole share 7; only the full gate showed it (the groups run alone passed), so run `publish-timing.selftest.sh` before the first commit of a helper (loop 66).
  Source: _docs/loops/loop66/record66.md
