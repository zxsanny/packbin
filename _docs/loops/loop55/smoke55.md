# Loop 55 smoke — checks

LOCAL_URL: none (a library; the proof is the test stages and CI)
Branch: dev
Script: `smoke55.sh` in this folder (`bash _docs/loops/loop55/smoke55.sh`; Docker, `dotnet` and `python3.14` are needed).

## Checks

- [x] 1. No application source is dirty
- [x] 2. The hostile case file holds 75 cases (three new bool-source `pack` cases) and `check-cases.sh` / `cases.test.sh` pass
- [x] 3. The loop test stages whose files changed since step 11 pass (3 passed, 11 skipped as unchanged: only a comment in `unpack.cpp` and docs changed after step 11)
- [x] 4. Mutant on a copy of `cpp/`: a `when` that ignores a skipped source fails `pack_when_of_skipped_bool_source` among 12 failing checks
- [x] 5. Embedded stage (logs of the step 11 run; step 3 skipped the stage as unchanged): Cortex-M4F flash 8,120 B of 8,192 (margin 72 B), stack 504 B of 512 (margin 8 B), `CHAIN_FAILURES 0`, `FLAG_CHAIN_FAILURES 0`, no `.failed` marker of the five arm targets

## Result

Agent run 2026-10-21 at `bf7e674` (owner rule 2026-10-12 in `deployment_procedures.md`): **5/5 steps passed**, about 260 s. Step 11 at `daa302d` (`scripts/loop-tests.sh`): 14 passed, 0 skipped as unchanged, 0 failed, 1049 s (`_docs/03_implementation/test_run_loop55_report.md`).

## For the operator

- Jira: AZ-3132, AZ-3133, AZ-3134 and AZ-3141 are In Testing; the epic AZ-2645 is open.
- The Cortex-M4F flash margin is 72 B and the stack margin 8 B: the next edit of `cpp/src/core` needs a flash saving first.
- Owner input still open (from loop 53/54): size limits for `text`, `ecc` and `session`; CS-D5; the first `v*` and `go/v*` tags; F44; close the epic AZ-2750; whether to close U24 in the C++ package.
