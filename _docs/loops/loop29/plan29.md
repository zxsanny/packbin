# Autodev Loop Plan — Loop 29

loop: 29
kind: product
confirmed: true
branch: dev
ship: false

Loop works on `dev` in this session (no worktree). Intake: owner pick 2026-10-15 "Cut the gate", approach A, target the `publish-gate` job at most 18 minutes (median of 3 runs); feature `_docs/02_task_plans/gate-cut/`; ticket AZ-2582 (5 points, epic AZ-2223). Owner preferences: one total review, one step-11 run, 30 s heartbeats, `< /dev/null` and timeouts on shell, no tag without the owner's go, pushes of `dev` asked each time (the loop 28 close commit f78553e is unpushed).

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done in P0 |
| decompose-feature | 9.5 | Decompose Feature | no | 5 points, one task |
| implement | 10 | Implement | yes | AZ-2582 in the parent: measure per scenario, then cut |
| code-review | — | Total review | yes | once over the loop diff before step 11 |
| feature-assess | 10.5 | Feature Assessment | yes | once, read-only |
| run-tests | 11 | Run Tests | yes | one run: gate on the Mac, selftest, mutants, then CI runs after the owner's push go |
| test-spec-sync | 12 | Test-Spec Sync | no | no product AC changed |
| update-docs | 13 | Update Docs | yes | `ci_cd_pipeline.md` timings |
| security | 14 | Security Audit | no | no auth, secret, network or untrusted input |
| performance | 15 | Performance Test | no | CI wall time is measured by GC-1 |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no deploy |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | no incident; last retro loop 26 |
| local-deploy | — | Local deploy + open site | yes | no local deploy script, no UI: the Mac gate run and the CI runs are the proof |
| smoke | — | Smoke acceptance | yes | checklist in `smoke29.md` |

## Implementation
### Files that change
- `.github/workflows/publish-gate.test.sh` and the sourced `publish-*.test.sh` files (swift, swift-gate, readonly, phases, gate checks, pins); split a file over 500 lines by responsibility
- `_docs/04_deploy/ci_cd_pipeline.md` (timings), status report entry
### Order of work
1. Per-scenario timing for swift, readonly, phases, gate (temporary, then kept only if cheap). 2. Cut list from the numbers. 3. Cuts one at a time with a mutant each, gate counts compared to the loop 28 log. 4. Mac run, then the owner's push go for CI runs.
### Proof
Counts per group before and after; mutants; 3 CI runs.
### Risks
A shared fixture hiding a guard; Mac gain not moving the runner.
