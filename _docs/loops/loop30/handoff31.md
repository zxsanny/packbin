# Loop 31 handoff — written 2026-10-16 while loop 30 was closing

Read `_docs/loops/loop30/record30.md`, `notes30.md`, `assessment30.md`, `_docs/04_deploy/reports/ci_metrics_2026-10-16.md` section 6 and `_docs/03_implementation/test_run_loop30_report.md`. Owner preferences from `_docs/loops/loop26/handoff27.md` stand.

## State when loop 30 closes
- `test.yml` 418 s on run 38921222391 (15 jobs). New long poles: `publish-gate-readonly` 415 s, `suites (swift, gates)` 379 s.
- T3 (Go proxy settle) and T1 (tag run skips the test) are unproven until the next tag; never push a `v*` or `go/*` tag without the owner's go.
- T2 option B: the Swift part conflicts with ADR-005; owner decides.

## Candidate work (owner picks)
- Balance the Swift parts (tests 284 s, gates 379 s on CI) and split `ro_gate_checks` (350 s) to bring the wall to about 5 minutes; caches (C3); embedded split (C4).
- Mac twin of C2: run the gate's three `--groups` shares in parallel in `scripts/loop-tests.sh` (1 141 s at load 10 to 21).
- `publish-phases.test.sh` (501 lines), review28 #3, #4, AZ-2068; owner only: F44, the first tags.
