# Autodev Loop Plan — Loop 27

loop: 27
kind: product
confirmed: true
branch: dev
ship: false

Loop works on `dev` in this session (no worktree). Intake: leftover `2026-10-14_ci-fail-loop26-close` (consumed), `_docs/loops/loop26/handoff27.md`; feature `_docs/02_task_plans/ci-publish-gate/` (CG-1 to CG-8); ticket AZ-2556 (3 points, epic AZ-2223). Owner decisions 2026-10-15 ("accept all recommended"): S1 A, S2 A, S3 B, F44 with the owner. Owner preferences unchanged: one total review, one step-11 run, 30 s heartbeats, `< /dev/null` and timeouts on shell, no tag without the owner's go, pushes of `dev` asked each time.

## Scope

Spec claimed (`loop: 27`): AZ-2556. AZ-2068 stays out. Implementation was done diagnosis-first before the plan (commits `94834ef`, `5703ff7`, `00ad75f`; CI run 38694589648 green on `94834ef`).

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | intake leftover seeded `problem.md`; spec written after the fact |
| decompose-feature | 9.5 | Decompose Feature | no | 3 points |
| implement | 10 | Implement | yes | done in `94834ef`, `5703ff7` (parent only, no workers) |
| code-review | — | Total review | yes | once over `1c3ddc4..HEAD` before step 11 |
| feature-assess | 10.5 | Feature Assessment | yes | once, read-only |
| run-tests | 11 | Run Tests | yes | one run: `run-suite.test.sh`, `publish-swift.test.sh`, the Swift stage, the publish gate test, ring wiring tests; then CI on the final push |
| test-spec-sync | 12 | Test-Spec Sync | no | no product AC or scenario changed |
| update-docs | 13 | Update Docs | no | CI timings go in `ci_cd_pipeline.md` at close (docs-only) |
| security | 14 | Security Audit | no | no auth, secret, network or untrusted-input change; last audit 2026-10-14 |
| performance | 15 | Performance Test | no | CI stage time is measured in CG-5, not a perf NFR |
| deploy | 16 | Deploy | no | `ship: false` |
| release | 16.5 | Release | no | no deploy |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | complexity 3, no incident beyond the CI fix, last retro loop 26 |
| local-deploy | — | Local deploy + open site | yes | no local deploy script, no UI: the Swift stage container run and the CI run are the deploy proof |
| smoke | — | Smoke acceptance | yes | user checklist in `smoke27.md` (CI run and gate timings) |
