# Test Run — loop 15

**Date**: 2026-10-06
**Commit under test**: 4300410 (application code, tests, workflows and scripts; `_docs/` dirty by design: assessment, docs pass, audit)
**Mode**: functional, Docker (`docker-compose.test.yml`: the six language suites and the `embedded` job's ARM and ESP stages) plus the scaffold checks, strict `tsc`, `language-pair.sh` and `publish-gate.test.sh`. Run stage by stage by a script that prints one result line per stage (the same 13 stages after each of the three batches; the numbers below are from the run after batch 3).

```
TEST RESULTS: 1026 passed, 0 failed, 0 skipped, 0 errors (csharp 410, typescript 279, python 103, rust 234; java and cpp print per-runner "all tests passed")
SUITE: specified 8 / executed 8 / not-run 0 suites; 1 target inside the ESP stage not run by the stage script on this host (cpp-example-pico), run separately under the CI toolchain below
```

Runner manifest fallback: the runners do not report `traceability-matrix.md` rows individually, so the suite count is the manifest (six language suites plus the two embedded stages), as in loops 12 to 14.

## Verdict: PASS

Every executed suite and check passed. The one failing row of the stage script, `cpp-example-pico` inside `cpp-embedded-esp`, is a host limit, not a product failure: this Mac is linux/arm64 and PlatformIO's registry has no linux_aarch64 build of `toolchain-gccarmnoneeabi ~1.90201.0` (`UnknownPackageError`, the same as loops 13 and 14). It was run for real this loop under the CI toolchain, so nothing specified is left not-run.

| Suite / check | Result | Detail |
|---------------|--------|--------|
| csharp | PASS | 410 passed (loop 14: 390; +17 round limits, +3 hostile replay) |
| typescript | PASS | 279 passed (loop 14: 241; +35 round limits, +3 hostile replay) |
| python | PASS | 103 passed, with the pinned pytest 9.1.1 and the README test |
| rust | PASS | 234 passed (217 before, +17) |
| cpp | PASS | all tests passed; the `limit` stage is skipped in its hostile replay |
| java | PASS | PackbinTest (with `RoundLimitsTest` and the hostile replay), SchemeTest, FieldIdBindingTest, SessionTest, `api-check` |
| embedded ARM (`cpp-embedded`) | PASS | Cortex-M0+, M3 QEMU (223 vectors), M4F (flash 7728 of 8192 B), s390x big-endian: 4 of 4 |
| embedded ESP (`cpp-embedded-esp`) | PASS for 4 of 5 | ESP32-S3, ESP32-C3, the ESP-IDF example from the packed component and the Arduino-ESP32 example; `cpp-example-pico` fails in the stage on the arm64 toolchain gap |
| `cpp-example-pico`, CI toolchain | PASS | linux/amd64 container (`python:3.12-slim`, emulated), repository `platformio.ini`, PlatformIO 6.2.0: `toolchain-gccarmnoneeabi` 1.90201.191206 (GCC 9.2.1): SUCCESS, RAM 15.1% (40 744 B), Flash 0.2% (4 034 B), 3 warnings all inside `framework-arduino-mbed` (the arm64 GCC 9.3.1 build passed in loop 14 and was not re-run: the example, the toolchain and the framework are unchanged) |
| `fixtures/hostile/cases.test.sh` and `check-cases.sh` | PASS | 19 cases (17 + 2 `limit`), five limit corruptions rejected |
| `.github/workflows/report-row.test.sh` | PASS | |
| `.github/workflows/publish-gate.test.sh` | PASS | 377 s: two-phase publish, credential matrix, re-run, Ruby workflow structure, `uses:` pins check (13 violating copies), read-only container checks (7 of 7 probe writes without the override), tool-pin reader |
| `tsc --noEmit --strict` | PASS | `typescript/src/index.ts` with the AGENT_GOTCHAS flags |
| `.github/workflows/language-pair.sh` | PASS | all rings, 61 s, `PACKBIN_CXX_SYSROOT` set |

## Reality gate

- The publish scenarios build the real packages in the real toolchain containers, now with the repo mounted read-only, and check the real artifacts; registry tools are PATH stubs at the system boundary, the registries are bare git repositories. The golden gate runs the six real drivers through the same read-only mount. No internal module is stubbed.
- The round limits are tested by real unpacks of generated packets (65,535 rounds accepted, 65,536 refused; a 1 MiB packet refused with `left` 983,041) in all four packages, and by the two shared hostile cases replayed against the real packers.

## CI parity

CI-parity: PASS locally. The six `docker compose -f docker-compose.test.yml run --rm <lang>` suites, `cpp-embedded`, `cpp-embedded-esp` (Pico run separately as above), `cases.test.sh`, `report-row.test.sh`, `publish-gate.test.sh`, strict `tsc`, `language-pair.sh`. Not exercised here and decided only by the first CI run after the push: Compose 2.38.2 merging the second compose file, the `/out` bind mount and file ownership on the Ubuntu runner (AZ-2215), the pinned `actions/checkout`, `actions/setup-node` and `NuGet/login` commits, the pinned pip tools on the runner's Python 3.12.3 (AZ-2214), and everything registry-side (assessment loop 14 U1, U3).

## Environment notes

- Host recipes are in `_docs/AGENT_GOTCHAS.md` (strict `tsc` flags, `PACKBIN_CXX_SYSROOT`, the Pico container); this run used them from the first stage.
- Timing-sensitive tests: `PackbinTests.Nfr_RoundTripsWithinOneSecond` failed at about 1.1 s twice when other workers pushed the load average above 30, and passed in every run on a quiet machine (including the three runs above).
- No new toolchain download was needed: `.cache/embedded` already held the arm64 and the amd64 sets from loop 14.

## Not run

None. `cpp-example-pico` ran under the CI toolchain (arm64 GCC 9.3.1 was last run in loop 14).
