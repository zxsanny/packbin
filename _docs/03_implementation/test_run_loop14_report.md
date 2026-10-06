# Test Run — loop 14

**Date**: 2026-10-06
**Commit under test**: 43af2f6 (application code, workflows and scripts; `_docs/` dirty by design: assessment, docs pass)
**Mode**: functional, Docker (`docker-compose.test.yml`: the six language suites and the `embedded` job's ARM and ESP stages) plus the scaffold checks, strict `tsc`, `language-pair.sh` and `publish-gate.test.sh`. Run stage by stage by a script with a result line per stage; logs under the session scratchpad.

```
TEST RESULTS: 951 passed, 0 failed, 0 skipped, 0 errors (csharp 390, typescript 241, python 103, rust 217; java and cpp print per-runner "all tests passed")
SUITE: specified 8 / executed 8 / not-run 0 suites; 1 target inside the ESP stage not run by the stage script on this host (cpp-example-pico), run separately with both toolchains below
```

Runner manifest fallback: the runners do not report `traceability-matrix.md` rows individually, so the suite count is the manifest (six language suites plus the two embedded stages), as in loops 12 and 13.

## Verdict: PASS

Every suite and check passed. The one failing row of the stage script, `cpp-example-pico` inside `cpp-embedded-esp`, is a host limit, not a product failure: this Mac is linux/arm64 and PlatformIO's registry has no linux_aarch64 build of `toolchain-gccarmnoneeabi ~1.90201.0` (`UnknownPackageError`; the same as loop 13, where it made the verdict PARTIAL). It was then run for real on this host two ways (below), so nothing specified is left not-run.

| Suite / check | Result | Detail |
|---------------|--------|--------|
| csharp | PASS | 390 passed |
| typescript | PASS | 241 of 241 |
| python | PASS | 103 passed |
| rust | PASS | 217 passed, 0 failed |
| cpp | PASS | all tests passed; compile-fail cases rejected |
| java | PASS | PackbinTest, SchemeTest, FieldIdBindingTest, SessionTest, and `api-check` (Android API 26) |
| embedded ARM (`cpp-embedded`) | PASS | Cortex-M0+ (cxa=0, heap=0), M3 QEMU (223 vectors asserted, session vectors 22), M4F (flash 7728 of 8192 B, stack 488 of 512 B), s390x (223 vectors, all-kinds packet equals M3 bytes) |
| embedded ESP (`cpp-embedded-esp`) | PASS for 4 of 5 | ESP32-S3 (177 680 B) and ESP32-C3 (147 552 B) on ESP-IDF v5.3.2, 0 errors 0 warnings; ESP-IDF example from the packed component; Arduino-ESP32 example from the staged layout. `cpp-example-pico` failed in the stage on the arm64 toolchain gap |
| `cpp-example-pico`, arm64 toolchain | PASS | PlatformIO's own linux_aarch64 `toolchain-gccarmnoneeabi` 1.90301.200702 (GCC 9.3.1), pinned only in a temporary project copy: SUCCESS in 277 s, RAM 15.1% (40 744 B), Flash 0.2% (4 042 B), 3 warnings, all in `framework-arduino-mbed` |
| `cpp-example-pico`, CI toolchain | PASS | linux/amd64 container (`python:3.12-slim`, emulated), repository `platformio.ini` untouched, no pin: PlatformIO picked `toolchain-gccarmnoneeabi` 1.90201.191206 (GCC 9.2.1), the one CI uses: SUCCESS in 274 s, RAM 15.1% (40 744 B), Flash 0.2% (4 034 B), 3 warnings, all in the framework |
| `fixtures/hostile/cases.test.sh` | PASS | 17 cases |
| `.github/workflows/report-row.test.sh` | PASS | |
| `.github/workflows/publish-gate.test.sh` | PASS | 214 s: two-phase publish, credential matrix, re-run, Ruby workflow structure check |
| `tsc --noEmit --strict` | PASS | `typescript/src/index.ts` with `--target es2022 --module nodenext --moduleResolution nodenext --allowImportingTsExtensions` |
| `.github/workflows/language-pair.sh` | PASS | all rings; 60 s; needs `PACKBIN_CXX_SYSROOT=$(xcrun --show-sdk-path)` on this Mac |

The stage script's first `tsc` and `language-pair` runs failed on host setup (no `--target`; no `PACKBIN_CXX_SYSROOT`, `fatal error: 'cstddef' file not found`), not on code: no TypeScript or C++ file changed in this loop (`git diff c6c389c..HEAD -- typescript cpp` is empty).

## Reality gate

- The publish scenarios build the real packages in the real toolchain containers on a copy of the tree (csharp, typescript, python, rust, java, vcpkg, platformio, esp-idf, arduino) and check the real artifacts; registry tools are PATH stubs at the system boundary, the registries are bare git repositories. No internal module is stubbed. The API check runs on the compiled Java classes against the Android API 26 signature.
- Cross-language rings run the real drivers of all six packages. The hostile cases replay against the real packers.

## CI parity

CI-parity: PASS. The six `docker compose -f docker-compose.test.yml run --rm <lang>` suites, `cpp-embedded`, `cpp-embedded-esp` (Pico run separately as above), `cases.test.sh`, `report-row.test.sh`, `publish-gate.test.sh`, strict `tsc`, `language-pair.sh`. Not exercised here: GitHub's behavior for the `workflow_call`, `needs` and branch-only `push` filter, the live Maven Central `published` answer and the token lifetime; they run on the first real tag (assessment U1, U3).

## Environment notes

- Toolchains added to the gitignored `.cache/embedded/` (owner approved the downloads): the arm64 PlatformIO packages `toolchain-gccarmnoneeabi` 1.90301.200702, `framework-arduino-mbed`, `tool-rp2040tools`, `tool-scons` under `.cache/embedded/platformio/packages` (476 MB), and the x86_64 set under `.cache/embedded/amd64/platformio/packages` with its own venv. The amd64 run used a pulled `python:3.12-slim` image.
- The Pico runs were not part of the stage script: `cpp/embedded/examples.sh` is unchanged, so on an arm64 host the stage still shows `cpp-example-pico` failed until the toolchain gap is handled by the project (open question for the owner, not decided here).
- The C# and TypeScript AC-10 throughput NFRs passed in this run.

## Not run

None. `cpp-example-pico` ran twice outside the stage script (both toolchains).
