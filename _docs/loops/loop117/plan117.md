# Autodev Loop Plan — Loop 117

loop: 117
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | queue item seeded `problem.md`; spec written from it (2 points) |
| decompose-feature | 9.5 | Decompose Feature | no | 2 points |
| implement | 10 | Implement | yes | AZ-4243 by the parent (one function, its tests, one paragraph) |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | `scripts/loop-tests.sh` (`scaffold` covers `scripts/`) |
| test-spec-sync | 12 | Test-Spec Sync | no | no product AC changed |
| update-docs | 13 | Update Docs | no | the procedure paragraph is part of the task (AC-5) |
| security | 14 | Security Audit | no | trivial: one line of a local test runner and its test, no package, CI, compose or deploy file, no dependency |
| performance | 15 | Performance Test | no | none |
| deploy | 16 | Deploy | no | no ship intent |
| release | 16.5 | Release | no | no deploy |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | routine loop (retro due by loop 118) |
| local-deploy | — | Local deploy + open site | yes | library: the close runs the smoke script |
| smoke | — | Smoke acceptance | yes | `smoke117.sh`, agent-verified |

## Needs

none
