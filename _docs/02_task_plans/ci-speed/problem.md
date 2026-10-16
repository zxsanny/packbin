---
loop: 30
branch: dev
---

# Loop 30 — CI test time and tag publish run time (AZ-2600, epic AZ-2223)

Owner (2026-10-16): after the metrics report `_docs/04_deploy/reports/ci_metrics_2026-10-16.md`, chose all recommended reductions.

## What

- C1+C2 (together): `test.yml` `suites` as a matrix, one job per language, Swift in two parts (`PACKBIN_SWIFT_PART` tests / gates); `publish-gate` as 3 parallel jobs (groups selected by `publish-gate.test.sh --groups`). Wall 15 to 18 min to about 7 min. Every guard that reads the job layout follows (publish-jobs, publish-workflow, report-row, run-suite-swift, ring wiring, loop-tests) with a mutant per rule; no check removed (count of `run:` commands and of gate groups before and after).
- T2: tag run pushes the Go tag and runs the Swift consumer check while Maven Central is still publishing; "no Go tag after a registry rejects the upload" kept by pushing once Maven reports PUBLISHING. Owner decision first (recommended option first).
- T3: find why `proxy.golang.org` needed 19 minutes (38 misses) for go/v0.3.0; shorter or non-blocking wait without weakening the check. No go/ or v* tag is pushed to test it.

Not in scope: C3, C4, T4, any tag, any registry upload, F44, AZ-2068.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A split that drops a gate group or a language from the matrix passes silently | guard reads the group list and the matrix and rejects a missing or duplicate entry; mutants | open | High |
| T2 changes the order of a publish; a Maven failure after validation would leave a Go tag | owner decision, asked before any T2 code | open | High |
| More concurrent jobs than the 20 of the free plan when dev and main are pushed together | measure; report | open | Medium |
| Pushes of `dev` asked each time; CI proof needs pushes | owner | open | Medium |
