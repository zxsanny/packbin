# Lessons Log

A ring buffer of the last 15 actionable lessons extracted from retrospectives and incidents.
Downstream skills consume this file:
- `.cursor/skills/new-task/SKILL.md` (Step 2 Complexity Assessment)
- `.cursor/skills/plan/steps/06_work-item-epics.md` (epic sizing)
- `.cursor/skills/decompose/SKILL.md` (Step 2 task complexity)
- `.cursor/skills/autodev/protocols/bootstrap-lessons.md` (Bootstrap B2 — Surface Recent Lessons)

Categories: estimation · architecture · testing · dependencies · tooling · process
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
- [2026-10-25] [architecture] On Cortex-M a `Result` returned through a hidden pointer puts a 16 B temporary and an on-stack fifth argument in every walk frame: folding a 32 B save frame into the walker (copy for a `when` only, `keep` pointer for the restore) cut a flag-scope level from 80 B to 56 B and the 0x5e image from 612 B to 540 B, and the same fold written as a `bool` argument saved only 48 B; measure shapes on a tree copy with the M4F target alone (3 s a run) before the full stage (loop 67).
  Source: _docs/loops/loop67/record67.md
- [2026-10-25] [tooling] An array copied under `if (x)` and read under `if (x)` fails the `gcc:16` host build (`-Werror=maybe-uninitialized`, -O1 to -O3) while Apple clang and arm `-Os` pass: check a new walker shape with `docker run gcc:16 g++ -O2 -Wall -Wextra -Werror -c` on the one file at the four levels before the first commit; a pointer that is null when nothing was saved compiles clean (loop 67).
  Source: _docs/loops/loop67/record67.md
- [2026-10-25] [estimation] Check a byte or stack budget against a named part before shaving bytes: loops 61 to 67 cut flash and stack of the C++ core against 8 KB and 2 KB figures that came from an early criterion, and the owner's answer in loop 68 (the nRF54L15: 256 KB of RAM, about 1.5 MB of NVM) made them 30 and 100 times too small; ask for the target part at the first size loop (loop 68).
  Source: _docs/06_metrics/retro_2026-10-25_loop68.md
- [2026-10-25] [tooling] A wall-clock heartbeat cannot tell a laptop sleep or a DST clock change from a stall: the publish gate reported 24,249 s while every share log ended `publish gate tests passed`; read the share's own end line and the container process ages before killing a long run (loop 68).
  Source: _docs/06_metrics/retro_2026-10-25_loop68.md
- [2026-10-25] [testing] Run the CI step list itself (`docker compose -f docker-compose.test.yml run --rm rust`) before committing a change to a public Rust type: a hand-picked test matrix missed the exhaustive `match` on `Error` in the nostd test support, and step 11 found it (loop 69).
  Source: _docs/06_metrics/retro_2026-10-25_loop69.md
- [2026-10-25] [architecture] A 600-byte value returned by value from a constructor cost 2.4 to 2.9 KB of device stack (probe 2,968 B against a 2,048 B bound) however the code was arranged; an in-place constructor (`frame_unloaded`, `load_frame_in_place`) gave 1,896 B, so measure the stack on the first build of a large type and design the constructor in place (loop 69).
  Source: _docs/06_metrics/retro_2026-10-25_loop69.md
- [2026-10-25] [architecture] Review a new security API for caller misuse before writing its tests: the independent review found that the replay counter is an open argument that the tag does not cover (one captured frame could poison a window), a rule the contract now states; the crypto core had no finding (loop 69).
  Source: _docs/06_metrics/retro_2026-10-25_loop69.md
- [2026-10-26] [architecture] Before offering the owner "leave X, it only holds derived data" for a crypto temporary, check whether X can be inverted back to its input: the SHA-256 schedule window left on the stack gives back the whole block (the key XOR a pad at key load), and the owner's first answer rested on that wrong premise (loop 73).
  Source: _docs/06_metrics/retro_2026-10-26_loop73.md
- [2026-10-26] [architecture] When a secret lives in an `Option`, wipe it in place and then set `None`; `take()` moves the value out and can leave its bytes in the slot (both Rust session `open`s did, loop 73).
  Source: _docs/06_metrics/retro_2026-10-26_loop73.md
- [2026-10-26] [estimation] A byte-budget change across feature sets can trade one set against another: the wipe helper out of line cost `session` +16 B and `frame` +152 B, forced inline +128 B and +96 B; compare each form per set and in total against the tightest bound before choosing (loop 73).
  Source: _docs/06_metrics/retro_2026-10-26_loop73.md
