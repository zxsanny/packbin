# Loop 65 smoke — checks

LOCAL_URL: none (a library; the proof is the files, the unit scripts and the arm stage)
Branch: dev
Script: `smoke65.sh` in this folder (`env PATH=<dir with python3 -> python3.14>:$PATH bash _docs/loops/loop65/smoke65.sh`; needs Docker for steps 4 and 5).

## Checks

- [x] 1. AC-1, AC-2: `test.yml` push ignores exactly `_docs/**`; the wiring check accepts it and rejects the old file
- [x] 2. AC-3: `limits.txt` holds `base 16384 512`, `text 27964 2898`, `ecc 18879 798`, `session 19325 1924`
- [x] 3. AC-4: `checks.test.sh` passes (numeric limits; a dash and a missing line are caught)
- [x] 4. AC-5: a text flash limit of 26,631 B fails the Rust stage with `text: flash 26632 B over 26631 B`
- [x] 5. AC-7 to AC-9: the arm stage passes, 0 failures in the new case, stack 612 B of 2048 B (pin 612 B), flash 7,724 B (pin 7,724 B)
- [x] 6. Step 11 stages other than the publish gate pass or are skipped as unchanged

## Result

Agent run 2026-10-23 at `f3738da` plus the uncommitted loop 65 documents (owner rule 2026-10-12): **6/6 steps passed**, about 15 seconds. The pin was also proved with a mutant (pin 611 B: `stack 612 B measured is over the pin of 611 B`).

## For the operator

- Publish gate: in two full parallel runs two timing-bound checks failed (`publish-go.test.sh` AC-3, `publish-phases-failures.test.sh` AZ-2096 AC-4) and each passes alone (`go` 28 s, `phases` 325 s, share 7 whole 1,057 s). The CI `publish-gate-*` jobs run one share each; read their result after the push.
- The first docs-only push after this loop shows whether `paths-ignore` works on GitHub (no `test` run for that commit).
- Jira: the connector is still absent; six tasks have no key (`2026-10-22_loop60_jira_create_tasks.md`).
