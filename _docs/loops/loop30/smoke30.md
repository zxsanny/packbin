# Loop 30 smoke — checks

LOCAL_URL: none (CI and test tooling, no UI; the proof is the CI run and the step 11 log)
Branch: dev

## Checks

- [x] 1. Tree clean at the commit that closes the loop (apart from this file and the record)
- [x] 2. CI run 38921222391: 15 of 15 jobs `success`, wall time 418 s (target: about 7 minutes)
- [x] 3. The three gate jobs' annotations list the 14 groups exactly once (readonly; gate, pins, phases; the other ten)
- [x] 4. `publish-jobs.test.sh` (45 mutants), `publish-timing.selftest.sh`, `report-row.test.sh` pass; `run-suite.test.sh` (with the Swift part mutants) and `publish-go.test.sh` pass
- [x] 5. `scripts/loop-tests.sh`: all stages PASS (rust and go on a re-run, timing bounds under load)
- [x] 6. The changed files are at most 500 lines (largest 469: `publish-go.test.sh`)
- [x] 7. No tag, no registry upload, no push of `main` in the loop

## Result

Agent run 2026-10-16, owner rule 2026-10-12 in `deployment_procedures.md`: **7/7 checks passed**.

## For the operator

- T3 (Go proxy wait) and T1 (tag run skips the repeated test) are proven only by the next tag; T2 option B's Swift part was not built (ADR-005 says the Swift check runs after the Go tag; about 70 s of gain): decision open.
- Second and third CI run of the same code: the close push of `dev` (and of `main`, if the owner allows it).
