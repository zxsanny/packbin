# Autodev Loop Plan — Loop 28

loop: 28
kind: product
confirmed: true
branch: dev
ship: false

Loop works on `dev` in this session (no worktree). Intake: owner request 2026-10-15 (speed check, then S3 limit, cpp pool race, small leftovers 26/27); feature `_docs/02_task_plans/ci-split-and-leftovers/`; tickets AZ-2563 to AZ-2567 (13 points, epic AZ-2223). Owner decision batch "accept all recommended": AZ-2068 held; speed set = job split + gate timings. Owner preferences: one total review, one step-11 run, 30 s heartbeats, `< /dev/null` and timeouts on shell, no tag without the owner's go, pushes of `dev` asked each time.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done in P0 (handoff to decompose) |
| decompose-feature | 9.5 | Decompose Feature | yes | done: 5 specs AZ-2563..2567 |
| implement | 10 | Implement | yes | wave 1: AZ-2563 then AZ-2564 (parent), AZ-2565 and AZ-2567 (workers), AZ-2566 (parent) |
| code-review | — | Total review | yes | once over the loop diff before step 11 |
| feature-assess | 10.5 | Feature Assessment | yes | once, read-only |
| run-tests | 11 | Run Tests | yes | one run: loop-tests.sh stages that the changed files cover, the new guards on mutants, then CI on the final push (owner's go) |
| test-spec-sync | 12 | Test-Spec Sync | no | no product AC or scenario changed |
| update-docs | 13 | Update Docs | yes | module-layout workflows text, ci_cd_pipeline.md timings |
| security | 14 | Security Audit | no | no auth, secret, network or untrusted-input change |
| performance | 15 | Performance Test | no | CI wall time is measured by SP-2 |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no deploy |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | complexity 13 but no incident; last retro loop 26 (2 loops ago) |
| local-deploy | — | Local deploy + open site | yes | no local deploy script, no UI: the step 11 run and the CI run are the proof |
| smoke | — | Smoke acceptance | yes | checklist in `smoke28.md` (CI run and timings) |

## Implementation
### Files that change
- AZ-2563: `.github/workflows/publish-gate.test.sh` (+ sibling if over 500 lines)
- AZ-2564: `.github/workflows/test.yml`, `publish-gate.test.sh`, `ring-wiring.test.sh`, `run-suite-swift.test.sh`, `report-row.test.sh`, `publish-readonly.test.sh` (comment), `_docs/04_deploy/ci_cd_pipeline.md`
- AZ-2565: `scripts/loop-tests.sh`, `scripts/loop-tests.test.sh` (cpp files only if the cause is there)
- AZ-2566: `README.md`, `_docs/02_document/adr/005_*.md`
- AZ-2567: scratchpad driver; entry in `_docs/05_security/` or the status report
### Order of work
Workers (AZ-2565, AZ-2567) start first; the parent does AZ-2563, AZ-2566, then AZ-2564.
### Proof
Guards against mutants; pool runs; CI run of the final push.
### Risks
Host load from other projects; a stale guard after the split.
