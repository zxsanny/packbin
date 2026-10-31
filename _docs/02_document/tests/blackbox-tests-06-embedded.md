# Blackbox Tests 6: C++ on microcontrollers

Part of the blackbox set; the index is [blackbox-tests.md](blackbox-tests.md).

### FT-E-01: The core builds the embedded way

**Summary**: The core builds the embedded way (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: cpp-microcontroller AC-1
**Category**: Resource

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: core sources with `-std=c++17 -fno-exceptions -fno-rtti -Os -Wall -Wextra -Werror`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | compile for Cortex-M0+, Cortex-M4F, ESP32-S3 and ESP32-C3 | each build: errors 0, warnings 0 |

**Expected outcome**: each build: errors 0, warnings 0.
**Max execution time**: 60s

### FT-E-02: No heap and no exceptions in a firmware image

**Summary**: No heap and no exceptions in a firmware image (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: cpp-microcontroller AC-2
**Category**: Resource

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: one firmware using every field kind, linked with aborting malloc/new wrappers

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | link, then run on QEMU `mps2-an385` | `__cxa_throw` and `__cxa_allocate_exception` references 0; wrapper calls 0 |

**Expected outcome**: `__cxa_throw` and `__cxa_allocate_exception` references 0; wrapper calls 0.
**Max execution time**: 60s

### FT-E-03: The same bytes on the target CPU

**Summary**: The same bytes on the target CPU (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: cpp-microcontroller AC-3
**Category**: Bytes

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: every hex vector asserted in `cpp/tests/core` and `fixtures/golden.hex`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack each row and unpack each hex on QEMU `mps2-an385` | differing bytes 0; differing fields 0; vectors run equals vectors asserted (213) |

**Expected outcome**: differing bytes 0; differing fields 0; vectors run equals vectors asserted (213).
**Max execution time**: 60s

### FT-E-04: The same bytes on a big-endian CPU

**Summary**: The same bytes on a big-endian CPU (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: cpp-microcontroller AC-4
**Category**: Bytes

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: the same vectors

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | run the core test under QEMU user `s390x` | mismatched bytes 0; mismatched fields 0 |

**Expected outcome**: mismatched bytes 0; mismatched fields 0.
**Max execution time**: 60s

### FT-E-05: Flash and stack budget

**Summary**: Flash and stack budget (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: cpp-microcontroller AC-5, AZ-2078 AC-5, AZ-2081 AC-5
**Category**: Resource

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: the all-kinds firmware on Cortex-M4F

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | read `size` and `-fstack-usage` reports | core plus a 14-field table at most 8192 B of flash; deepest pack or unpack at most 512 B of stack; `.data` and `.bss` 0 B |

**Expected outcome**: core plus a 14-field table at most 8192 B of flash; deepest pack or unpack at most 512 B of stack; `.data` and `.bss` 0 B.
**Max execution time**: 60s

### FT-E-06: Errors are values

**Summary**: Errors are values (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: cpp-microcontroller AC-6
**Category**: Errors

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: a packet one byte short, one trailing byte, a wrong type number, an output one byte small, one group too many

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | unpack or pack each | `ShortPacket`, `TrailingBytes`, `TypeMismatch`, `BufferFull`, `TooMany`, each with offset and field id; bytes written past the offset 0; aborts 0 |

**Expected outcome**: `ShortPacket`, `TrailingBytes`, `TypeMismatch`, `BufferFull`, `TooMany`, each with offset and field id; bytes written past the offset 0; aborts 0.
**Max execution time**: 1s

### FT-E-07: Scheme order is checked without throwing

**Summary**: Scheme order is checked without throwing (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: cpp-microcontroller AC-7
**Category**: Errors

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: a gap, a repeated id, a wrong anchor and a `when` naming an id not yet walked

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | compile a `constexpr` scheme; validate a runtime scheme | compile error naming the id; `SchemeInvalid` with that id; bytes written 0 |

**Expected outcome**: compile error naming the id; `SchemeInvalid` with that id; bytes written 0.
**Max execution time**: 1s

### FT-E-08: Strings and bytes are borrowed

**Summary**: Strings and bytes are borrowed (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: cpp-microcontroller AC-8
**Category**: Bytes

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: a 40-byte `utf8` field and a 16-byte `bytes` field

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | unpack into a `View` row; unpack into `Text<16>` | view points into the input with length 40, bytes copied 0; the fixed destination gives `TooMany` |

**Expected outcome**: view points into the input with length 40, bytes copied 0; the fixed destination gives `TooMany`.
**Max execution time**: 1s

### FT-E-09: `f64` needs an 8-byte double

**Summary**: `f64` needs an 8-byte double (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: cpp-microcontroller AC-9
**Category**: Errors

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: a build whose `double` is 4 bytes

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | compile a scheme with `f64`; compile one with `f32` only | a `static_assert` naming `f64`; the `f32` build succeeds (host stand-in until the avr-gcc task) |

**Expected outcome**: a `static_assert` naming `f64`; the `f32` build succeeds (host stand-in until the avr-gcc task).
**Max execution time**: 60s

### FT-E-10: The session runs on the board (retired, loop 74)

> **Retired in loop 74 (ADR 009, AZ-3286).** The C++ stream session (`session.hpp`, `session.cpp`, `os_random`) is removed, so no board runs this scenario; the text below is history. The core's internal crypto module (`src/core/crypto.cpp`) is checked on the host by `crypto_vectors_host_tests.cpp` (27 rows); C++ frame mode and its board run come with AZ-3292 (loop 75). The OS-call scan of the core moved to `host_tests.cpp`.

**Summary**: The session ran on the board (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: cpp-microcontroller AC-10
**Category**: Bytes

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: a 32-byte seed, a caller random function and the pack-session vectors

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | run `start`, `join`, `pack` and `unpack` on QEMU `mps2-an385` | padded bytes equal the vectors; OS random references 0; a failing random function makes `start` return an error with 0 bytes padded |

**Expected outcome**: padded bytes equal the vectors; OS random references 0; a failing random function makes `start` return an error with 0 bytes padded.
**Max execution time**: 60s

### FT-E-11: Host programs use the core API

**Summary**: Host programs use the core API (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: cpp-microcontroller AC-11
**Category**: Bytes

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: `make test` in `cpp/`, the compile-fail check and the C++ side of the language pairs

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | run on the host | failures 0; vectors dropped 0; 100000 round trips within 1 s; old walker references 0; each removed symbol has a README migration row |

**Expected outcome**: failures 0; vectors dropped 0; 100000 round trips within 1 s; old walker references 0; each removed symbol has a README migration row.
**Max execution time**: 10s

### FT-E-12: Installable from the embedded registries

**Summary**: Installable from the embedded registries (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: cpp-microcontroller AC-12
**Category**: Bytes

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: a published tag

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | a fresh PlatformIO, Arduino-ESP32 and ESP-IDF project add packbin by name and build the README example | three builds succeed; local overrides 0; installed version equals the tag |

**Expected outcome**: three builds succeed; local overrides 0; installed version equals the tag.
**Max execution time**: —

### FT-E-13: Every target runs in CI

**Summary**: Every target runs in CI (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: cpp-microcontroller AC-13
**Category**: Resource

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: a push to any branch

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | the `embedded` job of `test.yml` runs | one report row per target; a failing target fails the workflow |

**Expected outcome**: one report row per target; a failing target fails the workflow.
**Max execution time**: —


### FT-E-14: `chacha20_xor` runs on a 16-bit AVR (loop 92)

**Summary**: One image runs on `simavr` (ATmega328P, 16 MHz) and checks `chacha20_xor` on a 16-bit `int` and `size_t` (AZ-3452).
**Traces to**: AZ-3452 AC-1 to AC-6
**Category**: Bytes

**Preconditions**:
- The `packbin-embedded` image with `simavr`; the core's crypto file built with the Uno flags

**Input data**: key `00..1f`; the RFC 8439 2.4.2 nonce, counter 1 and 114-byte plaintext; lengths 0, 1, 63, 64, 65, 114, 127, 128, 129; the five counter-edge cases of the host test `block_counter_edge`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | the `cpp-avr-uno` row runs the image on `simavr` | the UART report equals `cpp/embedded/avr/chacha20_expected.txt`: `SIZES size_t=2 int=2`, `RFC 114/114`, `STREAM 9/9`, `RESTORED 9/9`, `EDGE 5/5`, `DONE` |
| 2 | one expected byte changed; a defect in `chacha20_xor`; an image that never ends; `simavr` missing; `simavr` silent | the row fails and names the cause (diff, 30 s limit, missing tool) |

**Expected outcome**: the row passes with the report above and fails on each of the five defects.
**Not run by**: a real ATmega328P; a buffer near 64 KiB (the part has 2 KB of RAM)
**Max execution time**: 30s for the emulator run
