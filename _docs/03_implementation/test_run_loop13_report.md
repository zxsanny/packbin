# Test Run — loop 13

**Date**: 2026-10-05
**Commit under test**: fb9e34c (application code and drivers; `README.md` and `_docs/` are dirty and untested here by design)
**Mode**: functional, Docker (`docker-compose.test.yml`, the jobs `.github/workflows/test.yml` runs: six language suites and the `embedded` job's ARM and ESP stages) plus the scaffold checks, strict `tsc`, `language-pair.sh` and `publish-gate.test.sh`; run as one staged script with a 30 s progress line

```
TEST RESULTS: 951 passed, 0 failed, 0 skipped, 0 errors (csharp 390, typescript 241, python 103, rust 217; java and cpp print per-runner "all tests passed")
SUITE: specified 8 / executed 8 / not-run 0 suites; 1 target inside the ESP stage not run (cpp-example-pico)
```

Runner manifest fallback: `traceability-matrix.md` rows map to tests inside the six language suites; the runners do not report matrix rows individually, so the suite count is the manifest (six language suites + the two embedded stages), as in loop 12.

## Verdict: PARTIAL

Every executed suite and check passed. One specified target was not run on this host: `cpp-example-pico` (PlatformIO `raspberrypi` publishes no Linux arm64 build of `toolchain-gccarmnoneeabi`, `UnknownPackageError`; this Mac runs the ESP container as linux/arm64; known since loop 10, `batch_04_loop10_report.md` #3, and the same reason as loop 12). CI runs it on x86_64. The same CPU core (Cortex-M0+, RP2040) builds and links in the ARM stage.

| Suite / check | Result | Detail |
|---------------|--------|--------|
| csharp | PASS | 390 passed (loop 12: 204) |
| typescript | PASS | 241 passed, 0 todo (loop 12: 108 + 3 todo; the construct-vector todos are now real tests) |
| python | PASS | 103 passed |
| rust | PASS | 217 passed (159 lib + 8 + 9 + 10 + 4 + 2 + 3 + 11 + 11 integration) |
| cpp | PASS | all tests passed; 11 compile-fail cases rejected (GCC 16) |
| java | PASS | PackbinTest, SchemeTest, FieldIdBindingTest, SessionTest: 0 failures |
| embedded ARM (`cpp-embedded`) | PASS | Cortex-M0+ (0 warnings, no `__cxa`/heap references), M3 QEMU (223 vectors run and asserted, session vectors 22), M4F (flash 7728 of 8192 B, deepest stack 488 of 512 B), s390x big-endian (223 vectors, all-kinds packet equals the M3 bytes): 0 targets failed |
| embedded ESP (`cpp-embedded-esp`) | PARTIAL | ESP32-S3 (app image 177 680 B) and ESP32-C3 (147 552 B) ESP-IDF v5.3.2 builds with 0 errors and 0 warnings, the ESP-IDF example from the packed component, the Arduino-ESP32 example from the staged library layout: PASS; Pico example: not run (host) |
| `fixtures/hostile/cases.test.sh` | PASS | |
| `.github/workflows/report-row.test.sh` | PASS | |
| `.github/workflows/publish-gate.test.sh` | PASS | 60 s |
| `tsc --noEmit --strict` (`typescript/src/index.ts`) | PASS | |
| `.github/workflows/language-pair.sh` | PASS | user, nested, boolflag, booltrue, bitwhen, the new `roundflags` and `roundwhen` (C# producing only), session and position rings; 60 s |

## Re-run after the README and docs pass (step 13)

**Date**: 2026-10-05 (evening), same commit fb9e34c with `README.md`, `fixtures/hostile/README.md` and `_docs/` dirty. The README is read by the Python suite (`test_binding.py`), by `cases.test.sh` / `check-cases.sh` (hostile README) and is copied into the packages by the publish scripts, so those stages were re-run, with every other CI stage that does not need the embedded toolchains: strict `tsc`, `cases.test.sh`, `report-row.test.sh`, the six `docker compose` suites, `language-pair.sh`, `publish-gate.test.sh` (11 stages, one script with a 30 s progress line).

Result: ALL 11 STAGES PASS (csharp 390, typescript 241, python 103, rust 217, cpp and java "all tests passed"; the rings and the publish gate pass). `git status` after the run shows only the docs files that were already dirty. The two embedded stages were not re-run: no file they build changed since the first run (`git diff --name-only fb9e34c` lists only `README.md`, `fixtures/hostile/README.md` and `_docs/`), and the Pico target stays not-run on this host. The verdict stays PARTIAL for that one target.

## Reality gate

- Every `unpack` hostile case is replayed against the real packers (Python, TypeScript, C#, Java, Rust, C++ host runner), each with a time guard; every `construct` case is built and must be refused with the rule's own message.
- The cross-language rings run the real drivers of all six packages (the two new rings run the real packers of five: the drivers call the public pack and unpack APIs, no hex is hard-coded, and a review mutated each package to prove the ring fails when an aligned entry is dropped or the rounds are reordered).
- No internal module is stubbed.

## CI parity

CI-parity: PASS — the six `docker compose -f docker-compose.test.yml run --rm <lang>` suites, `cpp-embedded`, `cpp-embedded-esp` (Pico excepted as above), `cases.test.sh`, `report-row.test.sh`, `publish-gate.test.sh`, strict `tsc`, `language-pair.sh`. Five batch-level parity runs (the same set without the embedded stages and the publish gate) were green at each commit.

## Environment notes

- The embedded toolchain cache lives at the gitignored repo-root `.cache/embedded/` (7.7 GB, override `PACKBIN_EMBEDDED_CACHE`); the ESP stage ran from it without downloads (about 4 minutes).
- The C# and TypeScript AC-10 throughput NFRs are load-sensitive in containers; both passed in this run and in every batch run.

## Not run

| Target | Reason | Covered by |
|--------|--------|------------|
| `cpp-example-pico` | no Linux arm64 PlatformIO ARM toolchain on this host | CI `embedded` job on x86_64; Cortex-M0+ core build in the ARM stage |
