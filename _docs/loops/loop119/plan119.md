# Autodev Loop Plan — Loop 119

loop: 119
kind: product
confirmed: true
branch: dev
ship: false
origin: operator

Feature: AZ-4253 (3 points). Java refuses at build an element-row or nested-row member declared for another row class (owner decision D10 A; mechanism D13 A applied: accessors called once on a fresh child from the group's factory).

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | spec written at intake |
| decompose-feature | 9.5 | Decompose Feature | no | 3 points |
| implement | 10 | Implement | yes | parent, one batch |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | `scripts/loop-tests.sh`: `java`, `ring`, `publish-gate` (README) as selected |
| test-spec-sync | 12 | Test-Spec Sync | no | no shared vector or blackbox case changes |
| update-docs | 13 | Update Docs | no | the README Java section is in the task (AC-7); no contract or component doc changes |
| security | 14 | Security Audit | yes | `lite` on the real diff |
| performance | 15 | Performance Test | no | build-time only, one call per member |
| deploy | 16 | Deploy | no | no tag |
| release | 16.5 | Release | no | deploy not included |
| migration | 16.7 | Data/Traffic Cutover | no | no data store |
| retrospective | 17 | Retrospective | no | done in loop 118; next due by loop 123 |
| local-deploy | — | Local deploy + open site | yes | no site (library): the smoke script |
| smoke | — | Smoke acceptance | yes | `smoke119.md`, `smoke119.sh`, agent run |

## Needs

| need | for | verified by | status |
|------|-----|-------------|--------|
| JDK and the Java build of this Mac (the probe and the suite) | implement, run-tests | loop 118 probe ran Java on this host | ok |

## Questions ahead

Scanned 2026-11-13: `java-unpack-declared-collection-type` (decided D12: B) and `hygiene` (agent-found items, each with its source): no new question.
