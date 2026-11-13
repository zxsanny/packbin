# Autodev Loop Plan — Loop 123

loop: 123
kind: product
confirmed: true
branch: dev
ship: false
origin: agent

Feature: the hygiene queue item (2 Low entries from loop 122): AZ-4279 C++ member folds without nesting (2), AZ-4280 clang install failure message (1). Agent-made loop 3 of 3 in a row: after it, agent-made items wait for the operator's word. Retrospective due (last: loop 118).

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | two specs written at intake |
| decompose-feature | 9.5 | Decompose Feature | no | two tasks of at most 2 points |
| implement | 10 | Implement | yes | parent, serial (both touch the cpp suite path) |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | `scripts/loop-tests.sh`: the stages the changed paths select (cpp, cpp-embedded-arm, ring, scaffold, publish-gate and the language suites through run-suite.sh) |
| test-spec-sync | 12 | Test-Spec Sync | no | no shared vector or blackbox case changes |
| update-docs | 13 | Update Docs | no | gotcha and Makefile comment are part of the tasks |
| security | 14 | Security Audit | yes | `lite`; T1 expected (`run-suite.sh`), so a scoped full audit |
| performance | 15 | Performance Test | no | compile-time change only; the m33f pins are the check |
| deploy | 16 | Deploy | no | no tag |
| release | 16.5 | Release | no | deploy not included |
| migration | 16.7 | Data/Traffic Cutover | no | no data store |
| retrospective | 17 | Retrospective | yes | due by loop 123 (last retro loop 118) |
| local-deploy | — | Local deploy + open site | yes | no site (library): the smoke script |
| smoke | — | Smoke acceptance | yes | `smoke123.md`, `smoke123.sh`, agent run |

## Needs

| need | for | verified by | status |
|------|-----|-------------|--------|
| Docker with `gcc:16`, network for apt | AZ-4279 AC-1/2, AZ-4280 | loop 122 runs | ok |
| host load below about 60 for step 11 | run-tests | `uptime` | re-check |

## Questions ahead
No queue item is left to scan: the rest of the queue is blocked on N1, D9 and a CI failure that has not returned.
