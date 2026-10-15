# Feature description — loop 28 (CI speed and the loop 26/27 leftovers)

Epic: AZ-2223 (Swift package, open until the first tag). Component: `ci` (workflows, `scripts/loop-tests.sh`) plus the README and ADR-005 text and one Swift measurement. Estimated at 13 points (5 tasks): handed to `/decompose --feature` per the New Task complexity gate.

Read first: `problem.md` (what, concerns), `acceptance_criteria.md` (SP-1..5, CR-1..2, DO-1..2, PM-1), `scenarios.md` (S-1..S-14 and Card 1 resolved as Option A), `input_data/expected_results/results_report.md`.

## Proposed tasks (decompose may adjust)

| Slug | Points | Covers | Notes |
|------|--------|--------|-------|
| ci_gate_timings | 2 | SP-5 | per-check-group timing lines in `publish-gate.test.sh`; assertions untouched |
| ci_job_split | 5 | SP-1..SP-4 | `test.yml` into `scaffold`/`suites`/`publish-gate`; move the 4 guards (`publish-gate.test.sh` ruby job list, `ring-wiring.test.sh` `scaffold` steps, `run-suite-swift.test.sh` `for lang in` sed, `report-row.test.sh` grep) with mutant proofs; depends on ci_gate_timings (same file); first proof is a pushed CI run (owner's go) |
| cpp_pool_race | 3 | CR-1, CR-2 | reproduce first (which command writes `cpp/build/` beside the `cpp` stage), then remove the shared path; a check in `loop-tests.test.sh` |
| swift_limit_docs | 1 | DO-1, DO-2 | ADR-005 and README Swift lines; reword Linux/CI claims to the runs that exist |
| swift_peak_memory | 2 | PM-1 | measure the F10 packet and the default-limit wide round; record beside Go 625 MB / 94 MB |

## Scenarios

See `scenarios.md` (all rows `confirmed` or `out-of-scope`).

## Fit decisions

- Card 1: three jobs, no matrix (Option A). Constraint: the `publish-gate` job pulls its own images; nothing assumes the suites ran first.

## Constraints

- Production code is not changed. No tag, no registry upload, no push of `dev` without the owner's go (the CI split is proven only by a pushed run).
- Each source file stays at or under 500 lines (`publish-gate.test.sh` is 493, `publish-phases.test.sh` 501): new timing code goes in a sibling file or replaces lines.
- Owner preferences stand: one total review, one step 11 run, `< /dev/null` and timeouts on shell, 30 s heartbeats on long runs.
