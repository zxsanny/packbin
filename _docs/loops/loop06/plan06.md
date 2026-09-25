# Autodev Loop Plan — Loop 6

loop: 6
kind: product
confirmed: true
branch: loop/6-python-single-accessor
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | Done in P0. Spec AZ-1963 is in todo. |
| decompose-feature | 9.5 | Decompose Feature | no | 3 points. One task. |
| implement | 10 | Implement | yes | AZ-1963 |
| feature-assess | 10.5 | Feature Assessment | yes | After implement |
| run-tests | 11 | Run Tests | yes | Always |
| test-spec-sync | 12 | Test-Spec Sync | yes | New ACs and scenarios |
| update-docs | 13 | Update Docs | yes | Python field contract and module layout |
| security | 14 | Security Audit | no | No auth, secrets, or untrusted-input scope. 3 points, not a ship loop. |
| performance | 15 | Performance Test | no | No latency or throughput NFR |
| deploy | 16 | Deploy | no | Not a ship loop |
| release | 16.5 | Release | no | Deploy not included |
| migration | 16.7 | Data/Traffic Cutover | no | No schema or traffic cut |
| retrospective | 17 | Retrospective | no | 3 points, no incident, retro ran in loop 4 |
| local-deploy | — | Local deploy + open site | yes | Loop close |
| smoke | — | Smoke acceptance | yes | Loop close |

## Implementation

### Files that change
### Order of work
### Proof
### Risks
