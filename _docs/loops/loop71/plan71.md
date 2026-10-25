# Autodev Loop Plan — Loop 71

loop: 71
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done at P0 (feature-description, 17 points) |
| decompose-feature | 9.5 | Decompose Feature | yes | done: AZ-3232, AZ-3233, AZ-3234, AZ-3235 |
| implement | 10 | Implement | yes | AZ-3232..AZ-3235; three package workers on disjoint trees, parent does docs |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | one total run (owner rule 2026-10-06) |
| test-spec-sync | 12 | Test-Spec Sync | yes | new ACs and tests in three packages |
| update-docs | 13 | Update Docs | no | AZ-3235 is the docs task, done inside implement |
| security | 14 | Security Audit | yes | authentication and untrusted input (tag check, replay) in three more packages |
| performance | 15 | Performance Test | no | no perf NFR |
| deploy | 16 | Deploy | no | ship false |
| release | 16.5 | Release | no | — |
| migration | 16.7 | Data/Traffic Cutover | no | — |
| retrospective | 17 | Retrospective | no | next after loop 73 |
| local-deploy | — | Local deploy + open site | yes | always at close; library, no UI: the suite run is the deploy |
| smoke | — | Smoke acceptance | yes | always at close; agent-run script (owner rule 2026-10-12) |

## Implementation

### Files that change
- `csharp/` + `csharp/tests/` (AZ-3232), `java/` + `java/test.sh` (AZ-3233), `swift/Sources`, `swift/Tests` (AZ-3234): disjoint trees, one worker each.
- Parent: README, `_docs/02_document/` (AZ-3235), state, commits.

### Order of work
1. Three workers in parallel (C#, Java, Swift), each runs only its own package suite.
2. Parent reviews diffs, runs docs task, one batch commit.
3. Feature assessment, one total step 11 run, security review, test-spec sync, smoke, close.
