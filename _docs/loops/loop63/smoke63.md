# Loop 63 smoke — checks

LOCAL_URL: none (a library; the proof is the arm stage figures)
Branch: dev
Script: `smoke63.sh` in this folder (`bash _docs/loops/loop63/smoke63.sh`; Docker is needed). `smoke63_u2diff.cpp` is its HEAD-versus-new probe.

## Checks

- [x] 1. No application source is dirty; `flash_pin=7724`; `bad` is `PACKBIN_NOINLINE`; `pack_u2` has no local buffer; no `held_of` in `pack.cpp`
- [x] 2. The Cortex-M4F stage on a copy of `cpp/` reports flash 7,724 B and stack 496 B, with no pin failure
- [x] 3. A pin one byte lower (7,723 B) fails the stage by its own bytes
- [x] 4. `pack_u2` returns the same `Result` (error, offset, field, needed) as `c9ceaa7` for 12 buffer and value cases
- [x] 5. `scripts/loop-tests.sh`: the stages whose files changed pass (all skipped as unchanged after the step 11 run)

## Result

Agent run 2026-10-23 at the close commit (owner rule 2026-10-12 in `deployment_procedures.md`): **5/5 steps passed**, about 8 seconds. Step 11 ran before it: `RESULT 5 passed, 9 skipped as unchanged, 0 failed, 395s` (cpp, scaffold, cpp-embedded-arm, rust-embedded, ring).

## For the operator

- Nothing to run. The `held_of` decision (drop) was the owner's, in chat.
- Jira: the Atlassian connector is still absent. Leftovers wait: `2026-10-22_loop59_jira_in_testing.md` and `2026-10-22_loop60_jira_create_tasks.md` (now five tasks to create under AZ-2645).
