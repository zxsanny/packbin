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
| `scheme<Row>(type, fields...)` | type number 0..255, field builders by order id (`u8<&Row::m>(0)`, `flags`, `when`, `repeat`, `list`, ...) | a `Scheme` table, built at compile time when `constexpr` | No | `SchemeInvalid` with the field id: a gap, a repeated id, an anchor that is not the next value id, a bad `when` or count reference, an `eq` constant that its integer source cannot hold (loop 19, AZ-2338). A `constexpr` scheme does not compile |
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
- A split flag bit binds to the latest flag byte of its number that is in its own container, was read before it, and is not inside a `when` that ended before it (`find_flag_byte` in `order.hpp`; loop 16, AZ-2135). A bit with no such byte is `SchemeInvalid` naming the bit, or a compile error for a `constexpr` scheme: `u8 k; when(k == 1, flag_byte(0), flag_bit(0, a)); flag_bit(0, b)` is refused at `b`. Unpack saves the flag byte values when a taken `when` starts and restores them when it ends (`unpack_when` in `unpack.cpp`), so a byte read inside a `when` never reaches a bit after it, and sibling `when` branches each read their own byte. Since loop 18 (AZ-2304) a `flags` member and the child of a `flag_bit` are the same kind of scope: `find_flag_byte` is recursive, so a flag byte read inside either is invisible to a later bit outside it (`flag_byte_in_flags_member.cpp` and `flag_byte_in_flag_bit_child.cpp` are compile-fail cases), and `unpack_scoped` in `unpack.cpp` saves and restores the flag byte values around each such scope. A byte inside a `flags` member still serves the bits of its own member, and an outer byte read before binds a later bit. Sibling members of one `flags` are separate scopes (a byte in one member is not seen by a bit in the next), as in TypeScript, Java and (since loop 19, AZ-2333) Rust. The wire bytes of schemes that worked do not change: with an outer `flag_byte(0)` before the `when`, `{k: 0, b: 6}` packs `01 00 01 06` and `{k: 1, a: 5, b: 6}` packs `01 01 01 01 05 06`.
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
- The deepest pack or unpack call uses 448 of the 512-byte stack budget since loop 19 (456 after loop 18, 488 after loop 16). A change that deepens the unpack recursion must free stack first, and any change to `unpack.cpp` or `pack.cpp` needs the arm embedded stage before the commit: `unpack_scoped` (AZ-2304) first raised the stack to 520 of 512 because GCC inlined `unpack_items` into `unpack_one`, and `PACKBIN_NOINLINE` on `unpack_items` (`be73db1`) brought it to 456. After loop 19 the Cortex-M4F image is 8064 of 8192 bytes of flash, a margin of 128 B (7992 after loop 18, 7784 after loop 16, 7728 before); the ESP32-S3 app image is 178 000 B and the ESP32-C3 147 808 B in the loop 18 run
- Sibling members of one `flags` are separate flag-byte scopes here, in TypeScript, in Java and, since loop 19 (AZ-2333), in Rust
- `present()` counts a nested `flags`, a `flag_bit` and a `u2` as a head since loop 18 (AZ-2128): `flag_byte(0), flags(0, flag_bit(0, p), q)` with `p` = 5 and `q` = 6 packs `01 01 03 05 06` (it packed `01 01 02 06` and dropped `p`), and `flags(group(flag_byte(0), flag_bit(0, x)))` with `x` = 5 packs `01 01 01 05` (both packed by a probe in the docs pass; the second is pinned by `flags_when_member_host_tests.cpp` since loop 19, AZ-2340; the first has no test of its own)
- A `when` whose source is an empty group (`group<M>(id)`) is accepted since loop 19 (AZ-2334, see Loop 19 changes), as in Rust. A construction error carries one field id: a bad `when` reports the `when`'s id, not the id of its source (discovery 6, error shape under C15)
- `eq(u8, true)` and `eq(u8, 1.5)` still build: a typed constant is converted to a 64-bit integer before the range check, and refusing them needs an `Eq` overload per type (about the 128 B of flash margin; assessment 19 U7, left as is). A split flag bit that decides a `when` or `times` whose source is written after its flag byte is checked for the first such decider of the bit only, and a `times` whose count is set in the row but behind a clear `when` is not seen (`010003055a00`; the fix costs 56 B of the flash margin, assessment 19 U4, loop 20)

**No round limit** (loop 15, AZ-2220). C#, TypeScript, Java, Rust and Python (since loop 16) refuse a `repeat` or `times` round past a scheme limit; C++ has none and needs none: unpack fills `Array<T, N>` storage the caller owns (`N` is at most 65535, `table.hpp`) and returns `TooMany` for a longer count. Pack needs no cap either: a `times` count above the length of its `Array` (at most 65,535) is a count mismatch, `BadValue`. The two `limit` cases of `fixtures/hostile/cases.txt` are skipped by `hostile_host_tests.cpp`.

**CMake package and vcpkg port** (loop 16, AZ-2098; `cpp/CMakeLists.txt`, `stage_vcpkg_port` in `.github/workflows/publish-embedded.sh`). The ESP-IDF branch of `cpp/CMakeLists.txt` is unchanged. The host branch builds the static library `packbin` and adds the alias `packbin::packbin`; its include directory has a build interface (`cpp/include`) and an install interface (`include`). Install and export rules run only when packbin is the top-level project (the vcpkg port, or `cmake --install` of `cpp/` itself), so a parent that `add_subdirectory()`s packbin does not install it with its own files: `lib/libpackbin.a`, `include/packbin/*`, and `lib/cmake/packbin/` with `packbin-targets.cmake` (namespace `packbin::`), `packbin-config.cmake` (it includes the targets file) and, when `-DPACKBIN_VERSION=<version>` is set, `packbin-config-version.cmake` (`SameMinorVersion` below 1.0, `SameMajorVersion` from 1.0). The version comes from the release tag, so only the port sets it. `stage_vcpkg_port` (moved to `publish-embedded.sh` by AZ-2096) writes `ports/packbin` with the vendored files, a `vcpkg.json` with `supports` `linux | osx` and the host dependencies `vcpkg-cmake` and `vcpkg-cmake-config`, and a portfile that calls `vcpkg_check_linkage(ONLY_STATIC_LIBRARY)`, `vcpkg_cmake_configure` (with `-DPACKBIN_VERSION=${VERSION}`), `vcpkg_cmake_install`, `vcpkg_cmake_config_fixup`, deletes `debug/include`, and calls `vcpkg_install_copyright`. Re-staging identical sources adds no commit to the registry branch. Checked by hand in a scratch copy: `cmake --install` of `cpp/` gives `libpackbin.a`, the headers and the four CMake files, and a consumer that calls `find_package(packbin CONFIG REQUIRED)` and links `packbin::packbin` prints the golden hex. The vcpkg install itself is checked by `publish-vcpkg.test.sh` (see tests.md); it could not run on the machine this was written on (no vcpkg).

**Loop 18 changes** (golden and route bytes are unchanged; unpack of older packets is unchanged):
- A `when`, `times` or `repeat` as a `flags` member, as the child of a `flag_bit`, or in a group under them is written since loop 18 (AZ-2120, AZ-2128; `present()` in `values.cpp`, `item_count` in `pack.cpp`). `present()` counts a `when` (its condition holds and a child is present), a `times` (its count is above 0 or its `Array` holds rounds, so a count of 0 with rounds is refused and not dropped) and a `repeat` (its `Array` count is not 0), and a nested `flags`, `flag_bit` and `u2` head, so a group, `when` body or flag bit whose only values sit there now sets its bit. A bound `times` or `repeat` with zero rounds under `flags` leaves its bit clear (it set it). The pinned shape `u8 mode; flags(when(eq(0, 1), u8 speed), u16 heading)` with `mode` = 1, `speed` = 7 and `heading` = 90 packs `01 01 03 07 5a 00` (it packed `01 01 02 5a 00`). Reference bytes: `_docs/03_implementation/flags_member_reference_cases_loop18.md`; tests `flags_when_member_host_tests.cpp`, `flags_times_repeat_member_host_tests.cpp` and `member_cases.hpp` (host only).
- A `times` whose count is 0 while its `Array` is not empty is `BadValue` on pack, in and out of `flags` (`item_count`: the `Array` count must equal the `times` count; a count above 0 was already checked). Silently skipped before.
- Construction: a `when` that names a float, utf8, bytes, sized, bits or packed field, `eq` of a bool against anything but `true` (`eq(0, false)` is a compile error, `compile-fail/when_eq_bool_false.cpp`; a run-time `eq(0, 0)` on a bool gives `SchemeInvalid` naming the `when`), and a count that names a bool or another non-integer field are refused (AZ-2126; `source_kinds_host_tests.cpp`; a bool count built before).
- Flag byte scope: see Unpack rules (AZ-2304).
- The hostile `pack` stage runs here (`hostile_pack_cases.hpp`): all five `pack` cases except `pack_out_of_range_integer`, which a typed row cannot express (it binds `std::uint8_t`). Loop 19 added seven `pack` cases and one `construct` case; see Loop 19 changes.

**Loop 19 changes** (golden and route bytes are unchanged; unpack of older packets is unchanged; the arm embedded stage passes at 448 of 512 B of stack and 8064 of 8192 B of flash):
- Split bit with a dropped body (AZ-2331; `mark_late` in `order.hpp`, `Field::late` in `table.hpp`, `pack_flag_byte` in `pack.cpp`, `times_present` in `values.cpp`). `Field::late` is a new byte in the padding of `Field` (`sizeof(Field)` is unchanged on 32-bit ARM, x86-32, x64 and AArch64; on AVR, AZ-2068, each entry would grow by 1 B). At resolve, `mark_late` sets it on a flag bit when a `when` or `times` that the bit decides (itself or inside groups) has a source that sits after the flag byte and before the flag bit entry (`t[i].ref > t[bit].ref && t[i].ref < bit`; a source inside the bit's own body is read where the body is read, review C1) and stores the distance to the first such decider (255 at most, else the scheme is invalid). `pack_flag_byte` refuses with `BadValue` naming that member when the decider is present in the row although the byte leaves the bit clear, before it writes the byte. A false condition stays silent. `times_present` also counts rounds whose count is not in the row, so pack refuses them (`times_with_a_skipped_count` now expects a refusal), in the combined `flags` form too. Not covered: the first decider only (review C2), a count set in the row but behind a clear `when`. Tests: `split_form_loud_host_tests.cpp`, `late_source_host_tests.cpp` (the C1 and distance 255/256 cases); hostile handlers for `pack_split_*`.
- Empty group as a `when` source (AZ-2334; `find_ref` in `order.hpp`, `read_int` in `values.cpp`). `find_ref` returns an empty group (`Kind::Group`, span 1, with a member) when no other field of the scope has the same id (an empty group takes the id of the field after it, so a field with that id wins, review C8); `read_int` reads its `bool` as 1 or 0. `eq(id, true)` matches an on group; a `when` that names an empty group with another value, or a presence source with anything but `true`, is `SchemeInvalid`. Tests: `source_kinds_host_tests.cpp` (three).
- Count 0 (AZ-2335). A `times` whose count is 0 and whose `Array` holds items is `BadValue` (unchanged since loop 18); a lone scalar with count 0 packs `0100`, as in the other five packages. Tests: `times_count_zero_host_tests.cpp`; the hostile handler `pack_times_zero_with_values`.
- `eq` range (AZ-2338; `eq_fits` in `order.hpp`, called from `resolve`). A `when` whose `eq` constant its integer source cannot hold (`u8` 0..255, `i8` -128..127, a `u2` slot 0..3, and so on) is `SchemeInvalid` naming the `when`; a `constexpr` scheme does not compile (`compile-fail/when_eq_out_of_range.cpp`, 15 of 15 compile-fail cases rejected). The bool and presence rule (`true` only) is unchanged. Floats and bools: see Known limitations. Tests: `eq_value_checked_host_tests.cpp`; the hostile `construct` case `eq_out_of_range` builds the scheme with the constant 300 at run time.
- Hostile runner: nine of the twelve `pack` cases run here; `pack_times_count_over_limit` (no round limit on pack, see No round limit) and `pack_lone_bytes_in_round` (a typed row holds an `Array` of `Array`) are skipped with the reasons in `hostile_host_tests.cpp`, and `pack_out_of_range_integer` as before.
- Test `flags_when_member_host_tests.cpp` pins `flags(group(flag_byte(0), flag_bit(0, x)))` with only `x` set: `01 01 01 05` (AZ-2340).


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
