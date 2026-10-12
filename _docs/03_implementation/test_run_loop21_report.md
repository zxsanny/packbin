# Test Run — loop 21

**Date**: 2026-10-12
**Commit under test**: `3acc589` (loop 21 implementation batch); the tree was clean apart from `_docs/` reports. Docker containers mount the working tree.
**Mode**: functional. One total run for the loop, by the owner's direction (2026-10-06): workers ran only their own package suite; no Docker run per batch. Script: stage by stage, a result line per stage, a heartbeat every 30 s (`stat -L` on the stage log). Total wall time 1 297 s, no restart.

```
TEST RESULTS: 5 466 passed, 0 failed, 0 skipped, 0 errors (csharp 1479 on net10.0 and the same 1479 again on the netstandard2.0 build, typescript 880, python 1003, rust 625; java prints PackbinTest checks 2153 and "All tests passed"; C++ prints "all tests passed")
SUITE: specified 8 / executed 7 / not-run 1 suite (the Pico example, a host limit), plus 6 scaffold checks, the cross-language ring and the publish gate executed
```

## Verdict: PARTIAL

`failed = 0` at the commit under test. Not run on this host: `cpp-example-pico` (PlatformIO has no linux arm64 build of `toolchain-gccarmnoneeabi ~1.90201.0`: `UnknownPackageError`; the CI `embedded` job runs it on x86-64). Same host limit as loops 19 and 20. NOT RUN inside the publish gate: vcpkg supports check and vcpkg consumer check (no vcpkg tool on the host).

| Suite / check | Result | Detail |
|---------------|--------|--------|
| golden row, `report-row.test.sh`, `fixtures/hostile/cases.test.sh` + `check-cases.sh`, `cpp/embedded/lib.test.sh`, `ring-wiring.test.sh`, `run-suite.test.sh` | PASS | 54 s; `hostile cases ok: 55` (40 + 15 new) |
| `tsc --noEmit --strict` (host recipe) | PASS | 1 s |
| csharp (`docker compose run csharp`) | PASS | 1479 passed on net10.0 and 1479 on `netstandard2.0` (1118 at loop 20); 50 s |
| typescript | PASS | 880 passed, 0 failed (765 at loop 20); 9 s; the AZ-2391 timing test passed on the idle machine |
| python | PASS | 1003 passed in 31.5 s (846 at loop 20), CI image python:3.14 |
| rust | PASS | 625 passed (569 at loop 20), 0 failed; 31 s |
| java | PASS | `PackbinTest checks: 2153` (1952), all tests, scheme tests, field id binding tests, session tests; 10 s |
| cpp (CI container, GCC 16, `-Wall -Wextra -Werror`) | PASS | `all tests passed`, compile-fail cases rejected; 18 s |
| `.github/workflows/language-pair.sh` (ring) | PASS | 107 s (python3 = 3.14, `PACKBIN_CXX_SYSROOT` set per `AGENT_GOTCHAS.md`) |
| `.github/workflows/publish-gate.test.sh` | PASS | 745 s, `publish gate: no failures`, NOT RUN: vcpkg supports check, vcpkg consumer check |
| embedded ARM (`cpp-embedded`) | PASS | `cpp-m4f` AC-5 flash **8152 B of 8192 (margin 40 B**, was 8160 B); deepest pack/unpack stack **456 B of 512** (margin 56 B, was 448 B); largest core frame 528 B; M0+ PASS; M3 QEMU 241 of 241 vectors; s390x 241 of 241 |
| embedded ESP (`cpp-embedded-esp`) | PASS except Pico | ESP32-S3 (app image 178 192 B), ESP32-C3 (148 112 B), ESP-IDF example, Arduino-ESP32 example PASS; Pico FAIL = the host limit above |

## Failures found

None at the commit under test. No first-pass failure, no re-run. The two timing tests that flaked in loop 20 (C# `Ac10TimingTests`, Python `test_nfr_round_trips`) passed on this idle run; the TypeScript AZ-2391 ratio test that flaked once under parallel worker load in wave 2 passed (880 of 880).

## Reality gate

- The six suites run the real packers and unpackers through each package's public API in the CI containers; the ring runs the real packers and unpackers of every pair on the same bytes; the hostile set replays the 55 cases (15 new) through six loaders.
- Every behavior change has a test that failed first on the previous code for the packages that report it (Rust: 22 of 49 new tests failed on a `git archive HEAD` copy; C#: the 37-test claim of the AZ-2373 spec was 7 failing cases; the others pinned reference rows).
- Golden `4001000065cd1d00a3e1110100` and the route fixture are unchanged in all six packages.
- Accepted-row byte changes of the loop: none (reference rows 29, 30, 38, 40 to 42 pack the bytes they packed before or the bytes the reference pins).

## CI parity

`test.yml` steps: required files and golden row, report columns, hostile case file, suite runner, embedded harness, ring wiring, the six suites, publish gate (scaffold job); the `embedded` job; the `ring` job. All run here except the Pico example and the two vcpkg checks.

## Lessons from the run

- A staged script with a per-stage log and a `stat -L` heartbeat made the 12 minute publish gate readable: it writes in bursts, so "quiet 60 to 100 s" was normal and a `ps` of its children (build scripts, compose) settled it each time.
- A cached docker image makes a stage 10 times faster than last loop (ARM 8 s against about 3 minutes): check the log for the numbers, not the time.
