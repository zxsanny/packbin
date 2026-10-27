---
loop: 74
branch: dev
---

# C++ without the stream session; crypto kept and verified

**Task**: AZ-3286_cpp_stream_removal_crypto
**Name**: Remove `PackSession` and the OS random source from the C++ package; keep its crypto as an internal module on the 27 crypto rows
**Description**: C++ has no stream session; its SHA-256, HMAC, HKDF and ChaCha20 are ready for the frame port; the embedded pins hold.
**Complexity**: 5 points
**Dependencies**: AZ-3280_ring_ci_stream_removal
**Component**: 05_cpp_package
**Tracker**: AZ-3286
**Epic**: AZ-3199

## Problem

`cpp/include/packbin/session.hpp` and `cpp/src/core/session.cpp` are the stream session (ADR-009); `os_random` exists only to give it a nonce. `session.cpp` also holds the package's only SHA-256, HMAC, HKDF, ChaCha20 and wipe, in an anonymous namespace, never checked against `fixtures/crypto/vectors.txt`; the frame port (loop 75) needs them (D2). Several CI scripts compile these files by path.

## Outcome

- 0 stream-session types and 0 OS random source; the crypto is an internal core module that passes 27 of 27 crypto rows on the host; the embedded pins are unchanged.

## Scope

### Included
- Delete `include/packbin/session.hpp`, `src/core/session.cpp`, `include/packbin/os_random.hpp`, `src/os_random.cpp`, `tests/core/session_tests.cpp`, `ecc_session_host_tests.cpp`, `session_host_tests.cpp` (its OS-header scan of the core is kept, moved to another host test).
- The crypto moves to an internal core module (heap-free, `packbin/platform.hpp` names only) with a host test that reads all 27 rows of `fixtures/crypto/vectors.txt`.
- `CMakeLists.txt` (the session source and the `PACKBIN_OS_RANDOM` option), `Makefile` (sources and test lists), `include/packbin/packbin.hpp`, `arduino/packbin.h`, `codec.hpp` helpers that lose their only caller, `tests/core/main.cpp`, `dict_order_host_tests.cpp`, `no_ecc_tests.cpp`, `examples/esp_idf/main/main.cpp` (no session demo, no `esp_random`).
- `cpp/embedded/lib.sh`, `common/vectors_main.cpp`, `arm.sh` (the session vector note).
- C++ paths compiled elsewhere: `.github/workflows/ring-lib.sh`, `publish-position.sh`, `publish-vcpkg.test.sh`, `fixtures/hostile/fuzz/cpp/` (`build_cpp.sh` and the probes).

### Excluded
- Frame mode itself (AZ-3292, loop 75); README (AZ-3291); the C++ ring driver (AZ-3280).

## Acceptance Criteria

**AC-1: No stream session**
Given the C++ package and the scripts that build it
When `git grep -nE 'PackSession|session\.hpp|session\.cpp|os_random|RandomFn' cpp .github fixtures/hostile/fuzz/cpp` runs
Then it finds 0 hits

**AC-2: Crypto verified**
Given `fixtures/crypto/vectors.txt`
When the new host test runs
Then 27 of 27 rows pass, and a row with one changed hex digit fails (1 of 1 mutant caught)

**AC-3: Embedded pins hold**
Given `cpp/embedded` (arm, AVR)
When it runs
Then `cpp-m4f` is 7,712 B of flash and 540 B of stack, `cpp-m33f` 25,720 B and 724 B, the AVR Uno image builds, the vector runners pass, and the core keeps 0 B of writable data

**AC-4: Suites green on both compilers**
Given `make -C cpp test` on the Mac and `gcc:16` in Docker (`-Wall -Wextra -Werror`)
When they run
Then 0 failures and 0 warnings; the ESP-IDF example and the vcpkg and position publish checks build

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | the grep | 0 hits |
| AC-2 | crypto vector host test plus mutant | 27/27; mutant caught |
| AC-3 | `cpp/embedded` arm and AVR stages | pins equal; runners pass |
| AC-4 | host and `gcc:16` suites; `publish-vcpkg.test.sh`; examples stage | 0 failures, 0 warnings |

## Constraints

- The core takes standard names only from `packbin/platform.hpp` (AVR target, `AGENT_GOTCHAS.md`, loop 44).
- `make -C cpp clean` between host and `gcc:16` builds (shared `cpp/build/`).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The crypto module has no caller until the frame port | owner D2 | accepted-risk | Low |
| The ESP-IDF example loses its session demo | ADR-009 | resolved | Low |
