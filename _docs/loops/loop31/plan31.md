# Autodev Loop Plan — Loop 31

loop: 31
kind: product
confirmed: true
branch: dev
ship: false

Intake: owner accepted all six recommendations of `_docs/loops/loop30/handoff31.md` (2026-10-17); ticket AZ-2607 (epic AZ-2223), 5 points, research skipped (the loop 30 metrics report is the research). Owner preferences: one total review, one step 11 run, 30 s heartbeats, `< /dev/null` and timeouts on shell, no tag or registry upload, pushes of `dev` asked each time, `main` not pushed.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done in P0 |
| decompose-feature | 9.5 | Decompose Feature | no | one task, 5 points |
| implement | 10 | Implement | yes | AZ-2607 in two batches: structure + timing, then the rebalance from the first CI run's numbers |
| code-review | — | Total review | yes | once over the loop diff before step 11 |
| feature-assess | 10.5 | Feature Assessment | yes | once, read-only |
| run-tests | 11 | Run Tests | yes | one run: `scripts/loop-tests.sh` (its new parallel gate stage is AC-4's proof), guards, mutants |
| test-spec-sync | 12 | Test-Spec Sync | no | no product AC |
| update-docs | 13 | Update Docs | yes | `ci_cd_pipeline.md` job layout and timings, metrics report section 7 |
| security | 14 | Security Audit | no | no auth, secret or input change |
| performance | 15 | Performance Test | no | measured by CI runs (AC-1) |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no tag |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | yes | 5 loops since the last retro (loop 26) |
| local-deploy | — | Local deploy + open site | yes | none (CI only): CI runs are the proof |
| smoke | — | Smoke acceptance | yes | checklist in `smoke31.md` |

## Implementation
### Files that change
- Batch 1 (as built): `publish-readonly.test.sh` (`readonly_checks` in three groups), `publish-gate.test.sh` (`gate_groups` 14 → 16, two new `group` lines), `test.yml` (5 gate jobs; `GITHUB_ACTIONS` is not in `test.yml`: the bare key is in `docker-compose.test.yml` for the 8 suite services), `run-suite.sh` (one timing notice per suite; Swift step labels cut on the joined line), `publish-jobs.test.sh` (gate jobs = every `publish-gate-*`, +5 mutants), `publish-timing.selftest.sh` (16 groups, `ro_split`, EXIT trap rule), `publish-vcpkg.test.sh` (trap chains `timed_abort`), `run-suite.test.sh` N1 to N6, `run-suite-swift.test.sh` S2e, `scripts/loop-tests.sh` + test (parallel shares read from `test.yml`, tree check), `publish-phases.test.sh` split into `publish-phases-failures.test.sh` (new), `_docs/02_document/module-layout.md`, `notes31.md` (audit).
- Batch 2 (as built, owner decision 2026-10-17: add C4 and do batch 2 with it, one push): `test.yml` gate jobs regrouped by the first run's seconds (swift group in `publish-gate-swift`; `readonly-full` and the nine small groups in `publish-gate-rest`, which pulls the images), the Swift suite in three parts (`run-suite.sh`: `tests`, `gates`, `speed`; `run-suite-swift.test.sh`), the embedded job in three jobs (`embedded-arm`, `embedded-esp-core`, `embedded-esp-packages`; `cpp/embedded/run.sh` target table, `host <stage> <part>` forms, a timing notice; `cpp/embedded/run-parts.test.sh` new, in the `scaffold` job and the Mac scaffold stage), `publish-jobs.test.sh` (embedded rules, the speed entry, +16 mutants), `publish-workflow.test.sh`. C4 was out of scope at intake and is in scope by the owner's decision.
### Order of work
1. Readonly split + group count guard + mutants. 2. Suite timing notice + guard. 3. Gate jobs by the best estimate. 4. Mac parallel stage + test, tree manifest proof. 5. publish-phases split. 6. Audit. 7. Owner push go → read annotations → batch 2 → second push → AC-1 median.
### Proof
Group and step counts before/after; one mutant per guard rule; per-job seconds of two CI runs; Mac stage seconds against the sum of its shares.
### Risks
Shares writing into one tree on the Mac; CI variance (1.5x) makes one run no proof.
