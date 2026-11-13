# Autodev Loop Plan — Loop 121

loop: 121
kind: product
confirmed: true
branch: dev
ship: false
origin: agent

Feature: the hygiene queue item (8 agent-found entries, none above Medium, no packet change), as five tasks of 14 points: AZ-4257 Java (3), AZ-4258 Python (2), AZ-4259 C# and Go (3), AZ-4260 Dart (1), AZ-4261 C++ (5). Agent-made loop 1 of 3 in a row (loops 118 to 120 were operator-made or the high item; the counter reads 0/3 before this loop).

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | five specs written at intake from the entries |
| decompose-feature | 9.5 | Decompose Feature | no | the entries are already independent tasks of at most 5 points |
| implement | 10 | Implement | yes | wave 1: four workers on disjoint directories (java, python, csharp + go, dart); wave 2: one C++ worker (cpp/build is shared); parent reviews every report against the tree, builds nothing shared |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | one `scripts/loop-tests.sh` run: the stages the changed paths select (java, python, csharp, go, dart, cpp, cpp-embedded-arm, ring, publish-gate, scaffold) |
| test-spec-sync | 12 | Test-Spec Sync | no | no shared vector or blackbox case changes |
| update-docs | 13 | Update Docs | no | README lines are in the tasks |
| security | 14 | Security Audit | yes | `lite`; T1 expected (CI workflow job `embedded-esp-core`, a tool pin), so a scoped full audit |
| performance | 15 | Performance Test | no | the memo tasks carry their own timing tests |
| deploy | 16 | Deploy | no | no tag |
| release | 16.5 | Release | no | deploy not included |
| migration | 16.7 | Data/Traffic Cutover | no | no data store |
| retrospective | 17 | Retrospective | no | done in loop 118; next due by loop 123 |
| local-deploy | — | Local deploy + open site | yes | no site (library): the smoke script |
| smoke | — | Smoke acceptance | yes | `smoke121.md`, `smoke121.sh`, agent run |

## Needs

| need | for | verified by | status |
|------|-----|-------------|--------|
| Docker with the suite images (`golang:1.27`, `gcc:16`, `dart:3.13.7`, `packbin-embedded:local`, `espressif/idf:v5.3.2`) | Go and Dart suites, C++ embedded rows, ESP core stage | `docker info`, `docker images` | check before wave 2 |
| outbound network for the ESP core pin check (the stage downloads the core) | AZ-4261 AC `esp core` | the run itself | check at wave 2 |
| host load below about 6 for step 11; Mac awake | run-tests, smoke | `uptime` | re-check before step 11 |

## Questions ahead
No queue item is left to scan: the queue holds only blocked items (N1, D9, a CI failure that has not returned).
