# Acceptance criteria — C++ on microcontrollers

Inherited: project acceptance criteria stay in force (AC-1 golden bytes, AC-10 host throughput, AC-16 MIT), and so do the `scheme-field-order` and `pack-session` criteria. This feature does not change any byte on the wire. Reference target for size and stack numbers: Cortex-M4F, arm-none-eabi GCC 13, `-Os -mthumb -mcpu=cortex-m4 -mfloat-abi=hard`, newlib-nano.

## Criteria

**AC-1: Builds the embedded way.**
Given the core headers and sources and the flags `-std=c++17 -fno-exceptions -fno-rtti -Os -Wall -Wextra -Werror`.
When they are compiled for Cortex-M0+ (`thumbv6m`), Cortex-M4F, ESP32-S3 (ESP-IDF ≥ 5.1, xtensa) and ESP32-C3 (ESP-IDF ≥ 5.1, RISC-V).
Then each build has 0 errors and 0 warnings.

**AC-2: No heap and no exceptions in a firmware image.**
Given a firmware that packs and unpacks one scheme using every field kind (u8…u64, i8…i64, f32, f64, bytes, bool, flags, flag byte bits, when, repeat, group, sized, u2, bits, packed, times, utf8, list, dict), linked with `-Wl,--wrap=malloc,--wrap=calloc,--wrap=realloc,--wrap=_Znwj,--wrap=_Znaj` wrappers that abort.
When the image is linked and run on the QEMU Cortex-M3 machine (`mps2-an385`).
Then the link map references `__cxa_throw` 0 times and `__cxa_allocate_exception` 0 times, and the malloc/new wrappers are called 0 times.

**AC-3: Same bytes on the target CPU.**
Given every hex vector asserted in `cpp/tests/*.cpp` and the row in `fixtures/golden.hex`.
When the firmware packs each row and unpacks each hex on QEMU `mps2-an385`.
Then packed bytes differ from the vector in 0 bytes, unpacked values differ in 0 fields, and the number of vectors run equals the number asserted in `cpp/tests` (none skipped).

**AC-4: Same bytes on a big-endian CPU.**
Given the same vectors.
When the core test runs on a big-endian Linux host (QEMU user mode `s390x` or `ppc64`, in the CI container).
Then mismatched bytes are 0 and mismatched fields are 0.

**AC-5: Flash and stack budget.**
Given the AC-2 firmware.
When `arm-none-eabi-size` and `-fstack-usage` reports are read for the reference target.
Then core code plus one 14-field scheme table is ≤ 8 KB of flash, the deepest pack or unpack call uses ≤ 512 bytes of stack, and the core adds 0 bytes of `.data`/`.bss`.

**AC-6: Errors are values.**
Given a packet one byte short, a packet with one trailing byte, a packet with the wrong type number, an output buffer one byte too small, and a `repeat` with one more group than the caller storage holds.
When each is unpacked or packed by the core.
Then the result is `ShortPacket`, `TrailingBytes`, `TypeMismatch`, `BufferFull` and `TooMany` respectively, with the byte offset and field id of the failure; output bytes written beyond the reported offset: 0; process aborts: 0.

**AC-7: Scheme order checked without throwing.**
Given each invalid scheme from the `scheme-field-order` criteria (gap, repeated id, wrong anchor, `when` naming an id not yet walked).
When a `constexpr` scheme is compiled, or a runtime-built scheme is validated.
Then the `constexpr` case fails to compile with a message naming the field id, and the runtime case returns `SchemeInvalid` with that field id. Bytes written: 0.

**AC-8: Borrowed strings and bytes.**
Given a packet with a 40-byte `utf8` field and a 16-byte `bytes` field.
When it is unpacked by the core into a row whose string member is a pointer + length view.
Then the view points into the input buffer, its length is 40, and bytes copied by the core are 0. A row with a fixed `char[N]` destination with N < 40 gets `TooMany`.

**AC-9: `f64` needs an 8-byte double.**
Given a build where `sizeof(double) == 4` (avr-gcc, or `-fshort-double` where supported).
When a scheme uses `f64`.
Then compilation fails with a `static_assert` naming `f64`. With `f32` only, the build succeeds.

**AC-10: Session on the board.**
Given a 32-byte seed, a caller random function, and the `pack-session` cross-language vectors.
When the firmware runs `start`, `join`, `pack` and `unpack` on QEMU `mps2-an385`.
Then the padded bytes equal the vectors in every byte; `<sys/random.h>`, `/dev/urandom` and `arc4random` are referenced 0 times in the firmware; a random function that reports failure makes `start` return an error, with 0 bytes padded.

**AC-11: Host programs on the core API.**
Given the host C++ suite (`make test` in `cpp/`), the compile-fail check, and the C++ side of the language-pair e2e, ported to the core API (decision D-2 B).
When they run on the host.
Then failures are 0, every hex vector asserted before the port is still asserted (vectors dropped: 0), AC-10 host throughput (100000 round trips) is ≤ 1 second, the tree has 0 references to the old dynamic walker, and every removed or renamed public symbol of 0.1.x has a row in the README C++ migration list.

**AC-12: Installable from the embedded tools.**
Given the published tag.
When a fresh PlatformIO project (`platform = raspberrypi`, board `pico`), a fresh Arduino-ESP32 sketch and a fresh ESP-IDF project add packbin by its registry name and build the README example.
Then all three builds succeed with 0 local path or git overrides, and the installed version equals the tag.

**AC-13: Every target in CI.**
Given a push to any branch.
When `test.yml` runs.
Then the embedded job builds AC-1 targets, runs AC-2/AC-3/AC-10 on QEMU and AC-4 on the big-endian host, and writes one result row per target to the existing report table; a failing target fails the workflow.

## Out of scope

- 8-bit AVR as a supported target (decision D-3; stretch task only).
- A code generator, compression, a new envelope, or any wire change.
- RTOS integration beyond the caller-supplied random function (no FreeRTOS/Zephyr task or queue code).
- Hardware CI (real boards); QEMU and toolchain builds are the proof.
