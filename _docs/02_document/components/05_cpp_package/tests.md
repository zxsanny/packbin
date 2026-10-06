# Test Specification — C++ package

## Acceptance Criteria Traceability

| AC ID | Acceptance Criterion | Test IDs | Coverage |
|-------|---------------------|----------|----------|
| AC-1 | Position pack is the 13-byte hex | IT-01, AT-01 | Covered |
| AC-2 | Unpack returns those fields and 0 motion fields | IT-02, AT-01 | Covered |
| AC-3 | This package's bytes match the shared golden hex | IT-03 | Covered |
| AC-4 | Clear bit adds 0 bytes; flags 0x20 adds 2 | IT-04 | Covered |
| AC-5 | A stored 0 is written | IT-05 | Covered |
| AC-6 | Conditional group adds 0 bytes or its width | IT-06 | Covered |
| AC-7 | Repeat yields one value per group; 1 leftover byte is an error | IT-07 | Covered |
| AC-8 | A short field returns `ShortPacket` with the order id, the byte offset and the bytes needed; the fields read before it keep their values. The project wording ("names the field", "bytes remaining", "0 values") is open for C++: see the note under the traceability table | IT-08, ST-01 | Covered for the C++ result |
| AC-9 | Trailing bytes are an error and 0 values | IT-09 | Covered |
| AC-10 | 100000 round trips ≤ 1 second on one core | PT-01 | Covered |
| AC-11 | This package's tests run on every push and pull request | AT-02 | Covered |
| AC-12 | A matching tag publishes this package, with 0 manual uploads | AT-03, ST-02 | Covered |
| AC-13 | The first tag includes this package with the other five | AT-03 | Covered |
| AC-14 | A golden mismatch publishes 0 packages, including this one | AT-04 | Covered |
| AC-15 | This package absent from the tagged tree publishes 0 packages | AT-05 | Covered |
| AC-16 | This published package declares MIT | AT-06 | Covered |

C++ differs from the other five languages on AC-8. `Result` carries `error`, `offset` (the byte where the failure was found), `field` (the order id, not a name) and `needed`. `unpack(scheme, data, len, row)` does not clear the row on failure. The feature restriction (`_docs/02_task_plans/cpp-microcontroller/restrictions.md`) approves the id and the offset. The project-level AC-8 text has no C++ exception yet.

Loop 10 adds the tests below, which are not part of the project AC table above: the feature criteria AC-1 to AC-13 of `_docs/02_task_plans/cpp-microcontroller/`.

## Blackbox Tests

### IT-01: Position pack

**Summary**: `pack` of the position fixture yields the 13-byte golden hex.

**Traces to**: AC-1

**Description**: Call `pack` with type 64, sid 1, latitude 500000000, longitude 300000000, profile 1, and motion flags clear.

**Input data**:
```
type 64, sid 1, latitude 500000000, longitude 300000000, profile 1, motion flags clear
```

**Expected result**:
```
4001000065cd1d00a3e1110100
mismatched bytes: 0
length: 13
```

**Max execution time**: 1s

**Dependencies**: the shared golden fixture file

### IT-02: Position unpack

**Summary**: `unpack` of that hex returns the five fields and 0 motion fields.

**Traces to**: AC-2

**Description**: Call `unpack` on `4001000065cd1d00a3e1110100`.

**Input data**:
```
4001000065cd1d00a3e1110100
```

**Expected result**:
```
type 64, sid 1, latitude 500000000, longitude 300000000, profile 1
motion field count: 0
field mismatches: 0
```

**Max execution time**: 1s

**Dependencies**: none

### IT-03: Bytes match the golden hex

**Summary**: This package's position bytes equal the shared fixture. A mismatch fails the seam with the other five languages.

**Traces to**: AC-3

**Description**: Pack the position list and compare to the fixture file. This is the package side of the six-language seam.

**Input data**:
```
the position row in the golden fixture
```

**Expected result**:
```
mismatched bytes: 0
```

**Max execution time**: 1s

**Dependencies**: the shared golden fixture file

### IT-04: Flags width

**Summary**: A clear flags bit adds 0 bytes. Flags 0x20 on a uint16 at bit 5 adds 2 bytes.

**Traces to**: AC-4

**Description**: Pack the same list twice, once with flags 0x00 and once with flags 0x20.

**Input data**:
```
flags 0x00
flags 0x20, bit 5 is uint16
```

**Expected result**:
```
flags 0x00 adds 0 bytes
flags 0x20 adds 2 bytes
```

**Max execution time**: 1s

**Dependencies**: none

### IT-05: A stored zero is written

**Summary**: A present 0 sets the field bit. Absence omits the field and does not substitute 0.

**Traces to**: AC-5

**Description**: Pack a value that includes 0, then pack a value that omits that field.

**Input data**:
```
field present, value 0
field absent
```

**Expected result**:
```
present 0 is written and the bit is set
absence adds 0 bytes and the result does not contain 0
```

**Max execution time**: 1s

**Dependencies**: none

### IT-06: Conditional group

**Summary**: A `when` group whose tested field does not match adds 0 bytes. A match adds that group's width.

**Traces to**: AC-6

**Description**: Pack one value that fails the condition and one that matches it.

**Input data**:
```
tested field not equal to the when value
tested field equal to the when value
```

**Expected result**:
```
mismatch adds 0 bytes
match adds exactly the group width
```

**Max execution time**: 1s

**Dependencies**: none

### IT-07: Repeat on a group boundary

**Summary**: A buffer of whole groups unpacks one value per group. One leftover byte is an error and 0 values.

**Traces to**: AC-7

**Description**: Unpack a complete repeated group, then a buffer that ends one byte into the next group.

**Input data**:
```
one complete group
one complete group plus 1 leftover byte
```

**Expected result**:
```
complete group: value count 1
leftover byte: error, value count 0
```

**Max execution time**: 1s

**Dependencies**: none

### IT-08: Short field

**Summary**: A buffer that ends inside a field returns `ShortPacket`.

**Traces to**: AC-8

**Description**: Unpack a buffer that ends inside a named field.

**Input data**:
```
a buffer shorter than the field width
```

**Expected result**:
```
error: ShortPacket
offset: the byte where the field starts
field: the order id of that field
needed: the width of that field in bytes
```

**Max execution time**: 1s

**Dependencies**: none

### IT-09: Trailing bytes

**Summary**: Bytes left after the field list are an error and 0 values.

**Traces to**: AC-9

**Description**: Unpack a buffer that completes the list and then has 1 extra byte.

**Input data**:
```
a complete field list plus 1 trailing byte
```

**Expected result**:
```
error
value count: 0
```

**Max execution time**: 1s

**Dependencies**: none

## Performance Tests

### PT-01: Position round trips on one core

**Summary**: 100000 pack-then-unpack round trips of the AC-1 fixture finish in ≤ 1 second on one core.

**Traces to**: AC-10

**Load scenario**:
- Concurrent users: 1
- Request rate: 100000 sequential round trips, then stop
- Duration: the loop itself
- Ramp-up: none

**Expected results**:

| Metric | Target | Failure Threshold |
|--------|--------|-------------------|
| Elapsed time of 100000 round trips | ≤ 1 second | > 1 second |
| Error count | 0 | > 0 |
| Throughput | the same loop on one core | a second core is required to meet the bound |
| Latency (p50, p95, p99) | not the bound | this NFR is elapsed time, not a percentile |

**Resource limits**:
- CPU: one core
- Memory: the test process
- Database connections: 0

## Security Tests

### ST-01: A short buffer returns no value

**Summary**: Unpack of a short field returns an error value and no handler runs.

**Traces to**: AC-8

**Attack vector**: a truncated packet presented as a complete value

**Test procedure**:
1. Unpack a buffer that ends inside a field
2. Read the returned value

**Expected behavior**: the call returns `ShortPacket`. With `unpack(data, len, on(...))` the handler does not run

**Pass criteria**: handler calls are 0, and the result carries the order id, the offset and the bytes needed

**Fail criteria**: a handler runs, or the call does not return

### ST-02: The published archive has no registry token

**Summary**: The files published for this package contain 0 registry tokens.

**Traces to**: AC-12

**Attack vector**: a CI secret copied into the archive

**Test procedure**:
1. Build the archive the tag job would upload to vcpkg `packbin`
2. Search the archive for a registry token

**Expected behavior**: the archive is the library only

**Pass criteria**: token count is 0

**Fail criteria**: token count is greater than 0

## Acceptance Tests

### AT-01: Caller pack and unpack

**Summary**: A caller packs the position fixture and unpacks it back.

**Traces to**: AC-1, AC-2

**Preconditions**:
- This package is built
- The golden fixture is on disk

**Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | `pack` the position value | `4001000065cd1d00a3e1110100`, mismatched bytes 0 |
| 2 | `unpack` that hex | the five fields, motion field count 0 |

### AT-02: Tests run on push and pull request

**Summary**: CI runs this package's tests on every push and pull request.

**Traces to**: AC-11

**Preconditions**:
- The repository is https://github.com/zxsanny/packbin

**Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | push a commit that fails one test in this package | the check fails |
| 2 | push a commit whose tests pass | the check passes |

### AT-03: A matching tag publishes this package

**Summary**: A version tag whose golden mismatch count is 0 publishes this package with the other five, and the upload is not manual. The same tag also publishes the PlatformIO, ESP-IDF and Arduino releases of the C++ sources.

**Traces to**: AC-12, AC-13

**Preconditions**:
- All six languages are in the tagged tree
- Golden mismatch count is 0

**Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | push a version tag | this package is on vcpkg `packbin` |
| 2 | install with `vcpkg install packbin` from this git registry and link `packbin::packbin` (`find_package(packbin CONFIG REQUIRED)`) | the headers are in `include/packbin`, `lib/libpackbin.a` and `lib/cmake/packbin` are installed, the consumer builds and prints the golden hex, and `share/packbin/copyright` is the repository `LICENSE` |
| 3 | count manual uploads | 0 |

### AT-04: A golden mismatch publishes nothing

**Summary**: If this package's bytes disagree with the fixture, the tag publishes 0 packages.

**Traces to**: AC-14

**Preconditions**:
- This package's position bytes differ from the fixture

**Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | push a version tag | packages published: 0 |

### AT-05: Absent from the tree publishes nothing

**Summary**: A tag whose tree lacks this package publishes 0 packages to its registry.

**Traces to**: AC-15

**Preconditions**:
- This package's project is not in the tagged tree

**Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | push a version tag | this registry receives 0 packages |

### AT-06: The published package declares MIT

**Summary**: The archive on vcpkg `packbin` declares the MIT license.

**Traces to**: AC-16

**Preconditions**:
- AT-03 has published this package

**Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | read the license identifier | MIT |
| 2 | count identifiers other than MIT | 0 |

Rollback if this version must not be used: publish a later vcpkg port version. A pushed port version stays.

## Embedded and Compile-Time Tests (loop 10)

Run by `make test` in `cpp/` and by `cpp/embedded/run.sh` (the `cpp-embedded` and `cpp-embedded-esp` services of `docker-compose.test.yml`; the `embedded` job of `test.yml`). One result row per target goes to `test-results/report.csv`.

| Test | What it proves | Where |
|------|----------------|-------|
| Core suites | scalars, schemes, grouped kinds, counted kinds, containers and the session, built with `-fno-exceptions -fno-rtti`. Since loop 16 (AZ-2135) `grouped_tests.cpp` also pins the split-bit rules: a flag byte read inside a `when` is not seen by a bit after it (`01 00 01 06` for `{k: 0, b: 6}`, `01 01 01 01 05 06` for `{k: 1, a: 5, b: 6}`), a scheme whose only flag byte for a bit sits inside a `when` is `SchemeInvalid` naming the bit, sibling `when` branches keep their own bytes, and a `when` inside a round gives the round's byte back when it ends | `cpp/tests/core/*_tests.cpp`, `make test` |
| Compile-fail cases | ten cases that must not compile and must print the expected text (`pack_without_scheme`, `f64_needs_8_byte_double`, `scheme_gap`, `scheme_repeated_id`, `scheme_wrong_anchor`, `scheme_when_ahead`, `flags_overflow`, `bool_outside_flags`, `empty_group_outside_flags`, `u2_too_wide`) | `cpp/tests/compile-fail/`, `make compile-fail` |
| Hostile vectors | every `unpack` and `construct` case of `fixtures/hostile/cases.txt` (17 of the 19) returns an error value or refuses the scheme, and returns within the time guard; the two `limit` cases are skipped, because C++ unpacks into caller-owned fixed arrays and has no round limit (AZ-2220) | `cpp/tests/core/hostile_host_tests.cpp` |
| Cortex-M0+ build | 0 errors, 0 warnings, 0 references to `__cxa_*` or the heap | `cpp-m0plus` |
| Cortex-M3 on QEMU `mps2-an385` | every vector run equals the number asserted (241 `expect(` calls in the six vector files after loop 16, 223 before); malloc and new wrapper calls are 0; session vectors; one image runs at most 300 seconds (`qemu_timeout_s`), and a hung image is killed and fails the target | `cpp-m3-qemu` |
| Cortex-M4F size and stack | flash for the core plus a 14-field table ≤ 8192 bytes; deepest pack or unpack ≤ 512 bytes of stack; `.data` and `.bss` 0. Measured after loop 16: 7784 bytes of flash (7728 before) and 488 bytes of stack | `cpp-m4f` |
| s390x big-endian on QEMU user | the same vectors, the same bytes | `cpp-s390x` |
| ESP32-S3 and ESP32-C3 builds | ESP-IDF builds with 0 warnings | `cpp-esp32s3`, `cpp-esp32c3` |
| Packaged examples | ESP-IDF component, Arduino-ESP32 library layout and Pico PlatformIO archive each build the README example | `cpp-example-esp-idf`, `cpp-example-esp32-arduino`, `cpp-example-pico` |
| Harness result rule (AZ-2099) | `run_target` always returns 0; a target is FAIL when its function exits non-zero (errexit is on in a child process, and the log names the failed command: `target command failed: ...`) or when a `fail` left the marker `<id>.failed`, and the stage exits 1 when any target failed. With a broken `arm-none-eabi-nm` the old harness reported 4 PASS; the new one reports FAIL for `cpp-m0plus`, `cpp-m3-qemu` and `cpp-m4f` and exits 1 (measured on a Mac). `run_stage_target` is removed | `cpp/embedded/lib.test.sh` (31 checks against fake targets, run by the `scaffold` job; the 31st fails when a `cpp/embedded` script pipes `find` into `head`, which ends the pipeline with SIGPIPE under `pipefail`, AZ-2238), `cpp/embedded/lib.sh`, `cpp/embedded/run.sh` |

## vcpkg Port Checks (AZ-2098, AZ-2232, AZ-2240, loop 16)

`.github/workflows/publish-vcpkg.test.sh` is sourced by `publish-gate.test.sh` (the `scaffold` job); `bash publish-gate.test.sh --vcpkg` runs only it. It stages the port into a local bare git registry through the real `publish-registries.sh` (`PACKBIN_DOCKER=0`, the optional targets skipped for lack of a token) and then:

| Test | What it proves | AC |
|------|----------------|----|
| consumer install | a project with `vcpkg.json` (`packbin`) and a `vcpkg-configuration.json` that names the bare registry and a baseline for the builtin one installs the port through the vcpkg toolchain, builds with `find_package(packbin CONFIG REQUIRED)` and `packbin::packbin`, and the program prints the golden hex | AC-1, AC-2 |
| `add_subdirectory` | `add_subdirectory(<repo>/cpp packbin)` builds with the targets `packbin` and `packbin::packbin`, and both programs print the golden hex | AC-3 |
| port content | the registry holds `CMakeLists.txt` (equal to `cpp/CMakeLists.txt`), `LICENSE` (equal to the repository one), `portfile.cmake` with the four vcpkg CMake calls, `vcpkg.json` (name, version, MIT, host dependencies `vcpkg-cmake` and `vcpkg-cmake-config`), the headers and `src`; `versions/p-/packbin.json` has the git-tree of the port and `versions/baseline.json` the version; the installed `share/packbin/copyright` is the repository `LICENSE` | AC-4 |
| re-staging | staging the same version a second time adds no commit | AC-5 |
| `supports` (`vcpkg_port_checks`, AZ-2232 AC-1) | the staged `vcpkg.json` declares `"supports": "linux \| osx"` | AZ-2232 AC-1 |
| `vcpkg_supports_check` (AZ-2232 AC-2) | `vcpkg install --dry-run --triplet x64-windows` exits 1 with `packbin is only supported on 'linux \| osx', which does not match x64-windows.`; `x64-linux` exits 0 without that text and plans `packbin:x64-linux@0.9.0`; a dry run, so no build and no compiler for the other triplet. NOT RUN without the vcpkg tool | AZ-2232 AC-2 |
| second consumer project (AZ-2232 AC-3) | the same manifest asks `find_package(packbin 0.9 CONFIG)` and prints the golden hex, and a second project asks `find_package(packbin 0.2 CONFIG)` and must print `packbin 0.2 not found` (`vcpkg_version` is 0.9.0) | AZ-2232 AC-3 |
| `vcpkg_version_rule_check` (AZ-2232 AC-4) | cmake only: `cpp/` is installed as 0.9.0, 0.10.2 and 1.4.0 and an empty project asks `find_package` for each request. 0.9.0 answers `0.9` and `0.9.0` and refuses `0.1`, `0.2`, `0.10`, `0.1.0`, `0.9.1`, `0` and `1.0`; 0.10.2 answers `0.10`; 1.4.0 answers `1.0`, `1.2` and `1.4` and refuses `1.5`, `2.0` and `0.9`. NOT RUN without cmake | AZ-2232 AC-4 |
| `vcpkg_guard_checks` (AZ-2240 AC-3, AC-4) | `publish-check.py vcpkg` passes on the staged port and fails with the exact message for each of eight mutants: no `CMakeLists.txt`, one that is only a comment, no `LICENSE`, an empty one, no `vcpkg-cmake`, no `vcpkg-cmake-config`, no `dependencies`, both host entries off | AZ-2240 AC-3, AC-4 |

The consumer check uses the vcpkg of the GitHub runner (`VCPKG_INSTALLATION_ROOT`), or `VCPKG_ROOT`, or the one on `PATH`; it has no pin. A missing vcpkg or cmake fails the job on GitHub Actions. Anywhere else it prints `vcpkg consumer check NOT RUN: no vcpkg tool`, and the last line of the gate reads `publish gate: no failures, NOT RUN: <checks>`: a check that did not run is not a pass. The script honors `PACKBIN_CXX_SYSROOT` itself (macOS): it adds the sysroot flags to the cmake builds (`add_subdirectory` and the consumer) and writes a temporary overlay triplet with `VCPKG_C_FLAGS` and `VCPKG_CXX_FLAGS` for the vcpkg consumer, because vcpkg ignores `CXXFLAGS`; unset, as on the CI runner, nothing of it exists.

## Test Data Management

**Required test data**:

| Data Set | Description | Source | Size |
|----------|-------------|--------|------|
| position | the 13-byte hex and the five fields | golden fixture file | 13 bytes |
| flags | flags 0x00 and flags 0x20 with a uint16 at bit 5 | the same fixture rows | under 1 KB |
| short | a buffer that ends inside a field | the same fixture rows | under 1 KB |

**Setup procedure**:
1. Build this package
2. Read the golden fixture file. Do not copy the hex into a second list

**Teardown procedure**:
1. Discard the test process
2. Do not leave a registry token on disk

**Data isolation strategy**: each test builds its own value in memory. There is no database and no shared mutable fixture.
