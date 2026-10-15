# Loop 29 expected results (input to output)

| # | Input (command or action) | Expected output |
|---|---------------------------|-----------------|
| 1 | `bash .github/workflows/publish-gate.test.sh` (Mac) | 14 lines `publish-gate: <check> took N s`, a total line of at most 800 s, then `publish gate tests passed` (or `publish gate: no failures, NOT RUN: ...`); exit 0 |
| 2 | The same command in CI, `publish-gate` job, 3 runs on `dev` | job time median at most 18 min, none above 20 min; exit 0 each |
| 3 | The command of row 1 with a guarded behaviour broken in a copy (one mutant per changed scenario) | exit non-zero; the group's own failure message names the broken behaviour |
| 4 | Assertion and mutant counts of each group, before (loop 28 log) and after | equal or higher in every one of the 14 groups |
| 5 | `wc -l` on `publish-gate.test.sh` and each sourced file | each at most 500 lines |
| 6 | `_docs/04_deploy/ci_cd_pipeline.md` gate timing section | median of 3 runs and per-group figures of loop 29; no loop 28 figure marked current |
