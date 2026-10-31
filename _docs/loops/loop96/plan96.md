# Autodev Loop Plan — Loop 96

loop: 96
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done at P0: AZ-3495 spec in `todo/` |
| decompose-feature | 9.5 | Decompose Feature | no | 5 points, one task |
| implement | 10 | Implement | yes | AZ-3495, one batch, by the parent |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | `scripts/loop-tests.sh --only scaffold,ring` (the stages that run the ring self-tests, the real ring and the driver script) |
| test-spec-sync | 12 | Test-Spec Sync | no | no package behavior or blackbox scenario of the packages changes; the ring is test infrastructure |
| update-docs | 13 | Update Docs | no | no public contract; `fixtures/frame/README.md` is edited by AZ-3495 itself |
| security | 14 | Security Audit | yes | `lite`, diff-scoped: the ring drivers parse driver lines (as loops 79 to 81) |
| performance | 15 | Performance Test | no | the ring time (30 s on HEAD) is an NFR of AZ-3495, measured in run-tests |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no deploy |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | 5 points, no incident, next retro due after loop 97 |
| local-deploy | — | Local deploy + open site | yes | no UI, no local deploy script: noted at close |
| smoke | — | Smoke acceptance | yes | user checklist in `smoke96.md` |

## Implementation

### Files that change
- `scripts/frame/ring_frame.py` (462 lines now; split if it would pass 500), `fixtures/frame/ring-cases.txt`, `fixtures/frame/README.md`
- the eight drivers' `mac` / `verify` functions under `.github/workflows/drivers`
- `.github/workflows/ring-frame.test.sh`, `.github/workflows/ring-frame-drivers.test.sh`

### Order of work
1. Baseline: the ring on HEAD is read (30 s, 64 pairs, 45 rows per pair, 72 refusals per language; problem.md).
2. Loader, writers and reference calls in `ring_frame.py`; rows; self-test with stand-in drivers (red first).
3. Eight drivers: split on `|`, each piece through the language's existing hex reader (`-` empty), pass the list.
4. Driver script cases (AC-4), the Go `parts[0]` mutation proof (AC-5), README.
5. Full `scaffold,ring` run, then the figures of AC-3.

### Proof
- E-table of `_docs/02_task_plans/ring-multipart-mac-rows/input_data/expected_results/results_report.md`.

### Risks
- A hex reader that takes `""` as zero bytes; C++ and Rust take a list of spans, Swift an array of arrays.
