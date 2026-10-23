# Loop 62 smoke — checks

LOCAL_URL: none (a library; the proof is the arm stage figures)
Branch: dev
Script: `smoke62.sh` in this folder (`bash _docs/loops/loop62/smoke62.sh`; Docker is needed).

## Checks

- [x] 1. No application source is dirty; `flash_pin=7808`; `Field` has no count pointer and the size guard is in `table.hpp`
- [x] 2. The Cortex-M4F stage on a copy of `cpp/` reports flash 7,808 B and stack 496 B, with no pin failure
- [x] 3. A pin one byte lower (7,807 B) fails the stage by its own bytes
- [x] 4. The size guard is live on arm-none-eabi-g++: it compiles at 32 B and a copy with the limit at 28 B is refused
- [x] 5. `scripts/loop-tests.sh`: the stages whose files changed pass (all skipped as unchanged after the step 11 run)

## Result

Agent run 2026-10-23 at `0b10651` (owner rule 2026-10-12 in `deployment_procedures.md`): **5/5 steps passed**, about 6 seconds. Step 11 ran before it: `RESULT 5 passed, 9 skipped as unchanged, 0 failed, 426s` (cpp, scaffold, cpp-embedded-arm, rust-embedded, ring).

## For the operator

- Nothing to run. `AC-1` was relaxed by the owner from 28 B to 32 B (the `item` pointer cannot go without an element offset and stride).
- Jira: the Atlassian connector is still absent. Leftovers wait: `2026-10-22_loop59_jira_in_testing.md` and `2026-10-22_loop60_jira_create_tasks.md` (now four tasks to create under AZ-2645).
