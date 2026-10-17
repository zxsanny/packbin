# Autodev Loop Plan — Loop 34

loop: 34
kind: product
confirmed: true
branch: dev
ship: false

Intake: owner answered the loop 34 batch (D1 to D4, from `_docs/loops/loop33/handoff34.md`) "accept all recommended" (2026-10-17), then, after the intake spike showed a restored SwiftPM build directory recompiles BoringSSL's 372 C files, picked "cache + ccache" for C3; ticket AZ-2627 (epic AZ-2223), 5 points, research skipped (the three runs' step times, the spike and the ccache mechanism check are the research, in `problem.md`). Owner preferences: one total review, one step 11 run, 30 s heartbeats, `< /dev/null` and timeouts on shell, no tag or registry upload, pushes of `dev` asked each time, `main` not pushed.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done in P0 |
| decompose-feature | 9.5 | Decompose Feature | no | one task, 5 points |
| implement | 10 | Implement | yes | AZ-2627: batch 1 = Swift caches with ccache (suites and ring), merged suite jobs, guards; batch 2 only if the measured runs miss (D4 gcc pull order, cache tuning) |
| code-review | — | Total review | yes | once over the loop diff before step 11 |
| feature-assess | 10.5 | Feature Assessment | yes | once, read-only |
| run-tests | 11 | Run Tests | yes | one run: `scripts/loop-tests.sh`, guards, mutants |
| test-spec-sync | 12 | Test-Spec Sync | no | no product AC |
| update-docs | 13 | Update Docs | yes | `ci_cd_pipeline.md` (caches, merged suites), metrics report section 10, `module-layout.md` |
| security | 14 | Security Audit | yes | new third-party action (`actions/cache`) and a new download (ccache from Ubuntu's apt) in CI: a short supply-chain addendum (pinning, cache scope and poisoning, publish path untouched) |
| performance | 15 | Performance Test | no | measured by CI runs (AC-1 to AC-4) |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no tag |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | yes | 5 points; CI-speed series: keep the trend table |
| local-deploy | — | Local deploy + open site | yes | none (CI only): CI runs are the proof |
| smoke | — | Smoke acceptance | yes | checklist in `smoke34.md` |

## Implementation
### Files that change
- `test.yml`: the `suites` matrix (7 entries, `csharp rust` and `cpp typescript java` shared; 20 jobs), its step (each suite in turn, keep going, fail at the end naming the failed ones; mounts the kept directories of a Swift part; ownership fix after a miss), `actions/cache` v6.1.0 by SHA for the three Swift parts and `ring` (key: build, swift pin, hash of `Package.swift` and `Package.resolved`, `v1`; no restore-keys; never on a tag run); comments.
- `swift-ccache.sh` (new, shared): ccache install (kept packages with `dpkg`, else `apt-get`), `CC`, `CCACHE_DIR`, statistics summary; sourced by `run-suite.sh`, run by `ring-swift.sh`'s container (`run`, build as the caller through `setpriv`).
- `run-suite.sh`: starts ccache when `PACKBIN_SWIFT_CACHE` is set; the cache line in the notice. `ring-swift.sh`: the kept-output build through `swift-ccache.sh run`. `ring-prepare.sh wait`: the Swift build's cache lines in the notice.
- `docker-compose.test.yml` unchanged (CI mounts at the service's own paths). `--disable-index-store` not used in batch 1.
- Guards: `publish-jobs.test.sh` (matrix, job count, suite step, cache rules, mutants), `run-suite-swift.test.sh` (S12), `ring-wiring-swift.test.sh` (ring cache rules, mutants, behaviour row), `ring-prepare.test.sh` (row 1b, mutant), `ring-wiring.test.sh` (cache-step exception in place).
### Order of work
1. ccache set-up in `run-suite.sh` + `run-suite-swift.test.sh` (parent). 2. compose and `test.yml` Swift cache steps. 3. `ring-swift.sh` + ring guard. 4. merged suites + `publish-jobs.test.sh`. 5. Total review → step 11 → owner push go → priming run (AC-5) → two measured runs (AC-1 to AC-4) → batch 2 only if a miss → close push.
### Proof
The four Swift builds' seconds and ccache hits from the notices before and after; job start offsets (AC-2); cache sizes from the cache list; one mutant per changed guard rule; two measured CI runs' wall times.
### Risks
Release builds may not reuse the restored Swift modules (whole-module optimization); the ring's root install; Ubuntu 26 move from 2026-10-19; CI variance (1.4x); the first push primes and is not counted, so the AC-1 runs are the second and third pushes.
