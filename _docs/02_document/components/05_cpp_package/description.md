# C++ package

## 1. High-Level Overview

**Purpose**: Pack and unpack a caller-owned scheme into caller buffers, for host C++ programs and 32-bit microcontrollers.

**Architectural Pattern**: one allocation-free, exception-free core (C++17, no heap, no RTTI, no global state), plus a session the caller holds. The wire bytes are the same as in the other five languages.

**Upstream dependencies**: none inside the repo.

**Downstream consumers**: the caller's C++ program or firmware.

## 2. Internal Interfaces

### Interface: packbin

Public headers are `codec.hpp`, `session.hpp`, `core.hpp`, `fields.hpp`, `fields_grouped.hpp`, `fields_counted.hpp`, `order.hpp`, `table.hpp` and `os_random.hpp`. `packbin.hpp` includes `codec.hpp`, `os_random.hpp` and `session.hpp`. The core sources are `cpp/src/core/*.cpp`; `os_random.cpp` is the only host-only source.

| Method | Input | Output | Async | Error Types |
|--------|-------|--------|-------|-------------|
| `scheme<Row>(type, fields...)` | type number 0..255, field builders by order id (`u8<&Row::m>(0)`, `flags`, `when`, `repeat`, `list`, ...) | a `Scheme` table, built at compile time when `constexpr` | No | `SchemeInvalid` with the field id: a gap, a repeated id, an anchor that is not the next value id, a bad `when` or count reference. A `constexpr` scheme does not compile |
| `validate(scheme)` | scheme | `Result` | No | `SchemeInvalid` |
| `pack(scheme, row, out, cap)` | scheme, struct row, caller buffer | `Result`; on success `offset` is the packet length | No | `BufferFull`, `TooMany`, `BadValue`, `SchemeInvalid` |
| `unpack(scheme, data, len, row)` | scheme, bytes, struct row | `Result` | No | `ShortPacket`, `TrailingBytes`, `TypeMismatch`, `TooMany`, `BadValue`, `SchemeInvalid` |
| `unpack(data, len, on(scheme, row, handler)...)` | bytes, one or more handlers | `Result`; the handler of the matching type number runs only after the whole packet reads | No | as above; two handlers with the same type number are `SchemeInvalid` |

**Input and output types**:

```
Row: a struct the caller owns. Members are bound by pointer to member.
  integers, floats, bool: the plain type, or Opt<T> for a member the packet may leave out
  View: borrowed bytes; on unpack it points into the input buffer
  Text<N>, Blob<N>: fixed storage, N bytes (1..65535)
  Array<T, N>: up to N items for repeat, times, list, dict, bits, packed
  Entry<V, Key>: one dictionary entry; the key is a View or a Text<N>
Result:
  error: Ok, ShortPacket, TrailingBytes, TypeMismatch, BufferFull, TooMany, BadValue, SchemeInvalid
  offset: the byte where the failure was found; on success the bytes written or read
  field: the order id of the failing field, or -1 when no field applies
  needed: the bytes that field required
```

A value longer than its storage is `TooMany`, never cut.

### Interface: PackSession

| Method | Input | Output | Async | Error Types |
|--------|-------|--------|-------|-------------|
| `load` | seed pointer and length | `bool` | No | a length other than 32 returns false |
| `start(nonce, len)` | the caller's nonce | `bool` | No | false when `len` is not 16, no seed is loaded, or the session is already open |
| `start(random, ctx, nonce_out)` | a `RandomFn`; 16 bytes are written to `nonce_out` | `bool` | No | false when `random` fails; nothing opens and `nonce_out` is left as it was |
| `join` | 16-byte nonce and length | `bool` | No | false when `len` is not 16, no seed is loaded, or the session is already open |
| `pack(scheme, row, out, cap)` | scheme, row, caller buffer | `Result`; the packet is padded in place and has the clear length | No | `BadValue` before start or join; on a pack failure the bytes before the offset are zeroed and the send index does not advance |
| `unpack(scheme, data, len, row)`, `unpack(data, len, on(...)...)` | payload (non-const) | `Result` | No | `BadValue` before start or join; the pad is removed in place before the clear unpack runs, and the receive index advances for every payload, whether or not it then reads |

`os_random` is a host `RandomFn`. Firmware passes its own (a hardware RNG).

## 4. Data Access Patterns

No queries and no cache.

**Seed data**: the shared golden hex file.

**Rollback**: a pushed vcpkg port version stays in the git registry. Callers move to a later version. The same holds for the PlatformIO, ESP-IDF and Arduino releases of the same tag.

## 5. Implementation Details

**State Management**: clear pack and unpack are stateless and reentrant; the core keeps no global or static mutable state. Scheme tables are `const` and can live in flash. A session keeps one send counter and one receive counter.

**Unpack rules (loop 10)**:
- Flag bytes are scoped per container. `flag_byte(n)` and `flag_bit(n, field)` pair by the number n (0..7) inside one scope. Each round of a `repeat`, `times`, `list` or `dict` starts with its own cleared flag bytes, and the outer values come back when the container ends.
- A `repeat` round, or a round of a container with no bound member (`times`, `list`, `dict`), that reads no bytes ends the container. A repeat would otherwise never reach the end of the packet, and an unbound container would only spin through its count. A bound container stops at its capacity.
- A `boolean` or an empty `group` is a presence bit. It is valid only directly under `flags(...)` or `flag_bit(...)`; anywhere else, including inside a plain `group` under `flags`, the scheme is `SchemeInvalid` (a compile error for a `constexpr` scheme).
- A `u2` holds at most 64 children. More is `SchemeInvalid`.
- A `flags` byte holds at most 8 children.
- A dictionary entry whose key repeats an earlier key is `BadValue` at the entry's offset.

**Key Dependencies**:

| Library | Version | Purpose |
|---------|---------|---------|
| none | — | numbers are written with shifts on an unsigned value of the field width, so the bytes do not depend on the CPU byte order |

**Error Handling Strategy**:
- Every failure is a `Result` value: error kind, byte offset, field order id and bytes needed. No exception, no text
- On an unpack failure the fields read before the failure keep their values. Optional members the packet leaves out are reset
- On a pack failure nothing is written past the reported offset
- No retry

## 6. Extensions and Helpers

| Helper | Purpose | Used By |
|--------|---------|---------|
| golden fixture | the shared hex | this package and the other five |
| hostile vectors | `fixtures/hostile/cases.txt`: packets and schemes that crafted input can send; the C++ side runs in `cpp/tests/core/hostile_host_tests.cpp` | every package |

## 7. Caveats & Edge Cases

**Known limitations**:
- The first release has no code generator
- vcpkg has no upload API. The tag pushes a public git registry. A pull request to the curated microsoft/vcpkg registry is not the publish path. The vcpkg port installs the headers and copies `cpp/src` to `share/packbin/src`; it builds no library. A host program builds the sources itself, for example with `add_subdirectory(cpp)` and the CMake target `packbin`
- The same tag also publishes PlatformIO, ESP-IDF component and Arduino (`arduino` branch and `arduino-<version>` tag) releases of the same sources
- CI builds Cortex-M0+, M3, M4F, s390x (big-endian), ESP32-S3, ESP32-C3 and RP2040 (Pico example); other 32-bit parts are expected to work but are not built in CI
- `f64` needs an 8-byte `double`; otherwise a `static_assert` stops the build
- `invalid_utf8` and `invalid_utf8_dict_key` unpack Ok in C++: strings are borrowed bytes and are not validated. The hostile runner accepts that for those two ids
- The deepest pack or unpack call uses 488 of the 512-byte stack budget. A change that deepens the unpack recursion must free stack first

**Potential race conditions**:
- None

**Performance bottlenecks**:
- The same AC-10 loop, on one core, in this language

## 8. Dependency Graph

**Must be implemented after**: the golden fixture file

**Can be implemented in parallel with**: the other five language packages

**Blocks**: the first version tag, together with the other five language packages

## 9. Logging Strategy

| Log Level | When | Example |
|-----------|------|---------|
| none | the library returns the error | the caller logs the error kind, offset and field id |

**Log format**: none inside the package

**Log storage**: none
