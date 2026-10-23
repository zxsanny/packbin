# Loop 61 smoke — checks

LOCAL_URL: none (a library; the proof is the arm stage figures)
Branch: dev
Script: `smoke61.sh` in this folder (`bash _docs/loops/loop61/smoke61.sh`; Docker is needed).

## Checks

- [x] 1. No application source is dirty; `cpp/src`, `cpp/include`, `cpp/embedded` are identical to the last arm stage (7aa2d8a)
- [x] 2. Baseline: the Cortex-M4F target at HEAD reports flash 8,032 B and stack 504 B, with no pin failure
- [x] 3. Candidate A (`pack_held_of_a.patch`) on a scratch copy: flash 8,104 B, rejected by the stage against the pin of 8,032 B
- [x] 4. Candidate A pack stack is 404 / 440 / 492 (8 B lower), unpack stack unchanged (flag chain 540)
- [x] 5. `scripts/loop-tests.sh`: the stages whose files changed since step 11 pass (all skipped as unchanged: only `_docs/` changed)

## Result

Agent run 2026-10-23 at `603fbf4` (owner rule 2026-10-12 in `deployment_procedures.md`): **5/5 steps passed**, about 7 seconds. Candidate shapes B to E were measured by hand in the same container; their figures are in the task spec.

## For the operator

- Decision recorded: the pack-side `held_of` is not kept (flash +44 to +72 B over the pin, no stack gain where it matters). Tell the agent if the owner wants the pin raised for it instead; that needs a line in `AGENT_GOTCHAS.md` saying what the bytes bought.
- Jira: the Atlassian connector is still absent. Leftovers wait: `2026-10-22_loop59_jira_in_testing.md` and `2026-10-22_loop60_jira_create_tasks.md` (now three tasks to create under AZ-2645).
- `main` has no `test.yml` run for 9bb9626 (see the loop 60 record); this loop's push will show whether `main` runs.
