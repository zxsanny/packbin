# Autodev Loop Plan — Loop 66

loop: 66
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done: `AZ-PENDING_publish_gate_load_aware.md` in `todo/` |
| decompose-feature | 9.5 | Decompose Feature | no | 3 points |
| implement | 10 | Implement | yes | two test-support edits |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | `--groups go`, `--groups phases`, one full gate |
| test-spec-sync | 12 | Test-Spec Sync | no | no product AC changed |
| update-docs | 13 | Update Docs | no | no public contract changed |
| security | 14 | Security Audit | no | no auth, secret or exposure change |
| performance | 15 | Performance Test | no | no perf NFR |
| deploy | 16 | Deploy | no | not a ship loop |
| release | 16.5 | Release | no | no deploy |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | next after loop 68 |
| local-deploy | — | Local deploy + open site | yes | no app: smoke is the gate runs |
| smoke | — | Smoke acceptance | yes | mandatory |
