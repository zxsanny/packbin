# Test Run — loop 17

**Date**: 2026-10-07
**Commit under test**: `412ae3a` (the tree was clean; the run uses a clean `git archive` export of that commit, except the cross-language ring, which runs from the live tree because its host drivers need `typescript/node_modules`; the tree was clean when it started).
**Mode**: functional. One total run for the loop, by the owner's direction (2026-10-06): the workers ran their own C# suites per batch, nothing else ran per change. Script: stage by stage with a result line per stage and a progress line every 30 seconds (scratchpad `run17.sh`).

```
TEST RESULTS: 1 971 passed, 0 failed, 0 skipped, 0 errors (csharp 649, typescript 470, python 492, rust 360; the netstandard2.0 build runs the same 649 C# tests again with 0 failures; java and cpp print per-runner "all tests passed")
SUITE: specified 8 / executed 6 / not-run 2 suites (the two embedded stages), plus 5 scaffold checks, the cross-language ring and the publish gate executed
```

Runner manifest fallback: the runners do not report `traceability-matrix.md` rows individually, so the suite count is the manifest (six language suites plus the two embedded stages), as in loops 12 to 16.

## Verdict: PARTIAL

`failed = 0`. Not run: `cpp-embedded` (ARM: Cortex-M0+, M3 QEMU, M4F, s390x) and `cpp-embedded-esp` (ESP32-S3, ESP32-C3, ESP-IDF and Arduino examples, Pico). Reason: loop 17 changed only `csharp/` and `_docs/` (plus the owner's CI and README hunks committed in `68ca4f8`); `git diff --name-only 67cb09d..HEAD` lists no file under `cpp/`, the toolchains and the ESP cache are the ones of the green loop 16 run (`test_run_loop16_report.md`) and of the green CI at `67cb09d`. It is a cost skip, not a host limit: the stages need the live `.cache/embedded` (9.4 GB) and about an hour. The CI `embedded` job runs them on the push of this loop. Never counted as PASS.

| Suite / check | Result | Detail |
|---------------|--------|--------|
| `.github/workflows/language-pair.sh` (ring) | PASS | 75 s; `language pairs passed`; every pair on the same bytes including the loop 16 rings (`listgroup`, `dictgroup`, `listflags`); C# is a producer and a consumer; `PACKBIN_CXX_SYSROOT` set |
| csharp (`docker compose run csharp`, CI container, SDK 10.0.401) | PASS | 649 passed on net10.0 and 649 on the `netstandard2.0` build (`PACKBIN_NETSTANDARD2_0`); 0 warnings, 0 errors; 21 s |
| typescript | PASS | 470 passed (unchanged since loop 16) |
| python | PASS | 492 passed (unchanged) |
| rust | PASS | 360 passed (unchanged) |
| cpp | PASS | all tests passed (unchanged) |
| java | PASS | all tests, scheme tests, field id binding tests, session tests, `api-check` PASS (Android API 26) |
| scaffold: golden row `4001000065cd1d00a3e1110100`, `report-row.test.sh`, `fixtures/hostile/cases.test.sh`, `cpp/embedded/lib.test.sh`, `ring-wiring.test.sh` | PASS | 0 to 4 s each |
| `.github/workflows/publish-gate.test.sh` | PASS | 412 s, with the real C# package build: the `.nupkg` check requires both `lib/netstandard2.0/Packbin.dll` and `lib/net10.0/Packbin.dll`, `csharp-payload` is rejected without the second |
| `tsc --noEmit --strict` (host recipe) | not run | no TypeScript change in loop 17 |
| real-vcpkg gate (`publish-gate.test.sh --vcpkg`) | not run | no C++ or port change in loop 17 (the full gate printed NOT RUN for the two vcpkg checks, as without a vcpkg tool) |

C# on the host, per batch and at the end (`dotnet test csharp`, both targets): 424 at the start of the loop, 448 after batch 1 stage 1, 465, 610, 649; unchanged at 649 after the total review fixes.

## Reality gate

- The C# suite runs the real packer and unpacker through the public API in the CI container; the ring runs the real packers and unpackers of every pair on the same bytes (no stub, no passthrough); the publish gate builds the real C# package in the toolchain container and checks the real artifact. The test files that call internals (`InternalsVisibleTo`) test internal helpers, never replace a product module.
- The AC-10 test times only the public typed `Pack(scheme, row)` and `Unpack(bytes, scheme.On(...))`.
- Behavior changes of this loop (counts, lone values in rounds, strict numbers, flag-bit numbering, group elements) have a test that fails on `68ca4f8` (see the batch reports), and the ring and the golden fixture show the wire did not change for any packet the other packages can produce.

## CI parity

CI-parity: PASS locally for what CI runs per push except the `embedded` job and the Linux-only parts: the `scaffold` job (checks, six container suites, publish gate) and the `ring` job's script. `test.yml` runs `docker compose run` for each of the six suites, which this run did. Linux-only parts were proven by the loop 16 CI run (the `ring` job with gcc 16 wrapper, the vcpkg `x64-linux` dry-run); loop 17 changes none of them.

## Findings of this run

None: no failure in any executed stage here. **CI found one after the push** (run 37588554503 at `87e554f`): the AC-10 timing test took 1 618 ms on the GitHub runner (bound 1 000 ms), so the `scaffold` job stopped in its first suite (C#) and the other five suites and the publish gate did not run on CI for that commit; `ring` and `embedded` passed (`embedded` closes the not-run item above: ARM, ESP and Pico stages are green on CI). A local pass on a fast machine is not CI parity for a timing assertion: the same test took 786 ms to 1 s inside the suite on the Mac and about 1.6 s on the runner. Fixed after the first push by isolating the test (see `perf_run_loop17_report.md`).

## Environment notes

- Docker Desktop with warm toolchain images, so the five package suites finish in 4 to 11 s each; the first run after an image change takes minutes.
- `dotnet build-server shutdown` after host `dotnet` runs; no process left.
- The stage logs are in the session scratchpad (`run17-*.log`), not in the repo.

## Not run

`cpp-embedded` and `cpp-embedded-esp` (reason above), `tsc --noEmit --strict`, the real-vcpkg gate.
