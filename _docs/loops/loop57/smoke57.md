# Loop 57 smoke — checks

LOCAL_URL: none (a library; the proof is the test stages and CI)
Branch: dev
Script: `smoke57.sh` in this folder (`bash _docs/loops/loop57/smoke57.sh`; Docker and `python3.14` are needed).

## Checks

- [x] 1. No application source is dirty
- [x] 2. The hostile case file still holds 75 cases and `check-cases.sh` / `cases.test.sh` pass
- [x] 3. The loop test stages whose files changed since step 11 pass (the others are skipped as unchanged)
- [x] 4. Mutant on a copy of `cpp/`: `keys_ascending` with the order reversed fails the host tests on `gcc:16`
- [x] 5. Embedded stage (logs of the step 11 run): Cortex-M4F flash at most 8,032 B (the pin) and stack at most 512 B, `CHAIN_FAILURES`, `FLAG_CHAIN_FAILURES` and `ROUND_CHAIN_FAILURES` 0, no `.failed` marker of the five arm targets

## Result

Agent run 2026-10-22 at `c4c5e23` (owner rule 2026-10-12 in `deployment_procedures.md`): **5/5 steps passed**, about 135 s (step 4: the mutant fails 16 lines; step 5: flash 8,032 B, margin 160 B, stack 504 B, margin 8 B). Step 11 at `7aa2d8a` (`scripts/loop-tests.sh`): 9 passed, 5 skipped as unchanged, 0 failed, 859 s (`_docs/03_implementation/test_run_loop57_report.md`).

## For the operator

- Jira: AZ-3151, AZ-3152, AZ-3153 and AZ-3154 go to In Testing (done); the epic AZ-2645 is open.
- You accepted `held_of` (one decision function) as the fold of AZ-3152 (assessment round 1, S4). Cortex-M4F flash margin is now 160 B (pinned at 8,032 B), stack margin still 8 B.
- Owner input still open: size limits for `text`, `ecc` and `session`; CS-D5; the first `v*` and `go/v*` tags; F44; close the epic AZ-2750; whether to close U24 in the C++ package.
