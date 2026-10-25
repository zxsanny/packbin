# Autodev Loop Plan — Loop 70

loop: 70
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done at P0 (AZ-3231) |
| decompose-feature | 9.5 | Decompose Feature | no | 3 points |
| implement | 10 | Implement | yes | AZ-3231 |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | always |
| test-spec-sync | 12 | Test-Spec Sync | yes | AC-9 notes in tests.md (new AC set) |
| update-docs | 13 | Update Docs | yes | Rust description and README |
| security | 14 | Security Audit | no | no auth, secrets or untrusted input touched; last audit loop 69 |
| performance | 15 | Performance Test | no | no perf NFR |
| deploy | 16 | Deploy | no | ship false |
| release | 16.5 | Release | no | — |
| migration | 16.7 | Data/Traffic Cutover | no | — |
| retrospective | 17 | Retrospective | no | retro 64-68 done in loop 69; next after loop 73 |
| local-deploy | — | Local deploy + open site | yes | always at close; no UI, no local server: the stage run is the deploy |
| smoke | — | Smoke acceptance | yes | always at close; agent-run script (owner rule 2026-10-12) |
