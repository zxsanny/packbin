# Autodev Loop Plan — Loop 100

loop: 100
kind: product
confirmed: true
branch: dev
ship: false

Feature: Dart aligned with TypeScript (AZ-4153, 5 points, epic AZ-4133). Plan files: `_docs/02_task_plans/dart-typescript-alignment/`. Spec: `_docs/02_tasks/todo/AZ-4153_dart_typescript_alignment.md`.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done at P0: `/problem`, then `/new-task` (AZ-4153) |
| decompose-feature | 9.5 | Decompose Feature | no | 5 points, one task |
| implement | 10 | Implement | yes | one task, one component (`dart/`) |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | `scripts/loop-tests.sh --only dart,ring` plus the shared-fixture stages |
| test-spec-sync | 12 | Test-Spec Sync | yes | ACs AL-1 to AL-10 amend DT-3, DT-4, DT-12 |
| update-docs | 13 | Update Docs | yes | README, hostile README, parity rows, two contract change-log lines |
| security | 14 | Security Audit | yes | `lite`: unpack of untrusted text and keys changes its error value; escalates on its triggers |
| performance | 15 | Performance Test | no | the speed bound runs inside the Dart suite |
| deploy | 16 | Deploy | no | no tag, no publish |
| release | 16.5 | Release | no | deploy not included |
| migration | 16.7 | Data/Traffic Cutover | no | no data store |
| retrospective | 17 | Retrospective | yes | complexity 5 |
| local-deploy | — | Local deploy + open site | yes | no site: the smoke script runs the Dart suite, the rings and the TypeScript probes |
| smoke | — | Smoke acceptance | yes | one paste script, `smoke100.md` |

## Implementation

### Order of work

One worker in `dart/lib/` (the walker files are shared by D1, D6, D8, D10), tests and docs after the code. Order: D8 (smallest change, pins the short-read shape), D7, D1 with the key sort, D6, D10. One total review and one step-11 run for the loop.

### Proof

The TypeScript probes of the session re-run against Dart give equal hex and equal results; the Dart suite; the shared fixtures; the ECC and frame rings with Dart.

### Risks

Key sort after the U+FFFD swap; the 11 tests that pin the old shape; `parity_doc_test.dart` rejects a row that names a removed test.
