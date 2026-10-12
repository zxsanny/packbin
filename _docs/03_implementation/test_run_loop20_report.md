# Test Run — loop 20

**Date**: 2026-10-12
**Commit under test**: first pass `442eaee`, then `803625f` (the only difference: one Python test file, see "Failures found and what they were"). The CI containers ran a clean `git archive` export of the commit; the shell checks, the cross-language ring and the publish gate ran from the live tree.
**Mode**: functional. One total run for the loop, by the owner's direction (2026-10-06): the workers ran only their own package suite; no Docker run per batch. Script: stage by stage, a result line per stage and a heartbeat (`scratchpad/step11.sh`, re-runs `step11b.sh`, `step11c.sh`, `step11d.sh`). The laptop slept several times during the run, so stage durations in the first pass include sleep.

```
TEST RESULTS: 4 416 passed, 0 failed, 0 skipped, 0 errors (csharp 1118 on net10.0 and the same 1118 again on the netstandard2.0 build, typescript 765, python 846, rust 569; java prints PackbinTest checks 1952 and cpp prints "all tests passed")
SUITE: specified 8 / executed 7 / not-run 1 suite (the Pico example, a host limit), plus 6 scaffold checks, the cross-language ring and the publish gate executed
```

Runner manifest fallback: the runners do not report `traceability-matrix.md` rows individually, so the suite count is the manifest (six language suites plus the two embedded stages), as in loops 12 to 19.

## Verdict: PARTIAL

`failed = 0` at the final commit. Not run / not passing on this host: `cpp-example-pico` (PlatformIO has no linux arm64 build of `toolchain-gccarmnoneeabi ~1.90201.0`: `UnknownPackageError`, the CI `embedded` job runs it) and the two real-vcpkg checks of the publish gate (no vcpkg tool on this host: printed `NOT RUN`, not a pass).

| Suite / check | Result | Detail |
|---------------|--------|--------|
| golden row, `report-row.test.sh`, `fixtures/hostile/cases.test.sh` + `check-cases.sh`, `cpp/embedded/lib.test.sh`, `ring-wiring.test.sh`, `run-suite.test.sh` | PASS | 33 s; `hostile cases ok: 40` (first pass: killed by my own 60 s alarm, `cases.test.sh` itself printed `hostile case tests passed`; re-run with a 900 s limit) |
| `tsc --noEmit --strict` (host recipe) | PASS | 5 s |
| csharp (`docker compose run csharp`) | PASS | 1118 passed on net10.0 and 1118 on the `netstandard2.0` build; 33 s on the idle re-run (first pass: see below) |
| typescript | PASS | 765 passed, 0 failed (39 s) |
| python | PASS | 846 passed in 31.6 s (CI image python:3.14; first pass: see below) |
| rust | PASS | 569 passed (472 lib + 97 in the other targets), 0 failed |
| java | PASS | `PackbinTest checks: 1952`, all tests, scheme tests, field id binding tests, session tests (47 s) |
| cpp (CI container, GCC 16, `-Wall -Wextra -Werror`) | PASS | `all tests passed`, 15 of 15 compile-fail cases rejected (44 s) |
| `.github/workflows/language-pair.sh` (ring) | PASS | `language pairs passed` (python3 = 3.14, `PACKBIN_CXX_SYSROOT` set per `AGENT_GOTCHAS.md`) |
| `.github/workflows/publish-gate.test.sh` | PASS | `publish gate: no failures`, NOT RUN: vcpkg supports check, vcpkg consumer check |
| embedded ARM (`cpp-embedded`) | PASS | `cpp-m4f` AC-5 flash 8160 B of 8192 (margin 32 B, was 8064 B in loop 19); deepest pack/unpack stack 448 B of 512; M0+ and M3 QEMU 241 of 241; s390x PASS |
| embedded ESP (`cpp-embedded-esp`) | PASS except Pico | ESP32-S3 (app image 178 224 B), ESP32-C3 (148 128 B), ESP-IDF example, Arduino-ESP32 example PASS; Pico FAIL = the host limit above. The first and second ESP passes failed the Arduino-ESP32 example with `Error during install: unexpected EOF` (a 314 MB download) and Pico once with a PlatformIO SPDX licence download error: network interruptions during a flaky-network period; the third pass was clean |

## Failures found and what they were

| First-pass failure | Cause | Resolution |
|--------------------|-------|-----------|
| C# `Ac10TimingTests` 1427 ms against a 1000 ms bound (netstandard2.0 run) | the machine was loaded (sleep and wake); idle A/B of the same test in the same image: loop 19 commit `857a272` 294 to 320 ms (one pair 369 and 381 ms), loop 20 370 to 388 ms, so the budget code adds about 20 % on the typed round trip, far inside the bound | idle container re-run PASS (1118 and 1118); watch the first CI run after the push (loop 17 lesson: a local pass is not CI parity for a timing bound) |
| Python `test_position.py::test_nfr_round_trips` 3.06 s against 2.0 s | the same load; idle A/B: loop 19 0.70 to 0.78 s, loop 20 0.83 to 0.87 s (13 to 15 % more) | re-run PASS |
| Python `test_pack_output_budget.py::test_ac1_row1_pack_takes_under_a_second_and_under_256_mb`: `ModuleNotFoundError: No module named 'packbin'` | **a real defect in the test the wave 1b worker wrote**: the child process `python -c "from packbin import ..."` found the package only through the worker's editable install, not through pytest's `pythonpath = ["src"]` that the CI container uses | fixed in `803625f` (the child gets the parent's import location through `PYTHONPATH`); re-run 846 passed |
| scaffold group killed with exit 142 | my own 60 s alarm; the chain never reached `run-suite.test.sh`, `lib.test.sh`, `ring-wiring.test.sh` | re-run with 900 s: PASS in 33 s |
| ESP stage: Arduino-ESP32 and Pico | network (above) | clean third pass |

## Reality gate

- The six suites run the real packers and unpackers through each package's public API in the CI containers; the ring runs the real packers and unpackers of every pair on the same bytes; the hostile set is replayed by all six loaders (C++ skips ten with reasons).
- Every behavior change of this loop has a test that failed first on the previous code (batch reports 01 to 04 and `review20.md`: 54 C# tests fail on the HEAD sources for the round binding fix, 9 C++ checks, the Rust and Python regression tests).
- Golden `4001000065cd1d00a3e1110100` and the route fixture are unchanged in all six packages. The hostile set grew from 33 to 40 cases.
- The only accepted-row byte change of the loop (plain `times`, count behind a clear `when`, count 0, no rounds, C++) is documented in the README upgrade note.

## CI parity

`test.yml` steps: required files and golden row, report columns, hostile case file, suite runner, embedded harness, ring wiring, the six suites, publish gate (scaffold job); the `embedded` job. All run locally above; the CI `embedded` job also runs the Pico example. `ring` job: run locally as the `language-pair.sh` stage.

## Lessons from the run

- A subagent's output file is a symlink: a heartbeat must `stat -L` it, and a monitor that measures a symlink reports every healthy worker as stalled.
- `setsid` does not exist on macOS; launch a long script as a harness background task and follow its stage lines.
- Monitor timers and `perl alarm` count wall time, and this laptop sleeps: a stage can show hours of duration, and a monitor expires after "30 minutes" in a few: re-arm, or wait on one single-shot task that exits when the run is done.
- A test that starts a child interpreter must give the child the parent's import path; it passed for a worker with an editable install and failed in the clean CI container.
