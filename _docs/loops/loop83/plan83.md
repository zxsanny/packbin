# Autodev Loop Plan - Loop 83

loop: 83
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done: AZ-3387, AZ-3388, AZ-3389 in `todo/` |
| decompose-feature | 9.5 | Decompose Feature | no | three tasks of 3 points each |
| implement | 10 | Implement | yes | one batch, three workers on disjoint paths (T1 driver, T2 module, T3 rows) |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | always |
| test-spec-sync | 12 | Test-Spec Sync | no | no product AC or scenario of the blackbox spec changed |
| update-docs | 13 | Update Docs | no | no public contract or module doc changed (fixtures README line is part of AZ-3389) |
| security | 14 | Security Audit | no | no auth, secret or untrusted input; last report not due (3-point, non-ship loop) |
| performance | 15 | Performance Test | no | no perf NFR |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no deploy |
| migration | 16.7 | Data/Traffic Cutover | no | no data store |
| retrospective | 17 | Retrospective | no | complexity 3, last retro loop 79 (4 loops) |
| local-deploy | - | Local deploy + open site | yes | always at close; no app: the stages the touched scripts belong to |
| smoke | - | Smoke acceptance | yes | always at close |

## Implementation

Order: T2 and T3 and T1 start together (disjoint). T3's sensitivity run (AC-4) uses a scratch copy; no worker touches git. A C++ driver edit by T3 is not allowed (T1 owns it).
