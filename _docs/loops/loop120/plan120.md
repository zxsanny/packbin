# Autodev Loop Plan — Loop 120

loop: 120
kind: product
confirmed: true
branch: dev
ship: false
origin: operator

Feature: AZ-4255 (2 points). Java unpack refuses, with the package's own error, a list or dict setter that rejects the `ArrayList` / `LinkedHashMap` it is given (owner decision D12 B).

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | spec written at intake |
| decompose-feature | 9.5 | Decompose Feature | no | 2 points |
| implement | 10 | Implement | yes | parent, one batch (code written before the intake files; reported in the batch report) |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | `scripts/loop-tests.sh`: `java`, `ring`, `publish-gate` (README) |
| test-spec-sync | 12 | Test-Spec Sync | no | no shared vector or blackbox case changes |
| update-docs | 13 | Update Docs | no | the README Java section is part of the task |
| security | 14 | Security Audit | yes | `lite` on the real diff |
| performance | 15 | Performance Test | no | one try/catch on the unpack path of a list or dict |
| deploy | 16 | Deploy | no | no tag |
| release | 16.5 | Release | no | deploy not included |
| migration | 16.7 | Data/Traffic Cutover | no | no data store |
| retrospective | 17 | Retrospective | no | done in loop 118; next due by loop 123 |
| local-deploy | — | Local deploy + open site | yes | no site (library): the smoke script |
| smoke | — | Smoke acceptance | yes | `smoke120.md`, `smoke120.sh`, agent run |

## Needs
none (JDK on this Mac: loop 119 ran it).
