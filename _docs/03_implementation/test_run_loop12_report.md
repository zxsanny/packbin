# Test Run — loop 12

**Date**: 2026-10-05
**Commit under test**: 37ed334 (application code); the embedded cache location and the publish-gate copy excludes changed after it and were re-run below
**Mode**: functional, Docker (`docker-compose.test.yml`, the jobs `.github/workflows/test.yml` runs: six language suites and the `embedded` job's ARM and ESP stages) plus the scaffold checks, strict `tsc` and `language-pair.sh`

```
TEST RESULTS: 550 passed, 0 failed, 3 skipped (TypeScript todo, AZ-2090), 0 errors (csharp 204, typescript 108, python 103, rust 135; java and cpp print per-runner "all tests passed")
SUITE: specified 8 / executed 8 / not-run 0 suites; 1 target inside the ESP stage not run (cpp-example-pico)
```

Runner manifest fallback: `traceability-matrix.md` rows map to tests inside the six language suites; the runners do not report matrix rows individually, so the suite count is the manifest (six language suites + the two embedded stages).

## Verdict: PARTIAL

Every executed suite and check passed. One specified target was not run on this host: `cpp-example-pico` (PlatformIO `raspberrypi` publishes no Linux arm64 build of `toolchain-gccarmnoneeabi`; this Mac runs the ESP container as linux/arm64; known since loop 10, `batch_04_loop10_report.md` #3). CI runs it on x86_64. The same CPU core (Cortex-M0+, RP2040) builds and links in the ARM stage.

| Suite / check | Result | Detail |
|---------------|--------|--------|
| csharp | PASS | 204 passed |
| typescript | PASS | 108 passed, 3 todo (AZ-2090 construct vectors) |
| python | PASS | 103 passed |
| rust | PASS | 115 lib + 6 + 10 + 4 = 135 passed |
| cpp | PASS | all tests passed; 11 compile-fail cases rejected (GCC 16) |
| java | PASS | PackbinTest, SchemeTest, FieldIdBindingTest, SessionTest: 0 failures |
| embedded ARM (`cpp-embedded`) | PASS | Cortex-M0+, M3 (QEMU), M4F (flash 7728 / 8192 B, stack 488 / 512 B), s390x big-endian: 0 failures |
| embedded ESP (`cpp-embedded-esp`) | PARTIAL | ESP32-S3 and ESP32-C3 ESP-IDF builds (0 errors, 0 warnings), ESP-IDF example from the packed component, Arduino-ESP32 example: PASS; Pico example: not run (host) |
| `fixtures/hostile/cases.test.sh` | PASS | |
| `.github/workflows/report-row.test.sh` | PASS | |
| `.github/workflows/publish-gate.test.sh` | PASS | 56 s |
| `tsc --noEmit --strict` (`typescript/src/index.ts`) | PASS | |
| `.github/workflows/language-pair.sh` | PASS | user, nested, boolflag, booltrue, bitwhen (5 languages), session, position rings |

## Reality gate

- Every `unpack` hostile case is replayed against the real packers (Python, TypeScript, C#, Java, Rust, C++ host runner), each with a time guard; every `construct` case is built and must be refused with the rule's own message (C#, TypeScript, Python, Java, Rust).
- The cross-language rings run the real drivers of all six packages (Python joins `bitwhen` with its split form, AZ-2100).
- No internal module is stubbed.

## CI parity

CI-parity: PASS — the six `docker compose -f docker-compose.test.yml run --rm <lang>` suites, `cpp-embedded`, `cpp-embedded-esp` (Pico excepted as above), `cases.test.sh`, `report-row.test.sh`, `publish-gate.test.sh`, strict `tsc`.

## Environment notes

- The embedded toolchain cache (arduino-cli, the Arduino ESP32 core 3.3.12, PlatformIO; 7.7 GB) moved twice this run. First from `cpp/build/embedded` (wiped by `make clean` / build cleanups) to `cpp/embedded/.cache`. Then to the repo-root `.cache/embedded/` (override `PACKBIN_EMBEDDED_CACHE`), because `compote component pack` walks every file under `cpp/` before applying its include list and stalled for minutes. `publish-gate.test.sh` `copy_tree` now excludes `.cache` and `cpp/build` (a CI checkout has neither); before that it copied the whole cache into a temp dir per registry.
- The C# and TypeScript AC-10 throughput NFRs are load-sensitive in the containers on this host (other projects' Docker stacks running); this run passed both.

## Not run

| Target | Reason | Covered by |
|--------|--------|------------|
| `cpp-example-pico` | no Linux arm64 PlatformIO ARM toolchain | CI `embedded` job on x86_64; Cortex-M0+ core build in the ARM stage |
