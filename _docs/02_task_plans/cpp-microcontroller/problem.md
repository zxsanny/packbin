---
loop: 10
branch: loop/10-cpp-microcontroller
---

# C++ on microcontrollers

**Date:** 2026-10-04  
**Mode:** feature-loop  
**Slug:** cpp-microcontroller  
**Requested by:** user, 2026-10-04 — "check how packbin is compatible in C++ with microcontrollers, and if it is not, write a detailed task to make it compatible".

## What

Make the C++ package usable on 32-bit microcontrollers (Cortex-M0+/M3/M4/M33, ESP32 family, RP2040, nRF52, STM32) built the usual embedded way: no exceptions, no RTTI, no heap after start-up, a small flash and stack budget, and the toolchains those boards ship (arm-none-eabi GCC, ESP-IDF, Arduino cores, PlatformIO). The same golden bytes as the other five languages, checked on the target CPU.

## Today: not compatible (assessment, 2026-10-04, tag v0.1.13, commit 1a15ce3)

Evidence from the `cpp/` tree (2209 lines of `src` + `include`) and from compiling it:

| # | Blocker | Evidence | Effect on a microcontroller build |
|---|---------|----------|-----------------------------------|
| 1 | Exceptions are the error path | 33 `throw std::runtime_error(...)` in `src/field.cpp`, `src/counted.cpp`, `src/walk.cpp`, `src/walk_common.cpp`, `include/packbin/scheme.hpp` (scheme order, flags overflow, lengths, missing field, duplicate type number). `std::get` on `Value` throws `bad_variant_access`. | `clang++ -std=c++17 -fno-exceptions -fno-rtti` on `src/*.cpp`: **33 errors** "cannot use 'throw' with exceptions disabled". Arduino, ESP-IDF (default), Zephyr and most bare-metal builds use `-fno-exceptions`. |
| 2 | Heap on every pack and unpack | Values travel through `Values = std::map<std::string, Value>`; `Value` is a `std::variant` of 14 types including `std::string`, `std::vector<uint8_t>` and `std::shared_ptr` lists/maps; output is `std::vector<uint8_t>`; bindings are `std::function`; `Field` holds `std::string`, `std::vector<Field>` and two `std::shared_ptr`. | One map node (~56 B on a 64-bit host, ~28–32 B on 32-bit) plus a key string per field per call; schema objects ~208 B per field (64-bit host). Fragmentation and unbounded RAM on devices with 64–520 KB SRAM; banned outright by many firmware rules (MISRA, no-heap-after-init). |
| 3 | Error results carry strings | `ShortPacket::field` is `std::string`; error messages are built with `std::to_string` + concatenation. | Heap on the error path; text that firmware cannot use. |
| 4 | C++17 library features required | `std::optional` (41 uses), `std::variant`, `std::map`, `<functional>`, `<memory>`, `<stdexcept>`. | C++14 build: **70+ errors** (`no template named 'optional'`, `'variant'`). AVR (Arduino Uno/Mega, avr-gcc 7.3) has no C++ standard library at all. |
| 5 | Byte order assumes a little-endian host | `write_num` / `read_num` (`src/walk.hpp:26-44`) `memcpy` the native object; only the `be` flag reverses. | Wrong bytes on a big-endian CPU (some PowerPC/ColdFire parts, big-endian ARM configurations). Alignment is safe (all `memcpy`). |
| 6 | `f64` assumes an 8-byte `double` | `read_num<double>` / `write_num(double)` | avr-gcc and some `-fshort-double` builds have a 4-byte `double`: `f64` silently writes 4 bytes. |
| 7 | `PackSession` needs an operating system | `src/session.cpp` includes `<sys/random.h>`, uses `arc4random_buf` or reads `/dev/urandom` through `std::ifstream`; buffers are `std::vector`. | Does not build without POSIX headers; no way to plug the board's hardware RNG (ESP32 `esp_fill_random`, STM32 RNG, nRF `NRF_RNG`, RP2040 ROSC). HKDF/SHA-256 itself is in-house and portable. |
| 8 | Code size | Host arm64 `-Os` objects: about 63 KB `__TEXT` for the seven sources, before `std::map`/`std::string`/`std::variant` instantiations from the caller. | Too large for 32–128 KB flash parts; acceptable on ESP32 but wasteful. |
| 9 | Build and packaging are host-only | `cpp/Makefile` (`g++`, `-std=c++17 -O2`), vcpkg port. No `library.json` (PlatformIO), `library.properties` (Arduino), `idf_component.yml` (ESP-IDF), Zephyr module, or CMake target with an embedded profile. | Not installable with the tools embedded developers use. |
| 10 | No proof on target | CI runs the C++ suite on the Ubuntu host only (`.github/workflows/test.yml`, `run-suite.sh`). | Nothing shows the golden bytes on a Cortex-M or ESP32 CPU. |

What is already fine: no RTTI use (`dynamic_cast` 0, `typeid` 0), no threads, no iostream on the pack path, `memcpy` instead of unaligned casts, HKDF/SHA-256 without OpenSSL.

## Who

Firmware developers who exchange packbin packets with the C#, TypeScript, Rust, Python and Java services: radios (Meshtastic-class links), field sensors and vehicle trackers that must speak the same bytes as the server.

## Why

The wire format is small and fixed-width-friendly, which is what constrained links want, but the C++ package cannot be built where those links end. Today a firmware team would hand-write the bytes, which is exactly the drift packbin exists to stop.

## Change location

The `cpp/` package (headers, sources, tests, build files), its CI job and publish step, the README C++ section, and `_docs/01_solution/languages.md`. Other languages do not change. Wire bytes do not change.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Project restriction "It runs on the operating system that hosts the language runtime" (`_docs/00_problem/restrictions.md`) excludes bare metal | User decision: amend the restriction for C++ | resolved 2026-10-04: amended in `_docs/00_problem/restrictions.md` | High |
| Project out-of-scope line "Any speed target other than AC-10, including allocation budgets … and a zero-copy API" (`_docs/00_problem/acceptance_criteria.md`) | This feature introduces a C++-only allocation and size budget; amend for C++ | resolved 2026-10-04: amended in `_docs/00_problem/acceptance_criteria.md` | High |
| One walker or two: an allocation-free core next to today's dynamic walker is a parallel implementation | Decision D-1 in `feature-description.md` | resolved 2026-10-04: A, one core | High |
| Public C++ API compatibility for existing desktop users | Decision D-2 | resolved 2026-10-04: B, host users move to the core API (breaking release, migration list in the README) | Medium |
| AVR (8-bit, no standard library, 4-byte `double`) | Decision D-3 | resolved 2026-10-04: A, stretch task T9; `f64` refused at compile time | Medium |
| Publishing to PlatformIO / Arduino / ESP-IDF registries needs accounts and tokens | Maintainer | open | Medium |
| No embedded toolchain on the maintainer laptop today | CI installs arm-none-eabi GCC and QEMU; local runs use the same container | open | Low |
