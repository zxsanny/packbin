# Restrictions — C++ on microcontrollers

## Wire

- Bytes on the wire do not change. Every hex vector already asserted in `cpp/tests/*.cpp` and `fixtures/golden.hex` must come out byte-identical from the microcontroller build.
- Little-endian stays the default and `be()` stays big-endian, independent of the CPU's byte order.

## Embedded profile (the "core")

- Builds with `-std=c++17 -fno-exceptions -fno-rtti -Os -Wall -Wextra -Werror` on arm-none-eabi GCC ≥ 12 (newlib-nano), ESP-IDF ≥ 5.1 (xtensa and RISC-V), and the Arduino-Pico / Arduino-ESP32 cores.
- No `throw`, no `try`, no `std::function`, no `std::shared_ptr`, no `std::string`, no `std::vector`, no `std::map`, no `std::variant` in the core. Allowed headers: `<cstdint>`, `<cstddef>`, `<cstring>`, `<type_traits>`, `<limits>`, `<array>`, `<utility>`.
- No heap: `malloc`, `operator new` and `__cxa_allocate_exception` are not referenced by a firmware that packs and unpacks every field kind (checked at link time, see AC-2).
- Output goes into a caller buffer (`uint8_t* data, size_t capacity`); input is read from a caller buffer. Strings and byte blocks unpack as a pointer + length into the input buffer (borrowed) or into a caller-sized destination; the core never allocates to hold them.
- Variable-size kinds (`repeat`, `times`, `list`, `dict`, `bits`, `packed`) unpack into caller storage with a compile-time or caller-given maximum count; exceeding it is an error result, never truncation.
- Errors are a small enum (`Ok`, `ShortPacket`, `TrailingBytes`, `TypeMismatch`, `BufferFull`, `TooMany`, `BadValue`, `SchemeInvalid`) plus the byte offset and field id. No text on the core path.
- Scheme field order and anchors (the `scheme-field-order` rules) are checked at compile time where the scheme is `constexpr`, else once by a `validate()` call that returns `SchemeInvalid`; never by throwing.
- Integers and floats are read and written with shifts on an unsigned value of the same width, not by copying the native object.
- `f64` requires `sizeof(double) == 8`; otherwise a `static_assert` names the field kind.
- Scheme tables are `const` (flash). The core keeps no global or static mutable state and is reentrant.
- `PackSession` on the core: caller-supplied random function (`bool(*)(uint8_t* out, size_t n, void* ctx)`), in-place XOR on the caller buffer, no `std::vector`, no `<sys/random.h>` include outside the host build.

## Desktop profile

- Host programs use the core API too (decision D-2 B). Today's dynamic API (`BinaryPacker`, `Scheme<T>` with `std::function` bindings, `Value`/`Values`, exception errors) is removed. One walker, one set of field rules (decision D-1 A).
- The only host-only code is an OS random source for `PackSession` (one adapter file, not compiled into firmware).
- The README C++ section lists every removed or renamed public symbol with its replacement. The release is a breaking C++ release.
- AC-10 throughput (100000 round trips ≤ 1 s on one core) still holds on the host.

## Packaging

- C++ stays published through vcpkg. Embedded installs add a PlatformIO library (`library.json`), an Arduino library (`library.properties`, `src/` layout) and an ESP-IDF component (`idf_component.yml` + `CMakeLists.txt`), all from the same tag and the existing `publish.yml` gate. Registry tokens are secrets in the publish job, never in the tree.
- License stays MIT.
