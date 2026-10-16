# Autodev Loop Plan — Loop 30

loop: 30
kind: product
confirmed: true
branch: dev
ship: false

Intake: owner chose "all recommended" from the metrics report 2026-10-16; ticket AZ-2600 (epic AZ-2223). Owner preferences: one total review, one step 11 run, 30 s heartbeats, `< /dev/null` and timeouts on shell, no tag or registry upload, pushes of `dev` asked each time.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done in P0 |
| decompose-feature | 9.5 | Decompose Feature | no | one task |
| implement | 10 | Implement | yes | AZ-2600: C1+C2, then T3, then T2 after the owner's decision |
| code-review | — | Total review | yes | once over the loop diff before step 11 |
| feature-assess | 10.5 | Feature Assessment | yes | once, read-only |
| run-tests | 11 | Run Tests | yes | one run: `scripts/loop-tests.sh`, guards, mutants; CI proof runs after the owner's push go |
| test-spec-sync | 12 | Test-Spec Sync | no | no product AC |
| update-docs | 13 | Update Docs | yes | `ci_cd_pipeline.md`, metrics report before/after |
| security | 14 | Security Audit | no | no auth change (T2 reorders publish steps only) |
| performance | 15 | Performance Test | no | measured by CI runs |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no tag |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | last retro loop 26 |
| local-deploy | — | Local deploy + open site | yes | none (CI only): CI runs are the proof |
| smoke | — | Smoke acceptance | yes | checklist in `smoke30.md` |

## Implementation
### Files that change
- `.github/workflows/test.yml`, `publish-gate.test.sh`, `publish-jobs.test.sh`, `publish-workflow.test.sh`, `publish-timing.selftest.sh`, `report-row.test.sh`, `run-suite.sh`, `run-suite-swift.test.sh`, `ring-wiring*.test.sh` if they read the layout, `scripts/loop-tests*.sh`
- T2/T3: `publish-registries.sh`, `publish-upload.sh`, `publish-go.sh`, `publish-swift.sh` and their tests
### Order of work
1. Swift part split in run-suite.sh + test. 2. `--groups` in publish-gate.test.sh + selftest. 3. test.yml matrix + 3 gate jobs + guards + mutants. 4. T3 evidence. 5. owner decision T2. 6. docs.
### Proof
Counts before/after; one mutant per rule; CI runs per-job times.
### Risks
Concurrent job limit; Swift part split must keep every step.
