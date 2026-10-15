# Loop 27 expected results

| # | Input | Expected result | Check |
|---|-------|-----------------|-------|
| 1 | Push of the fixed `dev` commit | `test.yml` run: `scaffold`, `embedded`, `ring` all `success` | Actions REST API read with `curl` (CG-1) |
| 2 | Same run, step `publish gate` | `conclusion: success`, `completed_at - started_at <= 1500 s` | jobs API (CG-2) |
| 3 | `bash .github/workflows/publish-gate.test.sh` in the CI image on the Mac, Swift scenarios included | exit 0, last line `OK`-style summary with the Swift scenarios named; wall time <= 900 s for the Swift scenarios | timed local run (CG-6) |
| 4 | `docker compose -f docker-compose.test.yml run --rm swift` (the Swift stage) | exit 0, `340 tests in 56 suites` in the plain runs, sanitizer run lists the concurrency and session suites only; wall time <= 500 s | timed local run (CG-5) |
| 5 | `git tag --list` after the loop | same tag list as before (CG-8) | `git ls-remote --tags origin` |
