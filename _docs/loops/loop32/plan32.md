# Autodev Loop Plan — Loop 32

loop: 32
kind: product
confirmed: true
branch: dev
ship: false

Intake: owner start message 2026-10-17 (scope and order from `_docs/loops/loop31/handoff32.md`), batched answer "accept all, target 330 s"; ticket AZ-2625 (epic AZ-2223), 5 points, research skipped (the loop 31 notes and metrics report section 7 are the research). Owner preferences: one total review, one step 11 run, 30 s heartbeats, `< /dev/null` and timeouts on shell, no tag or registry upload, pushes of `dev` asked each time, `main` not pushed.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done in P0 |
| decompose-feature | 9.5 | Decompose Feature | no | one task, 5 points |
| implement | 10 | Implement | yes | AZ-2625: batch 1 = the four cuts + guards; batch 2 (owner D5) only if the first CI run misses |
| code-review | — | Total review | yes | once over the loop diff before step 11 |
| feature-assess | 10.5 | Feature Assessment | yes | once, read-only |
| run-tests | 11 | Run Tests | yes | one run: `scripts/loop-tests.sh` (its parallel gate stage reads the new shares), guards, mutants |
| test-spec-sync | 12 | Test-Spec Sync | no | no product AC |
| update-docs | 13 | Update Docs | yes | `ci_cd_pipeline.md` job layout and timings, metrics report section 8, `module-layout.md` |
| security | 14 | Security Audit | no | no auth, secret or input change |
| performance | 15 | Performance Test | no | measured by CI runs (AC-1) |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no tag |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | yes | loop 31 was the last retro; 1 loop since, CI-speed series: keep the trend table |
| local-deploy | — | Local deploy + open site | yes | none (CI only): CI runs are the proof |
| smoke | — | Smoke acceptance | yes | checklist in `smoke32.md` |

## Implementation
### Files that change
- `publish-readonly.test.sh` (`ro_gate_checks` → one helper + three scenario functions), `publish-phases.test.sh` + `publish-phases-failures.test.sh` (`phase_checks` → `phase_checks` + `phase_rerun_checks`), `publish-gate.test.sh` (`gate_groups` 16 → 19, `group` lines), `test.yml` (gate jobs 5 → 8, long jobs first, `pins` in `publish-gate-rest`), `run-suite.sh` (strict flags on the speed build, `release` step gone), guards: `publish-jobs.test.sh`, `publish-timing.selftest.sh` (`ph_split`, new group list), `run-suite-swift.test.sh`; docs.
### Order of work
1. Swift strict-build merge in a worker (real container run). 2. Mac profile of the phase functions (scratch copy). 3. Readonly-gate split, phases split, `test.yml`, guards (parent). 4. Total review → step 11 → owner push go → read annotations and start times → batch 2 if needed → close push → AC-1 median.
### Proof
Group, job and step counts before/after; one mutant per changed guard rule; per-job seconds and start times of two CI runs; Mac stage seconds against the sum of its shares.
### Risks
23 jobs against 20 concurrent; `ring` and `swift tests` floors; CI variance (1.4x).
