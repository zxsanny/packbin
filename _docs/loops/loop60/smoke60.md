# Loop 60 smoke — checks

LOCAL_URL: none (a library; the proof is the test stages and CI)
Branch: dev
Script: `smoke60.sh` in this folder (`bash _docs/loops/loop60/smoke60.sh`; Docker, `cargo` and `python3` are needed).

## Checks

- [x] 1. No application source is dirty
- [x] 2. The hostile case file still holds 75 cases and `check-cases.sh` / `cases.test.sh` pass
- [x] 3. The loop test stages whose files changed since step 11 pass (the others are skipped as unchanged)
- [x] 4. Rust: `# note abcd` and an extra valid input pass; an upper-case hex line and a bad kind fail `corpus.txt lists 33 inputs, the loader read 34`; a letter-dropping loader fails `read 0`
- [x] 5. C++ (on `gcc:16`): a flipped pair fails `pack: ab then a: got BadValue, want Ok`; a 5-byte key fails `put_key: the key fits its Text` and the pair reports TooLong
- [x] 6. No library or embedded file changed since the last arm stage (7aa2d8a); its log: Cortex-M4F flash 8,032 B of 8,192 B and stack 504 B of 512 B

## Result

Agent run 2026-10-22 at `740e7fe` (owner rule 2026-10-12 in `deployment_procedures.md`): **6/6 steps passed**, about 175 seconds (step 2: 90 s; step 3: 14 stages skipped as unchanged, the stamps were already at `740e7fe` after step 11; step 4: 6 s; step 5: 76 s). Step 11 at `740e7fe` (`scripts/loop-tests.sh`): 2 passed (rust 35 s, cpp 38 s), 12 skipped as unchanged, 0 failed (`_docs/03_implementation/test_run_loop60_report.md`).

## For the operator

- Jira: the Atlassian connector is still absent. Two leftovers wait: `2026-10-22_loop59_jira_in_testing.md` (AZ-3163, AZ-3164 to In Testing) and `2026-10-22_loop60_jira_create_tasks.md` (create the two loop 60 tasks under AZ-2645, then In Testing).
- Owner input still open (as in `handoff61.md`): size limits for the Rust feature sets; CS-D5; the first `v*` and `go/v*` tags; F44; close the epic AZ-2750; whether to close U24 in the C++ package.
