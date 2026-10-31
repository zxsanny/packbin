# Autodev Loop Plan — Loop 95

loop: 95
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done at P0: AZ-3483 spec in `todo/` |
| decompose-feature | 9.5 | Decompose Feature | no | 3 points, one task |
| implement | 10 | Implement | yes | AZ-3483 |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | arm stage, Rust embedded stage, stage tests |
| test-spec-sync | 12 | Test-Spec Sync | yes | the embedded blackbox rows gain the reduced-build ARM scenarios |
| update-docs | 13 | Update Docs | yes | README, AGENT_GOTCHAS and living docs say the build has no ARM run (AC-9) |
| security | 14 | Security Audit | no | no auth, secrets or untrusted input touched |
| performance | 15 | Performance Test | no | stage time only (AC-7), measured in run-tests |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no deploy |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | 3 points, no incident, next retro due after loop 97 |
| local-deploy | — | Local deploy + open site | yes | no UI, no local deploy script: noted at close |
| smoke | — | Smoke acceptance | yes | user checklist in `smoke95.md` |

## Implementation

### Files that change
- `cpp/embedded/arm.sh` (a step in `target_m33f`), `cpp/embedded/arm/` (one small runner source)
- `README.md`, `_docs/AGENT_GOTCHAS.md`, living docs under `_docs/02_document`; CI step wording only if it names the reduced build

### Order of work
1. Baseline run of the arm stage on HEAD (figures and stage time into the batch report).
2. Try the two host test sources with both flags and `-Dmain=` on the M33F; decide fallback if one fails.
3. Runner, step, link and run checks; heap-check decision (Risk 2).
4. Scratch proofs AC-5 (a), (b), (c); full stage run.
5. Docs.

### Proof
- E1 to E11 of `_docs/02_task_plans/arm-no-text-no-ecc-run/input_data/expected_results/results_report.md`.

### Risks
- A host test that needs the other feature on; newlib stdio pulling the heap into the image.
