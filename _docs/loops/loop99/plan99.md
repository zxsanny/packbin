# Autodev Loop Plan — Loop 99

loop: 99
kind: product
confirmed: true
branch: dev
ship: false

Feature: the Dart package, full parity (epic AZ-4133; 15 tasks AZ-4134 to AZ-4148, 61 points). Plan files: `_docs/02_task_plans/dart-package/`.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done at P0: `/problem`, then the handoff to decompose |
| decompose-feature | 9.5 | Decompose Feature | yes | 13 points or more: done at intake, 15 specs in `todo/` |
| implement | 10 | Implement | yes | 15 tasks in 7 waves (`task_map.md`) |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | `scripts/loop-tests.sh --all` with the new `dart` stage |
| test-spec-sync | 12 | Test-Spec Sync | yes | 20 new criteria (DT-1 to DT-20) |
| update-docs | 13 | Update Docs | yes | a new component; most of it is task AZ-4148, step 13 checks the rest |
| security | 14 | Security Audit | yes | full: untrusted input, hand-written crypto, CI and publish files, a new toolchain image |
| performance | 15 | Performance Test | no | the speed bound (DT-8) runs inside the Dart suite |
| deploy | 16 | Deploy | no | no tag and no publish in this loop |
| release | 16.5 | Release | no | deploy not included |
| migration | 16.7 | Data/Traffic Cutover | no | no data store |
| retrospective | 17 | Retrospective | yes | complexity above 5 |
| local-deploy | — | Local deploy + open site | yes | no site: the smoke script runs the Dart suite, the rings and the dry run |
| smoke | — | Smoke acceptance | yes | one paste script, `smoke99.md` |

## Implementation

### Order of work

Waves as in `task_map.md` § Waves. One worker at a time in the walker files of `dart/lib/`; standalone modules and shared CI files in parallel with disjoint file sets. One total review and one step-11 run for the loop (no per-batch review or test run beyond each task's own tests).

### Proof

Each task's own Dart tests on the shared fixtures; the Dart suite in its container; the three rings with Dart; the publish gate tests; `dart pub publish --dry-run`.

### Risks

- pub.dev's publishing mechanism (first publish by hand, OIDC from a tag run): AZ-4147 reads the documentation first and stops if the release run cannot meet it.
- The ring is the longest CI job; a ninth member adds to it.
- `run-suite.sh` and other shared scripts are near the 500-line cap.
