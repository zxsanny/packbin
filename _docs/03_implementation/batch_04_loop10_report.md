# Batch Report

**Batch**: 4
**Tasks**: AZ-2064_cpp_host_on_core, AZ-2066_cpp_target_ci, AZ-2067_cpp_embedded_packaging
**Date**: 2026-10-05

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2064_cpp_host_on_core | Done | old walker deleted (9 src, 1 header, 6 tests); drivers, scripts, README, Makefile | host suite pass; language pairs pass | None |
| AZ-2066_cpp_target_ci | Done (subagent + parent) | cpp/embedded/**, test.yml, docker-compose.test.yml, core walkers | every target below PASS | 2 High fixed |
| AZ-2067_cpp_embedded_packaging | Done; AC-2 not run (needs a published tag) | library.json, idf_component.yml, CMakeLists.txt, arduino/, examples/, publish scripts, README, languages.md | examples PASS; publish gate test PASS up to an unrelated Docker Hub pull | 3 fixed |

## Code Review Verdict: PASS_WITH_WARNINGS

`reviews/batch_04_loop10_review.md`

## Test Suite

| Target | Result | Evidence |
|--------|--------|----------|
| Host (Apple clang 21, gcc:16 container) | PASS | `all tests passed`; 7 compile-fail cases; nfr 13–24 ms |
| Language pairs (6 languages) | PASS | `language pairs passed` |
| Cortex-M0+ build | PASS | 0 warnings; link refs `__cxa_*` 0, heap 0 |
| Cortex-M3 QEMU mps2-an385 | PASS | vectors run 184 = asserted 184; malloc/new wrapper calls 0; session vectors 22, OS random refs 0 |
| Cortex-M4F size/stack | PASS | flash core + 14-field table 7600 B ≤ 8192; deepest pack/unpack 464 B ≤ 512 (raw 528 − 64 meter); .data/.bss 0 |
| s390x big-endian QEMU user | PASS | vectors 184/184; all-kinds packet equals Cortex-M3 bytes |
| ESP32-S3 ESP-IDF 5.3.2 | PASS | 0 errors, 0 warnings, AC-1 flags on every packbin source |
| ESP32-C3 ESP-IDF 5.3.2 | PASS | 0 errors, 0 warnings |
| ESP-IDF example (packed component) | PASS | built from `packbin_0.0.0.tgz` |
| Pico example (pio package archive, amd64) | PASS | `[SUCCESS]`, flash 4034 B; 3 warnings, all in the Pico SDK |
| Arduino-ESP32 example (staged layout) | PASS | sketch 273 732 B (20%), globals 22 116 B; 0 warnings from packbin (after the `flag_bit` rename) |

CI-parity: PASS — `make test` (host), `docker compose -f docker-compose.test.yml run --rm cpp` (gcc:16), `bash .github/workflows/language-pair.sh`, `cpp/embedded/run.sh arm` in `packbin-embedded:local`, ESP targets in `espressif/idf:v5.3.2`.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | README contract: dict keys go out "in unsigned byte order"; the core wrote caller order | AZ-2063, README | Pack refuses keys that are not strictly ascending (BadValue; also catches duplicates); unpack stays lenient like the old C++ | clear |
| 2 | Arduino.h defines function-like macros (`bit`, `min`, `max`, …) | AZ-2067 AC-1 | Builder renamed `flag_bit`; checked the headers for other colliding callables (none) | clear |
| 3 | PlatformIO `raspberrypi` has no Linux arm64 toolchain | AZ-2067 AC-1 | The Pico example runs in an amd64 container locally; CI runners are x86_64 | clear |
| 4 | The Pico mbed framework does not build with `-std=gnu++17` | AZ-2067 | Projects add `build_src_flags = -std=gnu++17`; packbin's own sources get C++17 from `library.json`; README says so | clear |
| 5 | Stack meter counts its own 64 B guard | AZ-2066 AC-5 | Report raw and raw − empty-call baseline; budget is checked on the calibrated value | clear |
| 6 | The Arduino Library Manager needs `library.properties` at a repository root | AZ-2067 | Generated `arduino` branch + `arduino-<version>` tag, like the vcpkg port; one-time registration with arduino/library-registry by the maintainer | unclear — maintainer action |
| 7 | AC-12 (install by registry name) needs a published tag and PlatformIO / ESP-IDF registry tokens | AZ-2067 AC-2 | Not run in this loop; publish steps skip without tokens (gate test) | unclear — maintainer tokens |
| 8 | The embedded CI job downloads ~2 GB per run | AZ-2066 | Add an `actions/cache` step (refactor check) | clear |

## Commit

`[AZ-2064] [AZ-2066] [AZ-2067] Move C++ to the core and add embedded CI`

## Next Batch: AZ-2068_cpp_avr_build (stretch)
