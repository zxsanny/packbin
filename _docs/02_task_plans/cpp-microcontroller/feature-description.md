# Feature description — C++ on microcontrollers

Make `packbin` C++ build and run on 32-bit microcontrollers with no exceptions, no RTTI and no heap, with the same golden bytes as the other five languages proven on the target CPU, and installable from PlatformIO, Arduino and ESP-IDF. Source of truth: `problem.md` (assessment and blockers), `restrictions.md`, `acceptance_criteria.md` (AC-1…AC-13), `input_data/expected_results/results_report.md`.

Complexity: about 29 points in total, so it goes through `/decompose --feature` (new-task Step 2b). Decisions taken 2026-10-04: **D-1 A, D-2 B, D-3 A**.

## Decisions to take first

### D-1: One walker or two

- **A — One core, desktop layered on it (recommended).** Write an allocation-free, exception-free core (buffer in, buffer out, static field tables, error enum). Re-base today's `BinaryPacker` / `Scheme<T>` / `Values` API on that core, so there is one walker and one implementation of every field rule. Trade-off: the desktop layer is reworked in this feature (task T5), so the change touches the existing tests.
- **B — Separate embedded header next to today's walker.** Add `packbin/embedded.hpp` with its own walker and leave the dynamic walker as it is. Trade-off: two C++ implementations of every field kind, flags rule and field-order check that must be kept in step forever. This is the parallel-implementation pattern the project avoids.

Recommendation: **A**. **Chosen: A.**

### D-2: Desktop API compatibility

- **A — Keep today's public desktop API and behaviour (recommended).** It becomes a thin layer; exceptions stay available in the desktop layer for host users who want them, and the error enum is also exposed. Changed signatures: target 0, listed in the changelog otherwise.
- **B — Move everyone to the core API.** Smaller code, but a breaking release for host users.

Recommendation: **A**. **Chosen: B** — host programs move to the core API; the dynamic `Values` API is removed. Breaking C++ release; README carries the migration list.

### D-3: AVR (8-bit)

- **A — Stretch task, not in the release criteria (recommended).** The core avoids the standard library where it can; `f64` is refused at compile time where `double` is 4 bytes (AC-9). A follow-up task removes the remaining `<type_traits>`/`<array>` use and adds an avr-gcc build.
- **B — Supported target now.** No standard library at all on avr-gcc 7.3, 2 KB SRAM on the Uno: forces hand-rolled traits and a smaller scheme table format, roughly +5 points.

Recommendation: **A**. **Chosen: A.**

## Core shape (non-binding, for sizing)

- A scheme is a `constexpr` table of field descriptors (kind, id, width, endianness, child range, count id, anchor) in flash; a row is bound by member pointers (no `std::function`).
- `Writer { uint8_t* data; size_t cap; size_t len; }` and `Reader { const uint8_t* data; size_t len; size_t pos; }`; every put/get returns the error enum.
- Strings and byte blocks: `View { const uint8_t* data; uint16_t len; }` borrowed from the input, or a fixed `char[N]` / `uint8_t[N]` destination with `TooMany` past N.
- Counted kinds (`repeat`, `times`, `list`, `dict`, `bits`, `packed`) unpack into caller arrays with a max count.
- Field-order and anchor checks run in a `constexpr` validator (compile error) and in `validate()` for runtime-built tables (error result).
- Numbers go through shifts on the unsigned type of the same width; floats via a `memcpy` to that unsigned type first.

## Proposed task boundaries (in order)

| # | Task | Points | Depends on | Delivers | ACs |
|---|------|--------|------------|----------|-----|
| T1 | Core writer/reader, scalar kinds, portable byte order, error enum | 3 | — | Buffer `Writer`/`Reader`; u8…u64, i8…i64, f32, f64 (with the 8-byte `static_assert`), bool, bytes(n), `be()`; shift-based numbers; error enum with offset and field id | AC-4 (scalars), AC-6 (short/trailing/full), AC-9 |
| T2 | Static scheme tables, type number, field order at compile time | 5 | T1 | `constexpr` field table and member-pointer binding; type-number dispatch over several schemes without `std::function`; `constexpr` and runtime `validate()` for the field-order and anchor rules | AC-6 (type mismatch), AC-7 |
| T3 | Grouped and conditional kinds | 3 | T2 | `flags`, `flag_byte` + bits, `when(eq(...))`, `group` (nested and continuing) | AC-3 for those vectors |
| T4 | Counted and variable kinds with caller storage | 5 | T2 | `utf8` and `bytes` as borrowed views or fixed destinations, `sized`, `repeat`, `times`, `u2`, `bits`, `packed`, `list`, `dict` with max counts and `TooMany` | AC-3 for those vectors, AC-6 (`TooMany`), AC-8 |
| T5 | Host programs on the core; dynamic walker removed (D-1 A, D-2 B) | 5 | T3, T4 | Host suite, compile-fail check, language-pair e2e runner and benchmark ported to the core API with every vector kept; `BinaryPacker`, `Scheme<T>` `std::function` binding, `Value`/`Values` and their walker deleted; README migration list | AC-11 |
| T6 | Session on the core | 2 | T1 | Buffer-based `PackSession` with a caller random function; host build keeps the OS random source behind one adapter; no POSIX include in the core | AC-10 |
| T7 | Target CI: toolchains, QEMU, big-endian, link guards, size report | 3 | T3, T4, T6 | CI container with arm-none-eabi GCC 13, ESP-IDF 5.x, QEMU system (`mps2-an385`) and user (`s390x`); vector runner firmware; `--wrap` malloc/new guards and `__cxa_*` map check; size and stack report rows | AC-1, AC-2, AC-3, AC-4, AC-5, AC-13 |
| T8 | Embedded packaging and README | 3 | T7 | `library.json`, `library.properties` + Arduino `src/` layout, `idf_component.yml` + component `CMakeLists.txt`, examples for Pico, ESP32 (Arduino) and ESP-IDF; publish steps in `publish-registries.sh` behind the existing gate; README C++ embedded section; `languages.md` row | AC-12 |
| T9 | (stretch, D-3 A) AVR build | 3 | T7 | avr-gcc build of the core without `<type_traits>`/`<array>`, `f64` refused, Uno example | — |

Totals: T1–T8 = 29 points; T9 = 3 (not in the release criteria).

## Scenarios

| id | scenario | behaviour (proposed) | AC |
|----|----------|----------------------|----|
| S1 | Firmware packs a row into a buffer exactly the packet size | Ok, `len == size` | AC-3 |
| S2 | Buffer one byte short | `BufferFull`, nothing written past the offset | AC-6 |
| S3 | Received packet truncated by the radio | `ShortPacket` with field id | AC-6 |
| S4 | Packet with a type number this firmware does not know | `TypeMismatch`; no handler runs | AC-6 |
| S5 | Server sends more `repeat` groups than the firmware's array | `TooMany`; already-read fields stay as read | AC-6 |
| S6 | Long string into a fixed `char[16]` | `TooMany`; borrowed view has no limit | AC-8 |
| S7 | Big-endian CPU | Same bytes as little-endian | AC-4 |
| S8 | Board without a working RNG | `start` returns an error, no padding | AC-10 |
| S9 | Scheme typo (gap in field ids) in firmware source | Compile error naming the id | AC-7 |
| S10 | Host user upgrades from 0.1.x | Old API is gone; README migration list maps each old symbol to its core replacement; same bytes, same speed | AC-11 |

## Fit decisions

| card | collision | chosen option | constraint |
|------|-----------|---------------|------------|
| 1 | Project restriction "runs on the operating system that hosts the language runtime" | amended for C++ (2026-10-04) | `restrictions.md` |
| 2 | Project out-of-scope "allocation budgets … zero-copy API" | C++-only allocation and size budget (amended 2026-10-04) | AC-2, AC-5 |
| 3 | One walker or two | D-1 A, D-2 B (decided 2026-10-04) | `restrictions.md` § Desktop profile |
