# Test Run — loop 19

**Date**: 2026-10-11
**Commit under test**: `02206a7` (clean tree; the CI containers ran a clean `git archive` export of it; the shell checks, the cross-language ring and the publish gate ran from the live tree)
**Mode**: functional. One total run for the loop, by the owner's direction (2026-10-06): the workers ran only their own package suite; no Docker run per batch. Script: stage by stage, a result line per stage and a 30 s heartbeat (`scratchpad/step11.sh`, re-run script `step11b.sh`).

```
TEST RESULTS: 3 864 passed, 0 failed, 0 skipped, 0 errors (csharp 913 on net10.0 and the same 913 again on the netstandard2.0 build, typescript 728, python 777, rust 533; java and cpp print per-runner "all tests passed")
SUITE: specified 8 / executed 7 / not-run 1 suite (the Pico example, a host limit), plus 6 scaffold checks, the cross-language ring and the publish gate executed
```

Runner manifest fallback: the runners do not report `traceability-matrix.md` rows individually, so the suite count is the manifest (six language suites plus the two embedded stages), as in loops 12 to 18.

## Verdict: PARTIAL

`failed = 0`. Not run: `cpp-example-pico` (the PlatformIO example; PlatformIO has no linux arm64 build of `toolchain-gccarmnoneeabi ~1.90201.0` on this host, the CI `embedded` job runs it) and the two real-vcpkg checks of the publish gate (no vcpkg tool on this host: printed `NOT RUN`, not a pass). Same three gaps as loop 18.

| Suite / check | Result | Detail |
|---------------|--------|--------|
| golden row, `report-row.test.sh`, `fixtures/hostile/cases.test.sh` + `check-cases.sh`, `cpp/embedded/lib.test.sh`, `ring-wiring.test.sh`, `run-suite.test.sh` (new) | PASS | 27 s; `hostile cases ok: 33` |
| `tsc --noEmit --strict` (host recipe) | PASS | 1 s |
| csharp (`docker compose run csharp`) | PASS | 913 passed on net10.0 and 913 on the `netstandard2.0` build; 37 s |
| typescript | PASS | 728 passed, 0 failed |
| python | PASS | 777 passed (CI image python:3.14) |
| rust | PASS | 533 passed (436 lib + 97 in the other targets), 0 failed |
| java | PASS | all tests, scheme tests, field id binding tests, session tests |
| cpp (CI container, GCC 16, `-Wall -Wextra -Werror`) | PASS | `all tests passed`, 15 of 15 compile-fail cases rejected |
| `.github/workflows/language-pair.sh` (ring) | FAIL then PASS | first run: host `python3` was Apple's 3.9 (`dataclass(slots=True)` needs 3.10+); re-run with `python3` = 3.14 (CI's version) and `PACKBIN_CXX_SYSROOT`: `language pairs passed`, 138 s |
| `.github/workflows/publish-gate.test.sh` | FAIL then PASS | first run lacked `PACKBIN_CXX_SYSROOT` (`'cstddef' file not found`) and the 3.14 `python3` (twine 7.0.0 and the other pins need 3.10+); re-run: `publish gate: no failures`, NOT RUN: vcpkg supports check, vcpkg consumer check; 755 s |
| embedded ARM (`cpp-embedded`) | PASS | `cpp-m4f` AC-5 flash 8064 B of 8192; deepest pack/unpack stack 448 B of 512 (loop 18: 456 B); M0+ and M3 QEMU 241 of 241; s390x PASS |
| embedded ESP (`cpp-embedded-esp`) | PASS except Pico | ESP32-S3 (app image 178 112 B), ESP32-C3, ESP-IDF example, Arduino-ESP32 example PASS; Pico FAIL = the host limit above |

## Reality gate

- The six suites run the real packers and unpackers through each package's public API in the CI containers; the ring runs the real packers and unpackers of every pair on the same bytes.
- Every behavior change of this loop has a test that failed first on the previous code (batch reports 01 and the review fixes in `review19.md`: Java 10 failures on pre-fix sources, TypeScript 4 failures, C# 7 failures, C++ C1 reproduced by reverting one condition).
- Golden `4001000065cd1d00a3e1110100` and the route fixture are unchanged in all six packages. The hostile set grew from 25 to 33 cases and all six loaders replay them (C++ skips two with reasons).

## CI parity

`test.yml` steps: required files and golden row, report columns, hostile case file, suite runner (new `run-suite.test.sh`), embedded harness, ring wiring, the six suites, publish gate (scaffold job); the `embedded` job. All run locally above; the CI `embedded` job also runs the Pico example.

## Lessons from the run

- The ring and the publish gate need `python3` ≥ 3.10 and `PACKBIN_CXX_SYSROOT` on this Mac; both failures on the first pass were the host, not the code. Added to `_docs/AGENT_GOTCHAS.md`.
- `run-suite.sh python` now says why `/tmp/packbin-pytest` is unusable here (no `python` on PATH, only `python3`).
- A reviewer found four confirmed Medium defects the package suites did not (Java count truncation before the round cap, C# count-0 regression, TypeScript skipped count under `when`, C++ source inside a bit body): the one total review earned its place.
