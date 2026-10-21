# Loop 56 smoke — checks

LOCAL_URL: none (a library; the proof is the test stages and CI)
Branch: dev
Script: `smoke56.sh` in this folder (`bash _docs/loops/loop56/smoke56.sh`; Docker, `python3.14` are needed).

## Checks

- [x] 1. No application source is dirty
- [x] 2. The hostile case file still holds 75 cases and `check-cases.sh` / `cases.test.sh` pass
- [x] 3. The loop test stages whose files changed since step 11 pass (the others are skipped as unchanged)
- [x] 4. Mutant on a copy of `cpp/`: a resolver that never sets `flag::HoldsFlagByte` fails the AZ-3143 host test (`when_flag_bit_host_tests.cpp`)
- [x] 5. Embedded stage (logs of the step 11 run): Cortex-M4F flash at most 8,120 B and stack at most 512 B, `CHAIN_FAILURES`, `FLAG_CHAIN_FAILURES` and `ROUND_CHAIN_FAILURES` 0, no `.failed` marker of the five arm targets

## Result

Agent run 2026-10-21 at `22d92b6` (owner rule 2026-10-12 in `deployment_procedures.md`): **5/5 steps passed**, about 130 s (step 4: the mutant fails 7 checks, among them `AZ-3143 AC-2`). Step 11 at `1de928c` (`scripts/loop-tests.sh`): 8 passed, 6 skipped as unchanged, 0 failed, 540 s (`_docs/03_implementation/test_run_loop56_report.md`).

## For the operator

- Jira: AZ-3143, AZ-3144 and AZ-3145 go to In Testing; the epic AZ-2645 is open.
- AZ-3143 AC-1 is missed (8,080 B, target 8,040 B) and the fold of AZ-3144 was not kept; you accepted both (assessment round 1). Cortex-M4F flash margin is now 112 B, stack margin 8 B.
- Owner input still open: size limits for `text`, `ecc` and `session`; CS-D5; the first `v*` and `go/v*` tags; F44; close the epic AZ-2750; whether to close U24 in the C++ package.
