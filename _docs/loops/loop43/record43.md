# Autodev loop record — loop 43

loop: 43
branch: dev
plan_artifact: _docs/loops/loop43/plan43.md
tasks_shipped: [AZ-2723, AZ-2724]
decisions:
  - owner 2026-10-19 ("accept all recommended" after loop 42): the load-aware timing bounds (retro action 2, AZ-2723) plus F58 (Python session pad, AZ-2724); AZ-2068 stays out; `main` fast-forward at close
  - agent: each package has one test helper (Python `timing_support.py`, TypeScript `support/timing.ts`, C# `Timing.cs`, Java `Timing.java`, Rust `src/timing_support.rs`, Go `timing_test.go`, Swift `LoadFactor.swift`, C++ `load_factor.hpp`): bound = nominal x factor, factor = a reference CPU loop beside the check over its idle-host time, in [1, 8]; no production code. Python and TypeScript use the mean of 5 runs (best-of-3 read 1.0 while a 1 s check ran 1.5 to 3 times slow at load 100+), the others the smallest of 3 plus a re-measure over the section when a check fails (Rust, Go, Swift, C++). About 60 assertions converted; every package passes idle and under 12 busy processes (host load 20 to 210); a 10x slowdown of one timed operation still fails in each package that was tried
  - agent: F58: `_receive` removes the pad of the first byte, refuses an unknown type, and removes the rest only for a known one; the Python test counts `_block` calls
leftovers:
  - TypeScript hostile worker start-up stall (11.9 s against the 5 s hang guard) in the pool at load 11 to 25; passes alone; the guard is not a scaled bound
  - a check whose bound is 100 times its real cost (TypeScript EC-13 pack) or that is already a ratio (Python duplicate names, Swift pack_roundCost) is not changed; Python `test_ac8_100000_round_trips...40_seconds` (40 s nominal) is not converted
  - cap 8: above a real load of 8 times (load 130 to 200 on this host) a check can still fail
  - AZ-2068 in todo/; `/feature-assess`, `/security`, the retrospective, F44 and the first v*/go/v* tags are owner-run
smoke: PASS (agent run 7/7 at 5bee6cf, owner rule 2026-10-12)
smoke_artifact: _docs/loops/loop43/smoke43.md
step11: RESULT 11 passed (typescript on the serial retry), 2 skipped as unchanged, 0 failed, 961 s at 5bee6cf
loop_end_merge: main
