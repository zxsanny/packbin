# Test Run — loop 16

**Date**: 2026-10-06
**Commit under test**: `3b466e4` for the first run, `f26ba1e` for the re-runs of the two stages named below (the only change between them is one comment in `typescript/src/index.ts`). Both runs use a clean `git archive` export of the committed tree: the owner's uncommitted C# multi-target work and CI hunks are not part of the run.
**Mode**: functional, Docker (`docker-compose.test.yml`: the six language suites and the `embedded` job's ARM and ESP stages) plus the scaffold checks, strict `tsc`, `language-pair.sh`, `publish-gate.test.sh` and the real-vcpkg gate. By the owner's direction this is the one total test run of the loop; the workers ran their own package suites per batch, and nothing else ran per change.

```
TEST RESULTS: 1732 passed, 0 failed, 0 skipped, 0 errors (csharp 410, typescript 470, python 492, rust 360; java and cpp print per-runner "all tests passed")
SUITE: specified 8 / executed 8 / not-run 0 suites; 1 target inside the ESP stage not run by the stage script on this host (cpp-example-pico), run separately under the CI toolchain below
```

Runner manifest fallback: the runners do not report `traceability-matrix.md` rows individually, so the suite count is the manifest (six language suites plus the two embedded stages), as in loops 12 to 15.

## Verdict: PASS

One real failure was found by this run and fixed (below); every executed suite and check passes after the fix. The one failing target of the ESP stage, `cpp-example-pico`, is a host limit (this Mac is linux/arm64 and PlatformIO has no linux_aarch64 build of `toolchain-gccarmnoneeabi ~1.90201.0`: `UnknownPackageError`, as in loops 13 to 15), and it was run for real under the CI toolchain.

| Suite / check | Result | Detail |
|---------------|--------|--------|
| csharp | PASS | 410 passed (loop 15: 410, unchanged: the C# specs are held) |
| typescript | PASS | 470 passed (loop 15: 279) |
| python | PASS | 492 passed (loop 15: 103) |
| rust | PASS | 360 passed (282 lib, 78 integration; loop 15: 234) |
| cpp | PASS | all tests passed |
| java | PASS | PackbinTest (incl. `DuplicateNamesTest`, `MissingNestedValueTest`, `TypedElementScopeTest`), SchemeTest, FieldIdBindingTest, SessionTest, `api-check` |
| embedded ARM (`cpp-embedded`) | PASS | 4 of 4: Cortex-M0+, M3 QEMU, M4F (flash 7784 of 8192 B), s390x big-endian |
| embedded ESP (`cpp-embedded-esp`) | PASS for 4 of 5 | ESP32-S3, ESP32-C3, the ESP-IDF example from the packed component and the Arduino-ESP32 example; run from the live repo because the 9.4 GB toolchain cache is not visible inside a container through a symlink into a scratch export (the export run failed two targets with `No such file or directory: '/src/.cache/embedded'`, a harness artifact); `cpp-example-pico` fails on the arm64 toolchain gap |
| `cpp-example-pico`, CI toolchain | PASS | linux/amd64 container (`python:3.12-slim`, emulated), repository `platformio.ini`, current PlatformIO: `toolchain-gccarmnoneeabi` 1.90201.191206 (GCC 9.2.1): SUCCESS in 40 s, RAM 15.1% (40 744 B), Flash 0.2% (4 034 B) |
| `fixtures/hostile/cases.test.sh` and `check-cases.sh` (scaffold) | PASS | 19 cases |
| `.github/workflows/report-row.test.sh`, `cpp/embedded/lib.test.sh`, `ring-wiring.test.sh` (scaffold) | PASS | the `find | head` scan and the consumer-failure wording checks included |
| `.github/workflows/publish-gate.test.sh` | PASS after the fix | first run: 415 s, 1 failure; re-run of the npm part on the fixed export passes (`npm position check passed`, `npm dist checks passed`) |
| `publish-gate.test.sh --vcpkg`, real vcpkg 2026-09-26 (arm64-osx) | PASS | `vcpkg port checks passed` (the full gate prints NOT RUN for the two vcpkg checks without a vcpkg tool; this run is their proof) |
| `tsc --noEmit --strict` | PASS | `typescript/src/index.ts` with the AGENT_GOTCHAS flags |
| `.github/workflows/language-pair.sh` | PASS | all rings including `listgroup`, `dictgroup`, `listflags`; 72 s, `PACKBIN_CXX_SYSROOT` set |

## The failure this run found

`AZ-2103 AC-4 the built JavaScript uses a Node-only name`: the comment added in round 3 (AZ-2243, `PackSession.load` brand check) said `node:vm`, and the npm tarball check rejects any `node:` string in `dist`. No per-change run could have caught it because none ran (owner direction); the total run did. Fixed in `f26ba1e` (the comment says "a vm context"). The unit tests and the strict `tsc` were green before and after: only the publish gate sees the built JavaScript.

## Reality gate

- The publish scenarios build the real packages in the real toolchain containers with the repo mounted read-only and check the real artifacts; registry tools are PATH stubs at the system boundary, the registries are bare git repositories. The golden gate runs the six real drivers through the same read-only mount. No internal module is stubbed.
- The ring runs the real packers and unpackers of every pair on the same bytes, now also for a list of group, a dict of group and a list of flags, with the cut-short packets refused by each participant.
- The vcpkg gate installs the port with a real vcpkg, builds a consumer and checks the version rule against CMake; the supports check dry-runs `x64-windows` (refused) and `x64-linux` (planned).

## CI parity

CI-parity: PASS locally. The six `docker compose -f docker-compose.test.yml run --rm <lang>` suites, `cpp-embedded`, `cpp-embedded-esp` (Pico run separately as above), the scaffold checks, `publish-gate.test.sh` (the failing part re-run), the real-vcpkg gate, strict `tsc`, `language-pair.sh`. Not exercised here and decided only by the first CI run after the push: the new `ring` job on the Ubuntu runner (node 24, JDK 26, Python 3.14, the gcc 16 wrapper), `npm ci --prefix` through a symlinked temp path on Linux, `mawk` as the awk of the examples scan, the vcpkg `x64-linux` dry-run and second consumer, `GITHUB_ACTIONS=true` turning a missing tool into a failure.

## Environment notes

- Host recipes are in `_docs/AGENT_GOTCHAS.md` (strict `tsc` flags, `PACKBIN_CXX_SYSROOT`, the Pico container); this run used them from the first stage.
- The ESP and Pico stages need the real `.cache/embedded` directory in the tree they run from; an export of `HEAD` has none, so those two targets run from the live repo (identical `cpp/` and compose files, checked with `git status`).
- No timing-sensitive test failed in this run (a quiet machine, one stage at a time).

## Not run

None. `cpp-example-pico` ran under the CI toolchain.
