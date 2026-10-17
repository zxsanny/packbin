# Autodev Loop Plan — Loop 31

loop: 31
kind: product
confirmed: true
branch: dev
ship: false

Intake: owner accepted all six recommendations of `_docs/loops/loop30/handoff31.md` (2026-10-17); ticket AZ-2607 (epic AZ-2223), 5 points, research skipped (the loop 30 metrics report is the research). Owner preferences: one total review, one step 11 run, 30 s heartbeats, `< /dev/null` and timeouts on shell, no tag or registry upload, pushes of `dev` asked each time, `main` not pushed.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done in P0 |
| decompose-feature | 9.5 | Decompose Feature | no | one task, 5 points |
| implement | 10 | Implement | yes | AZ-2607 in two batches: structure + timing, then the rebalance from the first CI run's numbers |
| code-review | — | Total review | yes | once over the loop diff before step 11 |
| feature-assess | 10.5 | Feature Assessment | yes | once, read-only |
| run-tests | 11 | Run Tests | yes | one run: `scripts/loop-tests.sh` (its new parallel gate stage is AC-4's proof), guards, mutants |
| test-spec-sync | 12 | Test-Spec Sync | no | no product AC |
| update-docs | 13 | Update Docs | yes | `ci_cd_pipeline.md` job layout and timings, metrics report section 7 |
| security | 14 | Security Audit | no | no auth, secret or input change |
| performance | 15 | Performance Test | no | measured by CI runs (AC-1) |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no tag |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | yes | 5 loops since the last retro (loop 26) |
| local-deploy | — | Local deploy + open site | yes | none (CI only): CI runs are the proof |
| smoke | — | Smoke acceptance | yes | checklist in `smoke31.md` |

## Implementation
### Files that change
- Batch 1: `publish-readonly.test.sh` (`readonly_checks` in three groups), `publish-gate.test.sh` (`gate_groups` 14 → 16), `test.yml` (gate jobs, `GITHUB_ACTIONS` into the suite container), `docker-compose.test.yml` if the env needs listing, `run-suite.sh` (one timing notice per suite), `publish-jobs.test.sh`, `run-suite-swift.test.sh`, `run-suite.test.sh`, `scripts/loop-tests.sh` + test (parallel shares read from `test.yml`), `publish-phases.test.sh` split, audit fixes.
- Batch 2: `test.yml` shares and `run-suite.sh` Swift parts moved by the first run's numbers.
### Order of work
1. Readonly split + group count guard + mutants. 2. Suite timing notice + guard. 3. Gate jobs by the best estimate. 4. Mac parallel stage + test, tree manifest proof. 5. publish-phases split. 6. Audit. 7. Owner push go → read annotations → batch 2 → second push → AC-1 median.
### Proof
Group and step counts before/after; one mutant per guard rule; per-job seconds of two CI runs; Mac stage seconds against the sum of its shares.
### Risks
Shares writing into one tree on the Mac; CI variance (1.5x) makes one run no proof.
