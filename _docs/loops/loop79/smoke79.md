# Loop 79 smoke — ring number ranges and warning-free Rust test builds

LOCAL_URL: none (scripts, the CI `ring` and `suites` jobs; no site). Branch: dev. Script: `bash _docs/loops/loop79/smoke79.sh`. Run by the agent on 2026-10-28 at host load about 5 to 10 (owner rule 2026-10-12 in `_docs/04_deploy/deployment_procedures.md`: the agent runs the script and the gate passes when every step passes).

## Checks

- [x] 1. No application source is dirty
- [x] 2. `ring-frame.test.sh` passes (32 cases), among them `refusals-7`, `pair-6`, `refusals-5` (`... and N more`) and `row-dir-256`, `row-out-len-65536` (the loader refuses out-of-range rows) — AZ-3356 AC-4, AC-7
- [x] 3. The real ring with all 8 drivers: `ring-frame: 64 pairs, mismatched: 0` and 8 lines `refusals <lang>: 43 rows, 0 mismatched`; the 6 top-of-range rows are in `ring-cases.txt` — AC-5
- [x] 4. `ring-frame-drivers.test.sh`: 132 PASS, `all passed (8 languages, 132 checks)` — AC-1, AC-2
- [x] 5. Not vacuous: the loop-start Python driver, in a scratch copy, fails the new cases (`FAIL python dir-256`, `FAIL python dir-minus-1`; 8 FAIL) — AC-3
- [x] 6. Rust in `rust:1.98`: `cargo check --tests` of the 9 feature sets, 0 warnings in each — AZ-3357 AC-8
- [x] 7. `run-suite.test.sh` passes; `run-suite.sh` checks the 9 sets — AC-9
- [x] 8. A test file without its `#![cfg(feature = "std")]` (`bound_names_tests.rs`, scratch copy) fails the `none` set, exit 101 — AC-10
- [x] 9. Job layout, loop-tests, ring wiring, ring rows, ring-lib and report-row tests pass
- [x] 10. No touched source file went over 500 lines in this loop

## Agent walk

10 PASS, 0 FAIL, 0 NOT RUN (`smoke79: 0 failed`, exit 0, 113 s) on the first trial, at the commit before the close commit.

## For the operator

Nothing: every check ran in the script.

## Result

692edcc: 10/10 steps passed; agent run, owner rule 2026-10-12 in `deployment_procedures.md`. Smoke: PASS.
