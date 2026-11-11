# Autodev Loop Plan — Loop 101

loop: 101
kind: product
confirmed: true
branch: dev
ship: false

Feature: TypeScript refuses dictionary keys that collide after U+FFFD (AZ-4168, 2 points, epic AZ-4133). Plan files: `_docs/02_task_plans/typescript-colliding-dict-keys/`.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done at P0: `/problem`, then `/new-task` (AZ-4168) |
| decompose-feature | 9.5 | Decompose Feature | no | 2 points |
| implement | 10 | Implement | yes | one task, `typescript/` |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | `scripts/loop-tests.sh` with the loop 99 environment |
| test-spec-sync | 12 | Test-Spec Sync | no | TC-1 to TC-5 are one row in the loop 100 matrix style: added to the loop's matrix file in step 13 |
| update-docs | 13 | Update Docs | yes | README Dart notes, parity row 43, traceability AL-3, TypeScript component doc |
| security | 14 | Security Audit | yes | `lite`: a pack-side check on caller input, no wire change |
| performance | 15 | Performance Test | no | one neighbour comparison inside an existing sort |
| deploy | 16 | Deploy | no | no tag |
| release | 16.5 | Release | no | deploy not included |
| migration | 16.7 | Data/Traffic Cutover | no | no data store |
| retrospective | 17 | Retrospective | no | complexity 2, no incident; the loop 100 retro is current (next due by loop 104) |
| local-deploy | — | Local deploy + open site | yes | no site: the smoke script runs the TypeScript suite and the cross-language check |
| smoke | — | Smoke acceptance | yes | one paste script, `smoke101.md` |

## Implementation

### Order of work

One check in `typescript/src/pack-fields.ts`, tests in `typescript/tests/`, then docs. One total review and one step-11 run.

### Proof

The 7 cases of the results report in TypeScript and in Dart; the seeded random check; the TypeScript suite; the shared fixtures and rings.

### Risks

An exact-equal check on encoded keys must run after the sort so neighbours are adjacent; keys that are equal as strings cannot occur (object keys are unique).
