# Autodev loop record — loop 41

loop: 41
branch: dev
plan_artifact: _docs/loops/loop41/plan41.md
tasks_shipped: [AZ-2666]
decisions:
  - owner 2026-10-19 (intake): loop 41 runs the AZ-2666 security audit, widened to the message ECC unpack path (AC-2), plus the retrospective of loops 35 to 40; the load-aware timing bounds and AZ-2068 stay in the hopper
  - owner 2026-10-19 (after the audit): F51 (C++ dict keys, quadratic in the entries, needs a caller capacity of about 16,384 or more to pass 1 s) is Medium like F47, documented now; strictly ascending dict keys in all eight packages is the next loop (AZ-2713, in todo/), with the Lows F57 to F60 and the F19 instances as candidates
  - agent: four read-only audit arms (two packages each) on `git archive` copies; the probes of all eight are kept in `fixtures/hostile/fuzz/<language>/` (AGENT_GOTCHAS line 1), every file under 500 lines
  - agent: fixed in the loop with a test that fails on HEAD: F52 (Rust `UnpackError::BadParity` for a handler above 32 parity bytes, was a panic, Medium), F53 (C# session without parity above 254 bytes), F54 (Python raw text length before the copy); F55 (the contract's ECC work bound, about 3 x 255 x 32) in the contract, README, component docs and a C# comment
  - agent: the retrospective (`retro_2026-10-19_loop41.md`) covers loops 35 to 40 from the loop records, as those loops wrote no batch reports; three lessons added, one repeat promoted to AGENT_GOTCHAS (run every reader of a changed shape)
leftovers:
  - AZ-2713 (todo/, unclaimed): strictly ascending dict keys in all eight (F51, F56); candidates F57 (C++ session spends a position on an invalid scheme), F58 (Python session pad cost), F59 (C# and Go repair allocations), F60 (Rust decoded-string capacity), F19 instances (Python and TypeScript session payload types)
  - the timing checks that fail under parallel load (Go text times, Rust debug NFR, Python EC-13, TypeScript round-scope-cost, Java AC-8): a load-aware bound like `75b1d39` (retro action 2)
  - not run: the audit on Linux and x64 (except Go in its container), GCC, .NET Framework and Mono, the C++ NO_TEXT and NO_ECC builds, coverage-guided fuzzing
  - from earlier loops: F44 and the first v*/go/v* tags (owner only); D5 real messages; AZ-2068 in todo/
smoke: PASS (agent run 10/10 at b5d2ad8, owner rule 2026-10-12)
smoke_artifact: _docs/loops/loop41/smoke41.md
assessment_artifact: _docs/loops/loop41/assessment41.md
step11: RESULT 12 passed, 1 skipped as unchanged, 0 failed, 975 s at a9f4540 (no serial retries); python re-run at b5d2ad8 passed (124 s)
loop_end_merge: main
