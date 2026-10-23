# Autodev Loop Plan — Loop 64

loop: 64
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | short loop, no code: problem and ACs at P0 (`_docs/02_task_plans/retro-loops-61-63/`), no task spec |
| decompose-feature | 9.5 | Decompose Feature | no | no task |
| implement | 10 | Implement | no | no source change |
| feature-assess | 10.5 | Feature Assessment | no | no source change; the report is checked by `smoke64.sh` against AC-1 to AC-6 |
| run-tests | 11 | Run Tests | yes | `scripts/loop-tests.sh` once: expected 14 stages skipped as unchanged (no source change) |
| test-spec-sync | 12 | Test-Spec Sync | no | no AC or scenario change to the product |
| update-docs | 13 | Update Docs | no | `LESSONS.md` and `AGENT_GOTCHAS.md` are written by the retrospective itself |
| security | 14 | Security Audit | no | no input, auth or exposure change |
| performance | 15 | Performance Test | no | no perf NFR |
| deploy | 16 | Deploy | no | not a ship loop |
| release | 16.5 | Release | no | — |
| migration | 16.7 | Data/Traffic Cutover | no | — |
| retrospective | 17 | Retrospective | yes | the loop's work: loops 61 to 63, on-demand mode |
| local-deploy | — | Local deploy + open site | yes | none: a library |
| smoke | — | Smoke acceptance | yes | `smoke64.sh`, agent run (owner rule 2026-10-12) |

## Implementation

### Files that change
`_docs/06_metrics/retro_2026-10-23_loop64.md`, `_docs/LESSONS.md`, `_docs/AGENT_GOTCHAS.md` (only for a repeat), the loop 64 folder.
### Order of work
Collect metrics (records, batch reports, task specs, git log), compare with the loop 60 retro, write the report, append 1 to 3 lessons, then step 11, smoke, close.
### Proof
`smoke64.sh` checks AC-1 to AC-6 from the files and git.
### Risks
Thin review metrics (no per-batch review, loop 61 without a source change): the report says so.
