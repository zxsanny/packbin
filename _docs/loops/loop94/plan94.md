# Autodev Loop Plan — Loop 94

loop: 94
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done at P0: AZ-3479 spec in `todo/` |
| decompose-feature | 9.5 | Decompose Feature | no | 3 points, one task |
| implement | 10 | Implement | yes | AZ-3479 |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | arm and Rust embedded stages, stage tests |
| test-spec-sync | 12 | Test-Spec Sync | yes | the embedded blackbox rows lose the M4F scenarios |
| update-docs | 13 | Update Docs | yes | living docs quote the M4F row (AC-7) |
| security | 14 | Security Audit | no | no auth, secrets or untrusted input touched |
| performance | 15 | Performance Test | no | no perf NFR |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no deploy |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | 3 points, no incident, next retro due after loop 97 |
| local-deploy | — | Local deploy + open site | yes | no UI, no local deploy script: noted at close |
| smoke | — | Smoke acceptance | yes | user checklist in `smoke94.md` |

## Implementation

### Files that change
- `cpp/embedded/`: `run.sh`, `arm.sh`, `lib.sh`, `lib.test.sh`, `run-parts.test.sh`, `arm/mps2.ld`, `arm/size_main.cpp` (deleted)
- `rust/embedded/`: `run.sh`, `target.sh`, `limits.txt`, `README.md`, probe description
- `.github/workflows/test.yml`, `scripts/loop-tests.sh`, `cpp/Makefile`, `cpp/CMakeLists.txt` (comments)
- `README.md`, `_docs/AGENT_GOTCHAS.md`, living docs under `_docs/02_document`

### Order of work
1. Baseline run of the arm and Rust embedded stages on HEAD (figures into the batch report).
2. C++ stage: remove row, helpers, variables; fix stage tests.
3. Rust stage: remove row and `rust_same_as`; move mutants to the M33F target; limits file.
4. CI and comments; README and AGENT_GOTCHAS; then update-docs.
5. Full stage run; scratch-copy proof for AC-4.

### Proof
- E1 to E7 of `_docs/02_task_plans/drop-m4f-rows/input_data/expected_results/results_report.md`.

### Risks
- A shared helper removed with the M4F row (AC-2 grep plus full stage run).
- Mutants row blind after the target move (AC-4 scratch proof).
