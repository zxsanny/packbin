# Autodev Loop Plan — Loop 37

loop: 37
kind: product
confirmed: true
branch: dev
ship: false

Intake: owner (2026-10-18) chose "Review Lows cleanup"; findings 7 and 8 accepted with no code. Tickets AZ-2674, AZ-2675, AZ-2676 (epic AZ-2645).

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done in P0 |
| decompose-feature | 9.5 | Decompose Feature | no | 6 points, three small tasks |
| implement | 10 | Implement | yes | AZ-2674 (C++ flag), AZ-2675 (C# split), AZ-2676 (bench.py) |
| feature-assess | 10.5 | Feature Assessment | no | owner-run skill, carried |
| run-tests | 11 | Run Tests | yes | cpp, csharp stages of `scripts/loop-tests.sh`, bench run |
| test-spec-sync | 12 | Test-Spec Sync | no | no new behavior |
| update-docs | 13 | Update Docs | no | README line inside AZ-2674 |
| security | 14 | Security Audit | no | no untrusted input touched |
| performance | 15 | Performance Test | no | none |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no tag |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | owner-run skill, carried |
| local-deploy | — | Local deploy + open site | yes | none (library; CI is the proof) |
| smoke | — | Smoke acceptance | yes | script in `smoke37.md` |

## Implementation
### Files that change
- `cpp/Makefile`, a check script under `cpp/tests/`, comment in `cpp/include/packbin/core.hpp`, README C++ section.
- `csharp/tests/CompactTextTests*.cs`.
- `_docs/02_task_plans/compact-strings/research/bench*.py`.
### Order of work
Three disjoint tasks, run in parallel by subagents (parent keeps commits): AZ-2674, AZ-2675, AZ-2676; then step 11, smoke, close, push.
### Proof
Flag check with a mutant; equal C# test count; identical bench table.
### Risks
Flash 60 B and stack 20 B margins: only a comment in `cpp/include`. The frame limit must clear the largest legitimate test frame.
