# Loop 58 smoke — checks

LOCAL_URL: none (a library; the proof is the test stages and CI)
Branch: dev
Script: `smoke58.sh` in this folder (`bash _docs/loops/loop58/smoke58.sh`; Docker, `cargo` and `python3` are needed).

## Checks

- [x] 1. No application source is dirty
- [x] 2. The hostile case file still holds 75 cases and `check-cases.sh` / `cases.test.sh` pass
- [x] 3. The loop test stages whose files changed since step 11 pass (the others are skipped as unchanged)
- [x] 4. Mutant, C++ (AZ-3162): a signed byte compare in a copy of `keys_ascending` fails the new host test on `gcc:16` (`pack: 7f then c2 80`)
- [x] 5. Mutant, Rust (AZ-3160): a loader filter that also drops letter-led lines fails: `corpus.txt lists 33 inputs, the loader read 0`
- [x] 6. Mutant, Go (AZ-3161): an invented id in a copy of `hostileRefusals` fails and the message names both ids
- [x] 7. No library or embedded file changed since the last arm stage (7aa2d8a); its log: Cortex-M4F flash 8,032 B of 8,192 B and stack 504 B of 512 B

## Result

Agent run 2026-10-22 at `ac3cc99` (owner rule 2026-10-12 in `deployment_procedures.md`): **7/7 steps passed**, about 2 minutes (step 2: 75 cases; step 3: 14 stages skipped as unchanged; step 4: the mutant fails 5 lines; step 7: flash margin 160 B, stack margin 8 B). Step 11 at `ac3cc99` (`scripts/loop-tests.sh`): 3 passed (rust 37 s, cpp 41 s, go 265 s), 11 skipped as unchanged, 0 failed (`_docs/03_implementation/test_run_loop58_report.md`).

## For the operator

- Jira: AZ-3160, AZ-3161 and AZ-3162 go to In Testing (done); the epic AZ-2645 is open.
- Docker containers had no outbound network on the iPhone hotspot for the first `go` stage runs; on another network the stage passed through the compose path (`AGENT_GOTCHAS.md`). I restarted Docker Desktop at your request, which stopped the `archangel-*` containers for a minute; they came back.
- Owner input still open (as in `handoff58.md`): size limits for `text`, `ecc` and `session`; CS-D5; the first `v*` and `go/v*` tags; F44; close the epic AZ-2750; whether to close U24 in the C++ package.
