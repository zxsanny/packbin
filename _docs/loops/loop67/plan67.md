# Autodev Loop Plan — Loop 67

loop: 67
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | P0 `/problem` then `/new-task` done (AZ-3185) |
| decompose-feature | 9.5 | Decompose Feature | no | 3 points |
| implement | 10 | Implement | yes | AZ-3185 |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | one `scripts/loop-tests.sh` run |
| test-spec-sync | 12 | Test-Spec Sync | no | no AC or scenario of the project changes |
| update-docs | 13 | Update Docs | no | C++ description note rides in AC-5 of the task |
| security | 14 | Security Audit | no | no untrusted-input surface changes; unpack is behavior-preserving (AC-3) |
| performance | 15 | Performance Test | no | no latency NFR |
| deploy | 16 | Deploy | no | not a ship loop |
| release | 16.5 | Release | no | — |
| migration | 16.7 | Data/Traffic Cutover | no | — |
| retrospective | 17 | Retrospective | no | next after loop 68 |
| local-deploy | — | Local deploy + open site | yes | always at close |
| smoke | — | Smoke acceptance | yes | always at close |

## Implementation

Measure shapes on a tree copy under the scratchpad first (arm embedded stage per shape, about 3 minutes each); apply the winner to the tree, or record the no-go table (AC-6).
