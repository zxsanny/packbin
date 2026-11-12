# Loop 113 smoke — proposed checks

LOCAL_URL: none (library: no site, no local deploy; `_docs/04_deploy/deployment_procedures.md` § Loop smoke gate)
Branch: dev

The agent runs `smoke113.sh` itself at the commit before the close commit (owner rule 2026-10-12: all `N/N` steps pass, the gate passes without a question). The nine package suites, the ring, the ARM rows and the publish gate ran in step 11 (`scripts/loop-tests.sh --all`, 15 of 15 stages, 1,444 s).

## Run this (one paste, from the repository root)

```bash
bash _docs/loops/loop113/smoke113.sh
```

## Checks

- [ ] 1. The nine probes run from one command (85 lines, `scripts/probes/repeat-followed-by-field/run.sh`) and write nothing into the checkout
- [ ] 2. Every control scheme (a repeat that is last) builds and reads back `01090506` in all nine packages and the Rust heap-free API (10 lines)
- [ ] 3. The class is refused when the scheme is built: 75 of 75 non-control lines say `refused`, none says `built` (a field after a repeat, two repeats in a row, a repeat in a list or dict element, under `when` and `flags`)
- [ ] 4. The rule count of the TypeScript suite and the ring drivers is 0 (`rule-count/run.sh`)
- [ ] 5. `fixtures/hostile/cases.txt` holds 90 valid cases, including the two of AZ-4232, and `cases.test.sh` passes
- [ ] 6. The probe scripts parse and pass shellcheck
- [ ] 7. AZ-4210 to AZ-4219 and AZ-4232 are in `done/`, the contract is 1.0.2 and implemented, the README states the rule, the queue items and the operator to-do exist
- [ ] 8. No code changed since the step 11 run (`888a3e8`): only documents

## Notes

No credentials. The probe run takes about 70 s on a quiet host, `cases.test.sh` about 4 minutes.

## Result

Commit: `888a3e8` (the last code commit; the tree holds only documents since, step 8). `bash _docs/loops/loop113/smoke113.sh`: `SMOKE 113: ALL PASS (8/8)`, 294 s on 2026-11-12, agent run, owner rule 2026-10-12 in `deployment_procedures.md` (all `N/N` steps pass: the gate passes without a question). Step 11 before it: `scripts/loop-tests.sh --all`, 15 of 15 stages, 1,444 s; NOT RUN: the two vcpkg checks (no vcpkg tool).
