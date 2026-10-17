# Batch 2 report — loop 31

Task: AZ-2607 (CI speed 2), batch 2 and C4 (owner decision 2026-10-17 on the first CI run: add the embedded split, regroup the gate, Swift in three parts, one push, measure two runs). No per-batch review (owner preference). Two workers with disjoint file sets (Swift parts, embedded split); the parent did `test.yml`, `publish-jobs.test.sh`, `publish-workflow.test.sh`.

Why: the first run of batch 1 (run 39012012655, wall 375 s) had `suites (swift, gates)` 371 s, `embedded` 360 s, `publish-gate-rest` 306 s (the `swift` group 215 s of it), `publish-gate-phases` 278 s, `suites (swift, tests)` 278 s, `ring` 271 s. With the suites and the gate regrouped, the floor of the wall was the single embedded job.

| Part | Status | Evidence |
|------|--------|----------|
| Gate regroup | Done | 5 gate jobs: `publish-gate-readonly` (readonly, gate), `publish-gate-readonly-gate` (readonly-gate, pins), `publish-gate-phases` (phases), `publish-gate-swift` (swift, no image pull), `publish-gate-rest` (readonly-full and the nine small groups, with the pull); 16 groups each in exactly one job |
| Swift in three parts | Done | `run-suite.sh`: `tests` (resolve, debug build, tests, list, fuzz), `gates` (resolve, strict release build, sanitizer build, list, sanitized run, deps), `speed` (resolve, `swift_speed` with its own release list); `all` unchanged (10 steps, same order); step-plan strings in one `case`; 33 mutants rejected (worker table) |
| Embedded in three jobs (C4) | Done | `cpp/embedded/run.sh`: one target table, `host arm`, `host esp core|packages`, in-container `PACKBIN_ESP_PART`, `list`, one timing notice; core = esp32s3, esp32c3, Arduino-ESP32 example; packages = ESP-IDF example, Pico example; `run-parts.test.sh` 73 checks, 26 mutants rejected |
| Guards | Done | `publish-jobs.test.sh`: gate jobs = every `publish-gate-*`, embedded rules (each of the 3 `run.sh host ...` commands in exactly one `embedded-*` job, no other `run.sh` call, no job-level if/needs/continue-on-error, a timeout), the Swift `speed` entry, the new scaffold step; mutant calls 50 → 66, all rejected |
| Real command check | Done | the speed part ran in the `swift:6.3.3` container (Mac, load 25 to 45): `swift test list -c release --skip-build` is accepted and lists SpeedTests; the part ran SpeedTests and the 1 MiB fuzz test and wrote the `swift (speed)` notice; exit 1 because two timing bounds were missed under load (1.52 s against 1 s, 1.14 s against the bound): the known Mac-under-load class, not a defect of the split; step 11 runs the stage again |

## Discovered during implementation

| # | Finding | Handling | clear/unclear |
|---|---------|----------|---------------|
| 1 | the speed part cannot report a missing SpeedTests suite before its release test build (the list needs the build); in `all` it still fails before the build | accepted; same message | clear |
| 2 | the speed part's notice shows resolve and one `swift_speed` step (build, list and run are not separated) | splitting would make `all` 11 steps; left | clear |
| 3 | `target_example_esp32_arduino` calls `examples_tools`, which installs PlatformIO although only the Pico example needs it: time in the `core` job | not measured, not changed; the embedded notice shows the target seconds | unclear |
| 4 | each embedded ESP job pulls `espressif/idf:v5.3.2` separately | expected 40 to 90 s each; the notice and job seconds will show it | unclear |
| 5 | a push to `dev` and `main` together is now 40 jobs against the 20 of the free plan (20 per push) | `main` is not pushed in this loop; queueing is measured at the close | unclear |
| 6 | the Mac `scaffold` stage lacked the new `run-parts.test.sh`; added to `scripts/loop-tests.sh` | done | clear |
| 7 | docs that name one `embedded` job: `_docs/02_document/deployment/ci_cd_pipeline.md:7`, `deployment/containerization.md:18`, `module-layout.md:136`, `components/05_cpp_package/tests.md:413,426` | step 13 | clear |
| 8 | `run-parts.test.sh` is 497 lines, 3 under the cap | a new check goes in a sibling file | clear |

## CI-parity

CI-parity: PASS (2026-10-17, Mac at load 20 to 40). Commands, with seconds: `report-row.test.sh` 30, `run-suite.test.sh` 60 (it sources `run-suite-swift.test.sh`: the Swift three-part rows and the row that reads `test.yml`), `cpp/embedded/lib.test.sh` 30, `cpp/embedded/run-parts.test.sh` 30 (73 checks), `ring-wiring.test.sh` 60, `scripts/loop-tests.test.sh` 30, `publish-jobs.test.sh` 30 (66 mutant calls), `publish-timing.selftest.sh` 30, `publish-workflow.test.sh` 30, `docker compose -f docker-compose.test.yml config` 30, all PASS; `shellcheck -x -S warning` on the 6 changed shell files: the finding set equals HEAD's (no new finding). Unchanged since the batch 1 gate and not re-run: `fixtures/hostile/cases.test.sh`. No language source changed. The real new command of the speed part ran in the `swift:6.3.3` container (see the table). The embedded ESP parts have no real run here (the Mac cannot run the Pico target and the ESP image is several GB): the CI run is their proof.
