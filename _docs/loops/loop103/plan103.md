# Autodev Loop Plan — Loop 103

loop: 103
kind: product
confirmed: true
branch: dev
ship: false

Feature: C# and Java refuse colliding dictionary keys; Java writes U+FFFD (AZ-4169, 5 points, epic AZ-4133). Plan files: `_docs/02_task_plans/csharp-java-lone-surrogate-keys/`.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done at P0: `/problem`, then `/new-task` (AZ-4169) |
| decompose-feature | 9.5 | Decompose Feature | no | 5 points, one task over two small packages |
| implement | 10 | Implement | yes | C# then Java |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | `scripts/loop-tests.sh` with the loop 99 environment (csharp, java, ring, publish-gate) |
| test-spec-sync | 12 | Test-Spec Sync | no | CJ-1 to CJ-7 mirror TC-1 to TC-5: one traceability row set in step 13 |
| update-docs | 13 | Update Docs | yes | README, findings, C# and Java component docs |
| security | 14 | Security Audit | yes | `lite` |
| performance | 15 | Performance Test | no | one neighbour comparison; Java encodes each key once |
| deploy | 16 | Deploy | no | no tag |
| release | 16.5 | Release | no | deploy not included |
| migration | 16.7 | Data/Traffic Cutover | no | no data store |
| retrospective | 17 | Retrospective | no | complexity 5 but no incident; the loop 100 retro is current (next due by loop 104): run it if loop 104 starts |
| local-deploy | — | Local deploy + open site | yes | no site: the smoke script runs the C# and Java suites and the four-package check |
| smoke | — | Smoke acceptance | yes | one paste script, `smoke103.md` |

## Implementation

### Order of work

C# first (one check), then Java (a helper that writes U+FFFD, the key sort on precomputed bytes, the check). Tests per package, then the four-package differential, then docs. One total review and one step-11 run.

### Proof

The 5,000 seeded dictionaries of loop 101 and the 7 report cases packed by C#, Java, TypeScript and Dart; the C# and Java suites; the shared fixtures and rings.

### Risks

A third Java encoder call; Android API level; the C# build needs `MSBUILDDISABLENODEREUSE=1`.
