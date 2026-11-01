# Autodev Loop Plan - Loop 98

loop: 98
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | P0 intake done; three specs written (AZ-3524, AZ-3525, AZ-3526) |
| decompose-feature | 9.5 | Decompose Feature | no | 8 points in three tasks, each at most 3; split done in new-task |
| implement | 10 | Implement | yes | AZ-3524 docs; AZ-3525 C++ device run; AZ-3526 Rust device run (disjoint files) |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | go vet, host suites, embedded stages |
| test-spec-sync | 12 | Test-Spec Sync | yes | new device test scenarios close Open 1 of the loop 97 traceability matrix |
| update-docs | 13 | Update Docs | no | no contract or API change; the task is the docs |
| security | 14 | Security Audit | no | no auth, secret, network or untrusted-input change; lite pass at close as in loop 97 |
| performance | 15 | Performance Test | no | no perf NFR |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no deploy |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | 1 loop since the loop 97 retro, complexity below 5, no incident |
| local-deploy | - | Local deploy + open site | yes | at close; library: no local site |
| smoke | - | Smoke acceptance | yes | at close |
