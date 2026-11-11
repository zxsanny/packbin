# Autodev Loop Plan — Loop 108

loop: 108
kind: product
confirmed: true
branch: dev
ship: false

Feature: retrospective of loops 105 to 107 (owner, 2026-11-11: chose "Retro of loops 105-107" for the empty hopper; due by loop 109 per the loop 104 retro). No task, no application source: documents only.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | no feature: a retrospective loop |
| decompose-feature | 9.5 | Decompose Feature | no | no task |
| implement | 10 | Implement | no | no task |
| feature-assess | 10.5 | Feature Assessment | no | `not_in_plan`: no implement pass |
| run-tests | 11 | Run Tests | no | no application source changed |
| test-spec-sync | 12 | Test-Spec Sync | no | no criteria changed |
| update-docs | 13 | Update Docs | no | only if the retro names a rule line |
| security | 14 | Security Audit | no | `not_in_plan`, `trivial:` documents only |
| performance | 15 | Performance Test | no | no code |
| deploy | 16 | Deploy | no | no tag |
| release | 16.5 | Release | no | deploy not included |
| migration | 16.7 | Data/Traffic Cutover | no | no data store |
| retrospective | 17 | Retrospective | yes | the purpose of the loop |
| local-deploy | — | Local deploy + open site | yes | no site: the smoke script checks the documents |
| smoke | — | Smoke acceptance | yes | one paste script, `smoke108.md` |

## Implementation

### Order of work

Collect metrics from the records and git of loops 105 to 107 and the CI runs; write `_docs/06_metrics/retro_2026-11-11_loop108.md` and `structure_2026-11-11_loop108.md`; append lessons to `_docs/LESSONS.md` (ring buffer of 15); smoke; close.

### Proof

The smoke script: the retro and structure files exist, `LESSONS.md` has 15 entries each with a source that exists, the tree has only documents changed.
