# Autodev loop record — loop 68

loop: 68
branch: dev
plan_artifact: _docs/loops/loop68/plan68.md
tasks_shipped: [AZ-3189_cpp_m33f_target_nrf54l15]
decisions:
  - owner (2026-10-25, chat): "nRF54L15 is our target, so pick that for ram budget and so on or higher"; agent confirmed the part on Nordic's page and Zephyr's board docs (Cortex-M33F 128 MHz, 256 KB RAM, 1.5 MB NVM as RRAM, 128 KiB RAM in a non-secure image)
  - owner (2026-10-25, AskUserQuestion, recommended options): loop 68 = re-base budgets + Cortex-M33F target; ceilings flash 64 KB and stack 8 KB, pins at the measured values; the owner asked in chat to see the numbers before any pin changed and then accepted 64 KB and 8 KB (the numbers were shown after the code was committed locally and before the push)
  - agent: the M4F row and pins (7,712 B / 540 B) stay as the small-part bar; the new row is `cpp-m33f` after `cpp-m4f`
  - agent: flash figure = the all-kinds image (text plus data, codec and ECC on), 25,720 B; stack = net of the meter, 724 B; the meter window went from 8,192 B to 16,384 B
  - agent: `lib.test.sh` stubs and counts now cover six rows (`target_m33f`), `run-parts.test.sh` oracle has the row
  - agent: Jira AZ-3189 created under AZ-2645 (3 points as "Story point estimate"), moved to In Testing and read back
  - agent: retro of loops 64 to 68 done in this loop (`retro_2026-10-25_loop68.md`); LESSONS trimmed to 15 (four oldest dropped, two added)
leftovers:
  - owner: CS-D5 (deferred); first `v*` / `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; whether to drop the M4F row
  - candidates: a Rust or other-package check on a Cortex-M33F image (the Rust embedded stage still builds for M4F); a non-secure (TrustZone) image with 128 KiB of RAM on `mps2-an505`; cycle timing; Go window floor of 10 s; `item` pointer removal; `session_core` clippy; ring driver for `nostd`
  - open: the cause of the container `pip install` failure of loop 65 (no repeat in loops 66 to 68)
  - Jira: AZ-3189 In Testing at close (read back); epic AZ-2645 open
  - CI: loop 67 push read at the start of this loop, green on `dev` (run 40143198345, 213 s) and `main` (run 40143200878, 408 s); the CI of this loop's push is read at the next loop start
smoke: PASS (agent run 6/6, owner rule 2026-10-12)
smoke_artifact: _docs/loops/loop68/smoke68.md
assessment_artifact: _docs/loops/loop68/assessment68.md
step11: `scripts/loop-tests.sh` one run at `1df2e05`: cpp, scaffold, cpp-embedded-arm, rust-embedded, ring, publish-gate PASS (6 passed, 8 skipped as unchanged, 0 failed); the gate wall of 24,249 s is a laptop sleep and a DST clock change, every share log ends "publish gate tests passed"; the tree did not change during the gate
review: feature-assess COMPLETE (9 of 9 rows covered or out-of-scope, one residual risk); no per-batch code review (owner preference)
security: not in plan
retro: done in this loop, `_docs/06_metrics/retro_2026-10-25_loop68.md` (loops 64 to 68; next due after loop 73 or an incident)
loop_end_merge: main
