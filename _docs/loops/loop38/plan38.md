# Autodev Loop Plan — Loop 38

loop: 38
kind: product
confirmed: true
branch: dev
ship: false

Intake: owner (2026-10-18) chose option A of the loop 38 handoff (CRC for the whole message) and widened it: a configurable number of parity bytes with error correction. Decisions 1 to 5 and the code area are in `_docs/02_task_plans/message-error-correction/problem.md`; scope "full correction now" (57 points, epic AZ-2677, tasks AZ-2678 to AZ-2690).

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done at intake; 13 points handed to decompose |
| decompose-feature | 9.5 | Decompose Feature | yes | done: 13 tasks, 57 points |
| implement | 10 | Implement | yes | waves below |
| feature-assess | 10.5 | Feature Assessment | no | owner-run skill (memory: one total review and test) |
| run-tests | 11 | Run Tests | yes | one run for the loop |
| test-spec-sync | 12 | Test-Spec Sync | yes | new ACs EC-1..EC-17 |
| update-docs | 13 | Update Docs | no | AZ-2690 covers the docs |
| security | 14 | Security Audit | no | owner-run (AZ-2666); new decoders noted in AZ-2690 |
| performance | 15 | Performance Test | no | speed bounds are ACs in the package tasks |
| deploy | 16 | Deploy | no | ship false |
| release | 16.5 | Release | no | — |
| migration | 16.7 | Data/Traffic Cutover | no | — |
| retrospective | 17 | Retrospective | no | owner-run |
| local-deploy | — | Local deploy + open site | yes | always at close |
| smoke | — | Smoke acceptance | yes | always at close |

## Waves

1. AZ-2678 then AZ-2679 (serial: contract, then reference and vectors).
2. AZ-2680 to AZ-2687 (up to 4 workers at a time, disjoint folders per package; the shared fixture files are read-only for them).
3. AZ-2688, then AZ-2689, then AZ-2690.

## Implementation

## Assessment rounds
