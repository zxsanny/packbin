---
loop: 121
branch: dev
---

# C++ hygiene: s390x percentage compare, sanitizer-safe timing checks, pinned Arduino-ESP32 core

**Task**: AZ-4261_cpp_hygiene
**Name**: C++ hygiene: s390x percentage compare, sanitizer-safe timing checks, pinned Arduino-ESP32 core
**Description**: entries of the hygiene queue item `_docs/02_task_plans/hygiene-loop121/queue_item.md` (loop 121), below; their text is the spec.
**Complexity**: 5 points
**Dependencies**: none
**Component**: cpp/embedded/, cpp/tests/core/, cpp/Makefile, .github/workflows/test.yml (job embedded-esp-core only), _docs/gotchas/
**Tracker**: AZ-4261
**Epic**: AZ-4133

C++ only. Decision D15 (applied): under a sanitizer build (`__has_feature(address_sanitizer)` / `__SANITIZE_ADDRESS__`) timing checks print their measurement and do not assert; every plain build keeps its bounds.

Each entry below: its Problem, Outcome, Code sections and Acceptance checks are this task's; an acceptance check that names another package belongs to that package's task. Common: no packet change, every refusal text of a path the entry does not name stays the same, the package suite passes.

## Entry: C++ big-endian row: compare the percentage packets with the Cortex-M3 file

slug `s390x-percentage-packets-vs-m3`; severity low; source: loop98 record (leftovers: "the s390x stage does not compare its percentage packets with the M3 file"); `cpp/embedded/arm.sh` `target_s390x`; created 2026-11-12
### Problem
The `cpp-m33f` row compares its `PERCENT_HEX` packets (parity percentage, loop 97) with `m3-percent.hex` written by `cpp-m3-qemu`. The big-endian `cpp-s390x` row compares only the all-kinds packet with `m3-all-kinds.hex`; its percentage packets are printed and not compared.

### Outcome
The s390x row fails when a percentage packet differs from the Cortex-M3 bytes.

### Code sections
`cpp/embedded/arm.sh` (`target_s390x`, `percent_packets`), `cpp/embedded/lib.test.sh`, `cpp/embedded/run-parts.test.sh`.

### Acceptance checks
- `target_s390x` writes its percentage packets with `percent_packets` and compares them with `m3-percent.hex`, as `target_m33f` does; a missing M3 file is reported the way the all-kinds check reports it.
- The stub tests of `lib.test.sh` cover the equal and the differing case.
- `docker compose -f docker-compose.test.yml run --rm cpp-embedded` passes.

### Needs
none

### Constraints
No pin and no core source changes.

## Entry: C++: wall-clock bounds in a sanitizer build of the host suite

slug `cpp-wall-clock-bounds-under-sanitizers`; severity medium; source: found in loop114 (AZ-4237 smoke: the ASan + UBSan host suite); created 2026-11-12
### Problem
Under clang `-fsanitize=address,undefined` the C++ host suite reports no memory or UB error since AZ-4237, but the text speed check "AC-7 100,000 round trips within one second" fails in about one run of two (1.015 s against 1.012 s, 1.017 s against 1.004 s, loop 114, host load 9 to 50). `load_factor.hpp` scales a bound by an integer xorshift loop that ASan does not instrument, while the timed text code is memory work that ASan slows, so the factor does not see the sanitizer's cost. The plain Apple clang and GCC 16 builds hold the bound. This blocks running the host suite under ASan in CI, which the loop 113 security audit recommends (long term).

### Outcome
A sanitizer build of `build/packbin_tests` prints `all tests passed` on this Mac and on the CI runner, while the plain builds keep every wall-clock bound as it is.

### Code sections
`cpp/tests/core/load_factor.hpp` (the factor, `expect_within`), `cpp/tests/core/text_codec_host_tests.cpp:264`, and every other `expect_within` / `load_factor::bound` caller (`hostile_host_tests.cpp`, the ECC and text-repeat timing lines); `cpp/Makefile` if a sanitizer target is added.

### Acceptance checks
- A sanitizer build (`-fsanitize=address,undefined -fno-sanitize-recover=all`) passes 5 runs in a row on this Mac with no sanitizer report.
- `make -C cpp test` (Apple clang) and `gcc:16` `make test` pass, and a deliberately slowed timed section still fails the plain build (a check on a broken copy).

### Needs
none

### Constraints
Do not widen the bounds of the plain build. One way, to be chosen in the task: the timing checks print but do not assert when `__has_feature(address_sanitizer)` / `__SANITIZE_ADDRESS__` is set.

## Entry: C++: pin the Arduino-ESP32 core of the ESP core stage

slug `esp-core-arduino-pin`; severity medium; source: found in loop113 (AZ-4219 report: "the ESP stage installs the newest Arduino-ESP32 core, 3.3.12 today, unpinned; 525 s"); created 2026-11-12
### Problem
`bash cpp/embedded/run.sh host esp core` installs the newest Arduino-ESP32 core at run time (3.3.12 on 2026-11-12) and took 525 s on this host in loop 113 (about 3 minutes expected). A new core release can change the build or the time with no change in this repository, and the CI job `embedded-esp-core` has the same exposure.

### Outcome
The core version is pinned in one place that both the Mac run and the CI job read, with a gotcha file under `_docs/gotchas/` (and its line in `_docs/gotchas/INDEX.md`) saying how to move it.

### Code sections
`cpp/embedded/esp.sh`, `cpp/embedded/run.sh`, the Docker image or the PlatformIO / arduino-cli configuration it uses, `.github/workflows/test.yml` job `embedded-esp-core`, `cpp/embedded/*.test.sh`.

### Acceptance checks
- The stage prints the core version it uses and fails if it differs from the pin.
- `bash cpp/embedded/run.sh host esp core` passes with the pinned core; the stub tests of `lib.test.sh` and `run-parts.test.sh` pass.
- The pin and its date are recorded where the other tool pins are (`.github/workflows/tool-pin.sh` if the project keeps tool pins there).

### Needs
none

### Constraints
The source count of the stage (`expected N packbin sources`) does not change.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| agent-found hygiene entries; no operator decision outstanding (D14, D15 applied) | agent | accepted-risk | Low |
