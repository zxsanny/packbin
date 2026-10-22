# Loop 59 smoke — checks

LOCAL_URL: none (a library; the proof is the test stages and CI)
Branch: dev
Script: `smoke59.sh` in this folder (`bash _docs/loops/loop59/smoke59.sh`; Docker, `cargo` and `python3` are needed).

## Checks

- [x] 1. No application source is dirty
- [x] 2. The hostile case file still holds 75 cases and `check-cases.sh` / `cases.test.sh` pass
- [x] 3. The loop test stages whose files changed since step 11 pass (the others are skipped as unchanged)
- [x] 4. Rust (AZ-3163): a `# note abcd` comment leaves the count alone, an extra input line raises both counts, a loader that also drops letter-led lines fails: `corpus.txt lists 34 inputs, the loader read 0`
- [x] 5. C++ (AZ-3164): a flipped pair fails as `pack: ab then a is BadValue`; a 5-byte key fails `put_key: the key fits its Text` (both on `gcc:16`)
- [x] 6. No library or embedded file changed since the last arm stage (7aa2d8a); its log: Cortex-M4F flash 8,032 B of 8,192 B and stack 504 B of 512 B

## Result

Agent run 2026-10-22 at `2a0d510` (owner rule 2026-10-12 in `deployment_procedures.md`): **6/6 steps passed**, about 170 seconds (step 2: 75 cases, 88 s; step 3: 14 stages skipped as unchanged, the stamps were already at `2a0d510`; step 4: 4 s; step 5: 75 s; step 6: flash margin 160 B, stack margin 8 B). Step 11 at `2a0d510` (`scripts/loop-tests.sh`): 2 passed (rust 38 s, cpp 41 s), 12 skipped as unchanged, 0 failed (`_docs/03_implementation/test_run_loop59_report.md`).

## For the operator

- Jira: AZ-3163 and AZ-3164 exist under the epic AZ-2645 and are still To Do. The transition to In Testing was refused ("This tool has been disabled in your connector settings") and the Atlassian connector then left the session; the replay is in `_docs/_process_leftovers/2026-10-22_loop59_jira_in_testing.md`. The first create of AZ-3164 timed out but had landed; it was found by a search and not created twice.
- Owner input still open (as in `handoff59.md`): size limits for `text`, `ecc` and `session`; CS-D5; the first `v*` and `go/v*` tags; F44; close the epic AZ-2750; whether to close U24 in the C++ package.
