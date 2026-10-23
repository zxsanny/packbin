# Loop 64 smoke — checks

LOCAL_URL: none (a documents-only loop; the proof is the files and git)
Branch: dev
Script: `smoke64.sh` in this folder (`bash _docs/loops/loop64/smoke64.sh`; no Docker needed).

## Checks

- [x] 1. AC-5: every path changed since the end of loop 63 (`3619a2d`), committed or not, is under `_docs/`
- [x] 2. AC-1: the retro has its three sections, a row for each of loops 61, 62 and 63, and names the loop 60 retro
- [x] 3. AC-2: commits 2 / 4 / 5, 8 points and the flash and stack figures in the report equal git and the task specs
- [x] 4. AC-3: `LESSONS.md` holds 15 entries (2 new, each with a Source line) and `AGENT_GOTCHAS.md` has the new line
- [x] 5. AC-4: the report states exactly 3 improvements
- [x] 6. AC-6: both Jira leftovers keep their payload; 5 `AZ-PENDING` specs, as at `3619a2d`
- [x] 7. `scripts/loop-tests.sh`: all 14 stages skipped as unchanged (only `_docs/` changed)

## Result

Agent run 2026-10-23 at `d65adcf` plus the uncommitted loop 64 files (owner rule 2026-10-12 in `deployment_procedures.md`): **7/7 steps passed**, about 1 second. Negative proof of step 1: an untracked `zz_probe.txt` in the repository root is listed by the same pipeline.

## For the operator

- Retro improvements 2 and 3 are the owner's call (`retro_2026-10-23_loop64.md`): a named consumer for the 468 B of flash margin before another flash loop, and `paths-ignore: ["_docs/**"]` in `test.yml`.
- Jira: the Atlassian connector is still absent; the two leftovers wait (`2026-10-22_loop59_jira_in_testing.md`, `2026-10-22_loop60_jira_create_tasks.md`, five tasks to create). This loop owes no new task.
