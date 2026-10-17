# Autodev Loop Plan — Loop 33

loop: 33
kind: product
confirmed: true
branch: dev
ship: false

Intake: owner picked "CI speed 4" from `_docs/loops/loop32/handoff33.md` (2026-10-17), then answered the batch D1 to D6 "accept all recommended"; ticket AZ-2626 (epic AZ-2223), 5 points, research skipped (the step times of runs 39024316436 and 39025925515 and the code trace of the gate groups' images are the research, in `problem.md`). Owner preferences: one total review, one step 11 run, 30 s heartbeats, `< /dev/null` and timeouts on shell, no tag or registry upload, pushes of `dev` asked each time, `main` not pushed.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done in P0 |
| decompose-feature | 9.5 | Decompose Feature | no | one task, 5 points |
| implement | 10 | Implement | yes | AZ-2626: batch 1 = ring preparation + pull lists + guards; batch 2 (owner D5) only if the first CI run misses |
| code-review | — | Total review | yes | once over the loop diff before step 11 |
| feature-assess | 10.5 | Feature Assessment | yes | once, read-only |
| run-tests | 11 | Run Tests | yes | one run: `scripts/loop-tests.sh`, guards, mutants, the new script's test |
| test-spec-sync | 12 | Test-Spec Sync | no | no product AC |
| update-docs | 13 | Update Docs | yes | `ci_cd_pipeline.md` ring layout and pull lists, metrics report section 9, `module-layout.md` |
| security | 14 | Security Audit | no | no auth, secret or input change; background processes run the same commands as before |
| performance | 15 | Performance Test | no | measured by CI runs (AC-1, AC-2) |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no tag |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | yes | 5 points; CI-speed series: keep the trend table |
| local-deploy | — | Local deploy + open site | yes | none (CI only): CI runs are the proof |
| smoke | — | Smoke acceptance | yes | checklist in `smoke33.md` |

## Implementation
### Files that change
- `test.yml` (`ring`: a background-start step after checkout, a build step, a wait step before `toolchain versions`; `scaffold`: the Swift ring wiring check and the new test; the `publish-gate-*` pull lines and their comments), a new `.github/workflows/ring-prepare.sh` (start / build / wait, logs and rc per build, bounded wait, timing notice) and `ring-prepare.test.sh` (stand-in commands), `ring-wiring.test.sh` (Go rule, no net lines), `ring-wiring-swift.test.sh` (wiring step in `scaffold`, Swift build through the preparation script), `publish-jobs.test.sh` (group → images map, exact pull rule, mutants), `scripts/loop-tests.sh` (scaffold list); docs.
### Order of work
1. `ring-prepare.sh` + test (parent). 2. `test.yml` ring and scaffold, the two ring guards. 3. Pull lists + `publish-jobs.test.sh`. 4. Total review → step 11 → owner push go → read step times → batch 2 if needed → close push → AC-1 median.
### Proof
Ring step seconds before/after; the timing notice; pull step seconds of the five-image jobs; one mutant per changed guard rule; two CI runs' wall times.
### Risks
Background processes across steps on the runner; four builds on four cores; Ubuntu 26 move from 2026-10-19; CI variance (1.4x).
