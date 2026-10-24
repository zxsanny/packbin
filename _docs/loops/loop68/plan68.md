# Autodev Loop Plan — Loop 68

loop: 68
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | P0 `/problem` then `/new-task` done (AZ-3189) |
| decompose-feature | 9.5 | Decompose Feature | no | 3 points |
| implement | 10 | Implement | yes | AZ-3189 |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | one `scripts/loop-tests.sh` run |
| test-spec-sync | 12 | Test-Spec Sync | no | no project AC changes |
| update-docs | 13 | Update Docs | no | notes ride in AC-9 of the task |
| security | 14 | Security Audit | no | no untrusted-input surface |
| performance | 15 | Performance Test | no | no latency NFR |
| deploy | 16 | Deploy | no | not a ship loop |
| release | 16.5 | Release | no | — |
| migration | 16.7 | Data/Traffic Cutover | no | — |
| retrospective | 17 | Retrospective | yes | owner rule: retro due after loop 68 (loops 64 to 68); decide at close |
| local-deploy | — | Local deploy + open site | yes | always at close |
| smoke | — | Smoke acceptance | yes | always at close |

## Implementation

Prototype measured in a scratch tree (loop 68 start): code at 0x10000000, RAM at 0x38000000, flash 25,720 B, raw stack pack 636 B / unpack 788 B. Implement in `cpp/embedded`, then the arm stage and `run-parts.test.sh`.
