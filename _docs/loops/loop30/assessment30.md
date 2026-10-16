# Feature assessment — loop 30

loop: 30
feature: ci-speed
rounds: 1
verdict: COMPLETE (T3 and T1 unproven until the next tag; T2 option B's Swift part not built, owner decision open)

FEATURE ASSESSMENT loop 30 round 1: COMPLETE — 8 covered / 1 not built with reason / 0 gap-unclear

| id | scenario | status | evidence |
|----|----------|--------|----------|
| C1 | `suites` a matrix, one job per language, Swift in two parts | covered | run 38921222391: 9 suite jobs, longest 379 s; `run-suite-swift.test.sh` parts proof |
| C2 | `publish-gate` in 3 parallel jobs | covered | readonly 415, phases 324, rest 259 s; `publish-jobs.test.sh` |
| C1+C2 | wall about 7 minutes | covered (1 run) | 418 s against 980 to 1 095 s |
| G1 | no check removed | covered | 14 groups, 8 languages, Swift steps; counts in `notes30.md` |
| G2 | one mutant per changed guard rule | covered | 45 + 8 + 9 + 6 mutants rejected |
| T3 | cause of the 19 minute Go proxy wait found; wait shorter, check unchanged | covered, unproven on a tag | cached miss after a request 1.2 s after the push; `publish-go.sh` waits for the tag and 30 s |
| T2 | owner decision, recommended first | covered | asked; owner chose B |
| T2-B | Swift check early | not built | ADR-005 order (Go tag, then Swift) is asserted by a test; gain about 70 s; needs an ADR amendment |
| D1 | metrics report before/after with numbers | covered | `ci_metrics_2026-10-16.md` section 6 |
| D2 | no tag, no registry upload | covered | none pushed |
