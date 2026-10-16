# Loop 29 smoke — checks

LOCAL_URL: none (CI and test tooling, no UI; the proof is the CI run and the step 11 log)
Branch: dev

## Checks

- [x] 1. No gate or script file changed since 1ce48a2, the commit CI ran
- [x] 2. `scripts/loop-tests.sh --plan`: `scaffold` and `publish-gate` skip as unchanged since their passing stamp (e20e8fd)
- [x] 3. CI run 38888934994: 5 of 5 jobs `success`, `publish-gate` job at most 1 080 s (GC-1, run 1 of 3)
- [x] 4. The timing annotation of that job: one notice with the 14 groups and the total (GC-2, GC-10)
- [x] 5. `publish-timing.selftest.sh` passes
- [x] 6. The 6 changed files are at most 500 lines (GC-6)
- [x] 7. `notes29.md` (ledger, mutation proofs) and `test_run_loop29_report.md` exist and say PASS (GC-4, GC-5)

## Result

Commit 1ce48a2 (code); run 2026-10-16 by the agent, owner rule 2026-10-12 in `deployment_procedures.md` § Loop smoke gate: **7/7 steps passed** (job 689 s; annotation 1 notice with 15 lines; largest changed file 475 lines). Step 4 failed on the first run because the script split the annotation on the literal `%0A` while GitHub returns real newlines; the script was fixed, the check was not changed, and the whole script was re-run.

## For the operator

- Runs 2 and 3 of the median of 3 for GC-1 were the close pushes of `dev` and `main` (825 s and 1 011 s, with 689 s: median 825 s).

## Notes

No credentials. No tag, no registry upload.
