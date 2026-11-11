# Autodev Loop Plan — Loop 109

loop: 109
kind: product
confirmed: true
branch: dev
ship: false

Feature: AZ-4198, find why the embedded-arm image build could not resolve names on the runner (owner, 2026-11-11: chose "Embedded-arm DNS cause" for the empty hopper). One new manual workflow, a findings document, comments in `run.sh` and the `Dockerfile`; no application source.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done: AZ-4198 in `todo/` |
| decompose-feature | 9.5 | Decompose Feature | no | 3 points, one task |
| implement | 10 | Implement | yes | the diagnostic workflow, the runs, the findings, the comments |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | scoped: the workflow structure and embedded self-tests; the full `loop-tests.sh` stages do not read the files changed (no application source) |
| test-spec-sync | 12 | Test-Spec Sync | no | no criteria of the project changed |
| update-docs | 13 | Update Docs | no | no public contract or module doc |
| security | 14 | Security Audit | yes | `lite`: a workflow file (CI config) is a sensitive path |
| performance | 15 | Performance Test | no | no code |
| deploy | 16 | Deploy | no | no tag |
| release | 16.5 | Release | no | deploy not included |
| migration | 16.7 | Data/Traffic Cutover | no | no data store |
| retrospective | 17 | Retrospective | no | next due by loop 113 |
| local-deploy | — | Local deploy + open site | yes | no site: the smoke script checks files and the final `dev` run |
| smoke | — | Smoke acceptance | yes | one paste script, `smoke109.md`, agent run |

## Implementation

### Files that change
- new `.github/workflows/diagnose-dns.yml`
- new `_docs/06_metrics/embedded-arm-dns_2026-11-11.md`
- `cpp/embedded/run.sh`, `cpp/embedded/Dockerfile` (comments, or the build line if the findings replace the workaround)

### Order of work
1. Write the workflow; run the structure checks (pins, permissions); push `dev`; dispatch it; read the log with `gh api` while it runs.
2. If no failure shows, dispatch once more at another time; stop after two runs unless a failure shows.
3. Write the findings; update the comments; push; read the CI run of that push.

### Proof
Smoke script: findings file exists; quoted lines exist in the saved logs; diff paths; `dev` run 20 of 20.

### Risks
The fault may not reproduce (findings then say so). A workflow must be on the default branch (`dev`) to be dispatched, so one push precedes the first run.
