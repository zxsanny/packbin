# Autodev Loop Plan — Loop 127

loop: 127
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | hygiene queue item, three task specs written from its entries (AZ-4306 to AZ-4308) |
| decompose-feature | 9.5 | Decompose Feature | no | 9 points in three tasks, written directly |
| implement | 10 | Implement | yes | four workers, disjoint package folders: A TypeScript + Python + Java, B Dart + Swift, C C# + Go, D Rust |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | one total `scripts/loop-tests.sh` run |
| test-spec-sync | 12 | Test-Spec Sync | no | no AC changed |
| update-docs | 13 | Update Docs | no | contract unchanged (D20 open) |
| security | 14 | Security Audit | yes | lite: a depth-check change in nine packages (T3), the Rust nostd check |
| performance | 15 | Performance Test | no | the new tests carry the figures |
| deploy | 16 | Deploy | no | no ship intent |
| release | 16.5 | Release | no | no deploy |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | routine loop (retro due by loop 128) |
| local-deploy | — | Local deploy | yes | library: the close runs the probe and the smoke script |
| smoke | — | Smoke acceptance | yes | `smoke127.sh`, agent-verified |

## Needs

none (toolchains as loop 126).
