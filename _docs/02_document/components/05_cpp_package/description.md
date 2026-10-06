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
- A split flag bit binds to the latest flag byte of its number that is in its own container, was read before it, and is not inside a `when` that ended before it (`find_flag_byte` in `order.hpp`; loop 16, AZ-2135). A bit with no such byte is `SchemeInvalid` naming the bit, or a compile error for a `constexpr` scheme: `u8 k; when(k == 1, flag_byte(0), flag_bit(0, a)); flag_bit(0, b)` is refused at `b`. Unpack saves the flag byte values when a taken `when` starts and restores them when it ends (`unpack_when` in `unpack.cpp`), so a byte read inside a `when` never reaches a bit after it, and sibling `when` branches each read their own byte. The wire bytes of schemes that worked do not change: with an outer `flag_byte(0)` before the `when`, `{k: 0, b: 6}` packs `01 00 01 06` and `{k: 1, a: 5, b: 6}` packs `01 01 01 01 05 06`.
- A `repeat` round, or a round of a container with no bound member (`times`, `list`, `dict`), that reads no bytes ends the container. A repeat would otherwise never reach the end of the packet, and an unbound container would only spin through its count. A bound container stops at its capacity.
- A `boolean`, or an empty group bound to a `bool` or `Opt<bool>` member (`group<&Row::m>(id)`), is a presence bit. It is valid only directly under `flags(...)` or `flag_bit(...)`; anywhere else, including inside a plain `group` under `flags`, the scheme is `SchemeInvalid` (a compile error for a `constexpr` scheme).
- A `group(id)` with no children and no member could never set its bit, so the factory marks it invalid: the scheme is `SchemeInvalid` at that field wherever it stands, including directly in `flags` or as a `flag_bit` (loop 12; a compile error for a `constexpr` scheme).
- A split flag bit inside a `when` that is not taken still has its bit set from the row on pack; unpack tests the `when` first and never reads that field. The shared `bitwhen` vector pins it (loop 12): `{k:0, v:5}` packs `010001` and unpacks with no `v`; `{k:1, v:5}` packs `01010105`.
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
- vcpkg has no upload API. The tag pushes a public git registry. A pull request to the curated microsoft/vcpkg registry is not the publish path. Since loop 16 (AZ-2098) the vcpkg port builds the static library: it vendors `CMakeLists.txt`, `LICENSE`, `include/packbin` and `src` into `ports/packbin`, so an install downloads no tag archive. A consumer uses `find_package(packbin CONFIG REQUIRED)` and `target_link_libraries(app PRIVATE packbin::packbin)`, and the project's `vcpkg-configuration.json` needs this git registry (repository `https://github.com/zxsanny/packbin.git`, reference `vcpkg`) and a baseline for the default registry too. Port versions pushed before AZ-2098 copy the headers and `src` to `share/packbin/src` and build nothing, so they do not link
- The vcpkg port is static only (`vcpkg_check_linkage(ONLY_STATIC_LIBRARY)`); its `packbin-config-version.cmake` uses `SameMinorVersion` while the version is below 1.0 and `SameMajorVersion` from 1.0 (AZ-2232; `PACKBIN_VERSION_RULE` in `cpp/CMakeLists.txt`). Below 1.0 an installed 0.9.0 answers `find_package(packbin 0.9 CONFIG)` and `0.9.0` but not `0.8`, `0.10`, `0.1.0` or `1.0`; a request that names only the major (`find_package(packbin 0 ...)`) finds nothing, and a range that spans minors (`0.9...0.10`) is refused too (checked with CMake 4.1). A request without a version is unchanged. The port also declares `"supports": "linux | osx"` in the staged `vcpkg.json` (`stage_vcpkg_port`): vcpkg refuses any other triplet (`--allow-unsupported` overrides it), because the C++ core is built and tested only with gcc on Linux and clang on macOS, and `os_random` has no Windows branch (read from the code, not run). Port versions 0.1.x have no `supports` line
- The same tag also publishes PlatformIO, ESP-IDF component and Arduino (`arduino` branch and `arduino-<version>` tag) releases of the same sources
- CI builds Cortex-M0+, M3, M4F, s390x (big-endian), ESP32-S3, ESP32-C3 and RP2040 (Pico example); other 32-bit parts are expected to work but are not built in CI
- `f64` needs an 8-byte `double`; otherwise a `static_assert` stops the build
- `invalid_utf8` and `invalid_utf8_dict_key` unpack Ok in C++: strings are borrowed bytes and are not validated. The hostile runner accepts that for those two ids
- The deepest pack or unpack call uses 488 of the 512-byte stack budget. A change that deepens the unpack recursion must free stack first. After loop 16 the Cortex-M4F image of the core plus the 14-field table is 7784 of 8192 bytes of flash (7728 before) and the stack stays at 488 of 512
- A `flags` member and the child of a `flag_bit` stay visible scopes after they end: a flag byte read inside one still binds a bit placed after it, where Rust, TypeScript and Java drop it (AZ-2135 follow-up, open)
- A `flag_bit` used directly as a `flags` member is never present on pack: `flag_byte(0), flags(0, flag_bit(0, p), q)` with `p` and `q` set packs `01 01 02 06`, so the bit of the flag byte is set and `p` is not written (open)

**No round limit** (loop 15, AZ-2220). C#, TypeScript, Java, Rust and Python (since loop 16) refuse a `repeat` or `times` round past a scheme limit; C++ has none and needs none: unpack fills `Array<T, N>` storage the caller owns (`N` is at most 65535, `table.hpp`) and returns `TooMany` for a longer count. The two `limit` cases of `fixtures/hostile/cases.txt` are skipped by `hostile_host_tests.cpp`.

**CMake package and vcpkg port** (loop 16, AZ-2098; `cpp/CMakeLists.txt`, `stage_vcpkg_port` in `.github/workflows/publish-embedded.sh`). The ESP-IDF branch of `cpp/CMakeLists.txt` is unchanged. The host branch builds the static library `packbin` and adds the alias `packbin::packbin`; its include directory has a build interface (`cpp/include`) and an install interface (`include`). Install and export rules run only when packbin is the top-level project (the vcpkg port, or `cmake --install` of `cpp/` itself), so a parent that `add_subdirectory()`s packbin does not install it with its own files: `lib/libpackbin.a`, `include/packbin/*`, and `lib/cmake/packbin/` with `packbin-targets.cmake` (namespace `packbin::`), `packbin-config.cmake` (it includes the targets file) and, when `-DPACKBIN_VERSION=<version>` is set, `packbin-config-version.cmake` (`SameMinorVersion` below 1.0, `SameMajorVersion` from 1.0). The version comes from the release tag, so only the port sets it. `stage_vcpkg_port` (moved to `publish-embedded.sh` by AZ-2096) writes `ports/packbin` with the vendored files, a `vcpkg.json` with `supports` `linux | osx` and the host dependencies `vcpkg-cmake` and `vcpkg-cmake-config`, and a portfile that calls `vcpkg_check_linkage(ONLY_STATIC_LIBRARY)`, `vcpkg_cmake_configure` (with `-DPACKBIN_VERSION=${VERSION}`), `vcpkg_cmake_install`, `vcpkg_cmake_config_fixup`, deletes `debug/include`, and calls `vcpkg_install_copyright`. Re-staging identical sources adds no commit to the registry branch. Checked by hand in a scratch copy: `cmake --install` of `cpp/` gives `libpackbin.a`, the headers and the four CMake files, and a consumer that calls `find_package(packbin CONFIG REQUIRED)` and links `packbin::packbin` prints the golden hex. The vcpkg install itself is checked by `publish-vcpkg.test.sh` (see tests.md); it could not run on the machine this was written on (no vcpkg).

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
