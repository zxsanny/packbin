# Autodev Loop Plan — Loop 122

loop: 122
kind: product
confirmed: true
branch: dev
ship: false
origin: agent

Feature: the hygiene queue item (2 agent-found entries, none above Medium, no packet change), run because nothing else in the queue is ready: AZ-4277 Dart cost test best of three (1), AZ-4278 C++ sanitizer CI job (3). Agent-made loop 2 of 3 in a row (loop 121 was the first).

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | two specs written at intake from the entries |
| decompose-feature | 9.5 | Decompose Feature | no | two tasks of at most 3 points |
| implement | 10 | Implement | yes | parent, serial: Dart first (one test file), then the C++ job (workflow, compose, pins, checkers) |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | `scripts/loop-tests.sh`: the stages the changed paths select (dart; the workflow checker stages for `.github/workflows/`), plus the new compose service |
| test-spec-sync | 12 | Test-Spec Sync | no | no shared vector or blackbox case changes |
| update-docs | 13 | Update Docs | no | `ci_cd_pipeline.md` job list line and the timing gotcha are part of the tasks |
| security | 14 | Security Audit | yes | `lite`; T1 expected (a CI workflow job, a compose service, an apt install), so a scoped full audit if it escalates |
| performance | 15 | Performance Test | no | the Dart task is its own timing check |
| deploy | 16 | Deploy | no | no tag |
| release | 16.5 | Release | no | deploy not included |
| migration | 16.7 | Data/Traffic Cutover | no | no data store |
| retrospective | 17 | Retrospective | no | due by loop 123; run at the next loop |
| local-deploy | — | Local deploy + open site | yes | no site (library): the smoke script |
| smoke | — | Smoke acceptance | yes | `smoke122.md`, `smoke122.sh`, agent run |

## Needs

| need | for | verified by | status |
|------|-----|-------------|--------|
| Docker with `gcc:16` and `dart:3.13.7` images | Dart suite, the sanitizer service | `docker images` | ok (gcc:16 ran 2026-11-13) |
| outbound network from containers (apt for clang-19) | AZ-4278 AC-2 locally | `apt-cache policy clang-19` in gcc:16 printed 1:19.1.7-3+b1 | ok |
| host load below about 6 for step 11; Mac awake | run-tests, smoke | `uptime` (25.7 at intake) | re-check before step 11 |
| `gh` logged in | AZ-4278 AC-1 (read the job's runs) | `gh auth status` | check at close |

## Questions ahead
No queue item is left to scan: the queue holds only blocked items (N1, D9, a CI failure that has not returned).
