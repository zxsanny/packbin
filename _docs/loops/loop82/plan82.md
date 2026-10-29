# Autodev Loop Plan — Loop 82

loop: 82
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done: P0 `/problem` then `/new-task` (8 points, handed to decompose) |
| decompose-feature | 9.5 | Decompose Feature | yes | done: 6 tasks AZ-3381 to AZ-3386 (28 points) |
| implement | 10 | Implement | yes | six tasks; AZ-3381 and AZ-3382 first, then AZ-3383, AZ-3384, AZ-3385, last AZ-3386 |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | always |
| test-spec-sync | 12 | Test-Spec Sync | no | project ACs unchanged; the loop's ACs live in the task specs |
| update-docs | 13 | Update Docs | no | the two documents that named Ruby are edited by AZ-3386 (AC-5) |
| security | 14 | Security Audit | yes | release-path script and an `if:` evaluator on untrusted-shaped text; diff-scoped lite |
| performance | 15 | Performance Test | no | no latency NFR |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no deploy |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | not due (next after loop 84) |
| local-deploy | — | Local deploy + open site | yes | always at close (no site: the scripts are the surface) |
| smoke | — | Smoke acceptance | yes | always at close; user checklist in `smoke82.md` |

Only rows with `include: yes` are executed (plus close steps).

## Implementation

### Files that change
`.github/workflows/`: `publish-precheck.sh`, `publish-precheck.test.sh`, `publish-workflow.test.sh`, `ring-wiring.test.sh`, `ring-wiring-swift.test.sh`, `publish-jobs.test.sh` (+ split files), `publish-pins.test.sh`, `report-row.test.sh`, `run-suite.test.sh`, `run-suite-swift.test.sh`, `test.yml`, `tool-pins.txt`; a new shared reader under `scripts/ci/`; `_docs/02_document/module-layout.md`, `_docs/02_document/deployment/ci_cd_pipeline.md`.

### Order of work
AZ-3381 (reader, pin, one-liners) and AZ-3382 (precheck) first; AZ-3383, AZ-3384, AZ-3385 on the reader (disjoint files); AZ-3386 last (guard, docs, push).

### Proof
Each script green on this host (no Ruby) and failing on one mutation; CI of the push green on `dev` and `main`, with the six formerly unrun scripts PASS.

### Risks
Release-path precheck (High); first CI run of six scripts.
