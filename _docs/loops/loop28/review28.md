# Review — loop 28 (one total review, inline, effort high)

6 findings: 1 Medium correctness, 1 Low test-coverage, 4 Low (altitude x2, conventions x2).

| # | Sev | Category | Finding | Handling |
|---|-----|----------|---------|----------|
| 1 | Medium | correctness | the `publish-gate` job lost the `mkdir -p test-results` the suites step did | fixed: step "test results directory" |
| 2 | Low | test-coverage | layout guard ignored `set -euo pipefail` in the suites step | fixed: rule + mutant |
| 3 | Low | altitude | global EXIT trap in `publish-timing.test.sh` is fragile to a later trap | skipped: no other trap exists; noted |
| 4 | Low | altitude | the host-delete-then-container pattern is not audited elsewhere | skipped: leftover |
| 5 | Low | conventions | README limit sentence gives a hedged reason ("may not resolve") | skipped: the reason is stated as unproven, which is the point of S3 B |
| 6 | Low | conventions | `ci_cd_pipeline.md` mixes old and new timings | skipped: figures are filled at close after the CI run |
