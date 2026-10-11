# Test Run — loop 18

**Date**: 2026-10-11
**Commits under test**: the full run at `e1ad5f4` (clean `git archive` export for the CI containers; the cross-language ring, the embedded stages and the shell checks from the clean live tree); re-runs after the two fixes it found: `8540047` (C++ host tests under GCC 16) and `be73db1` (C++ unpack stack), both in `cpp/` only.
**Mode**: functional. One total run for the loop, by the owner's direction (2026-10-06): the workers ran only their own package suite per stage; no Docker run per batch. Script: stage by stage with a result line per stage and a progress line every 30 seconds (scratchpad `step11.sh`).

```
TEST RESULTS: 2 657 passed, 0 failed, 0 skipped, 0 errors (csharp 844 on net10.0 and the same 844 again on the netstandard2.0 build, typescript 642, python 692, rust 479; java and cpp print per-runner "all tests passed")
SUITE: specified 8 / executed 7 / not-run 1 suite (the Pico example, a host limit), plus 5 scaffold checks, the cross-language ring and the publish gate executed
```

Runner manifest fallback: the runners do not report `traceability-matrix.md` rows individually, so the suite count is the manifest (six language suites plus the two embedded stages), as in loops 12 to 17.

## Verdict: PARTIAL

`failed = 0` after the fixes below. Not run: `cpp-example-pico` (the PlatformIO example). Reason: PlatformIO has no linux arm64 build of `toolchain-gccarmnoneeabi ~1.90201.0` on this host (`UnknownPackageError`); documented in `_docs/AGENT_GOTCHAS.md` (it needs a `--platform linux/amd64` container with its own cache); the ESP-IDF and Arduino-ESP32 examples and the ESP32-S3 and ESP32-C3 builds passed. The two real-vcpkg checks of the publish gate print NOT RUN (no vcpkg tool on this host), as in every earlier loop.

| Suite / check | Result | Detail |
|---------------|--------|--------|
| golden row, `report-row.test.sh`, `fixtures/hostile/cases.test.sh`, `cpp/embedded/lib.test.sh`, `ring-wiring.test.sh` | PASS | 30 s; `hostile cases ok: 25`; 40 negative cases of the ring wiring rejected |
| `tsc --noEmit --strict` (host recipe) | PASS | 1 s |
| csharp (`docker compose run csharp`, CI container) | PASS | 844 passed on net10.0 and 844 on the `netstandard2.0` build; 61 s |
| typescript | PASS | 642 passed, 0 failed |
| python | PASS | 692 passed |
| rust | PASS | 479 passed, 0 failed |
| java | PASS | all tests, scheme tests, field id binding tests, session tests |
| cpp (CI container, GCC 16, `-Wall -Wextra -Werror`) | FAIL at `e1ad5f4`, PASS at `be73db1` | the new host tests tripped GCC 16 `-Warray-bounds` false positives and `-Wformat-truncation` (clang on the Mac did not): fixed in `8540047` (std::string messages, two valid schemes `constexpr`, one scoped suppression with its reason); re-run at `be73db1` 11 s, `all tests passed` |
| `.github/workflows/language-pair.sh` (ring) | PASS | 102 s; `language pairs passed`; C# is a producer and a consumer in `listgroup`, `dictgroup` and `listflags` |
| `.github/workflows/publish-gate.test.sh` | PASS | 450 s; vcpkg supports/consumer checks NOT RUN |
| embedded ARM (`docker compose run cpp-embedded`) | FAIL at `e1ad5f4`, PASS at `be73db1` | `cpp-m4f` AC-5: deepest pack/unpack stack 520 B of 512 B (flash 7960 B of 8192 B). Cause: GCC inlined `unpack_items` into `unpack_one` so the per-level frame grew once `unpack_scoped` was added (AZ-2304). Fix `be73db1`: `PACKBIN_NOINLINE` on `unpack_items`: stack 456 B of 512 B, flash 7992 B of 8192 B; M0+, M3 QEMU (241 of 241 vectors, session vectors 22), s390x all PASS |
| embedded ESP (`cpp-embedded-esp`) | PASS except Pico | ESP32-S3 (app image 178 000 B) and ESP32-C3 (147 808 B) PASS, ESP-IDF example PASS, Arduino-ESP32 example PASS; Pico not run (above). `cpp/src` changed after this stage only by `be73db1`'s `NOINLINE` |

## Reality gate

- The six suites run the real packers and unpackers through each package's public API in the CI containers; the ring runs the real packers and unpackers of every pair on the same bytes, and `ring-wiring.test.sh` fails if a C# line is missing; the hostile vectors (25 cases, five of them `pack`) run in all six loaders; the publish gate builds the real packages.
- Every behavior change of this loop has a test that failed first on the previous code (see the batch reports 01 to 03 and the review fixes in `review18.md`).
- Golden `4001000065cd1d00a3e1110100` and the route fixture are unchanged in all six packages.

## CI parity

`test.yml` steps: required files and golden row, report columns, hostile case file, embedded harness, ring wiring, the six suites, publish gate (scaffold job); the `embedded` job. All run locally above. The CI `embedded` job runs the Pico example in a container where its toolchain exists, so the one not-run target here is expected to run there on the push.

## Lessons from the run

- A green macOS (Apple clang) `make -C cpp test` does not prove the GCC 16 `-Werror` build of CI: new C++ test code failed the container. Rule added to `_docs/AGENT_GOTCHAS.md`.
- The stack budget of the Cortex-M4F target is tight (56 B margin now): an inlining decision of GCC moved it by 64 B. Any change to `unpack.cpp`/`pack.cpp` needs the arm embedded stage before the commit.
- `dotnet test csharp` hangs without `MSBUILDDISABLENODEREUSE=1` (already in the gotchas).
