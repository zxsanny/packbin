# Module Layout

**Language**: mixed
**Layout Convention**: custom
**Root**: ./
**Last Updated**: 2026-10-06

## Layout Rules

1. Each language package owns one top-level directory.
2. The packages do not import each other. There is no `shared/` code package.
3. The golden fixture is data, owned by the bootstrap task. Every package reads it. None of them import it as a library.
4. Public API is the file or headers named below. Other files in that directory are internal.
5. Test paths are in the table below. Java tests live in `java/src/test/`.

## ADR-driven exceptions to the conventional layout

A single `src/`, `crates/`, or `packages/` tree would put six languages in one convention. ADR 002 publishes six registries from one tag, and ADR 003 publishes C++ as its own vcpkg port. Each language therefore keeps that language's files inside its own root.

> See ADR 002_publish-from-version-tag, ADR 003_cpp-vcpkg-git-registry.

## Per-Component Mapping

### Component: csharp

- **Epic**: AZ-1859
- **Directory**: `csharp/`
- **Public API**:
  - `csharp/Packbin.cs`
- **Internal (do NOT import from other components)**:
  - `csharp/**` except `csharp/Packbin.cs`
  - Construction checks: `csharp/FlagScopes.cs`, `csharp/RoundScopes.cs` (a `repeat` or `times` inside a round, loop 13); the reference scope and row-type checks are `SchemeOrder` in `Packbin.cs`
  - Walkers: `csharp/Walker*.cs`, with `csharp/Walker.Rounds.cs` (round pack and aligned unpack, loop 13); per-call state in `csharp/Scope.cs`, which also holds the round budget (`RoundBudget`, loop 15)
  - Tests: `csharp/tests/RoundLimitTests.cs` (round limits, AZ-2216); the hostile `limit` cases are replayed in `csharp/tests/HostileVectorTests.cs`
- **Owns (exclusive write during implementation)**: `csharp/**`
- **Imports from**: none
- **Consumed by**: the caller's server

> See ADR 001_runtime-primitives-no-generator.

### Component: typescript

- **Epic**: AZ-1860
- **Directory**: `typescript/`
- **Public API**:
  - `typescript/src/index.ts`
- **Internal (do NOT import from other components)**:
  - `typescript/src/**` except `typescript/src/index.ts`
  - Construction checks: `typescript/src/flag-scope.ts`, `typescript/src/member-names.ts` (name collisions) and `typescript/src/ref-scope.ts` (reference binder), the last two new in loop 13; the nested-round refusal is `validateRoundNesting` in `typescript/src/rounds.ts`
  - Walkers: `typescript/src/walker.ts` (unpack), `typescript/src/pack-fields.ts` (pack; since loop 16 it keeps a map of what pack wrote in each scope for `when` and counts), `typescript/src/rounds.ts` (round names, count, slice, aligned lists and `refuseLongLists`, loop 13), `typescript/src/flag-bits.ts` (which flag bits pack sets: `collectFlagBits`, `bitOn`, `flagValueFor`; new in loop 16); construction also binds and numbers the split flag bits in `typescript/src/flag-scope.ts` (`bindFlagBits`, AZ-2135); the unpack round counters live on `ViewCursor` in `typescript/src/kinds.ts` and `refuseRound` in `walker.ts` checks them (loop 15)
  - Tests: `typescript/tests/round-limits.test.ts` (round limits, AZ-2217); the hostile `limit` cases are replayed in `typescript/tests/hostile.test.ts`. Loop 16: `u64-count.test.ts` (AZ-2112), `list-group-elements.test.ts` (AZ-2102), `times-longer-list.test.ts` (AZ-2185), `flags-under-split-bit.test.ts` (AZ-2183), `dict-keys-not-flattened.test.ts` (AZ-2184), `duplicate-names.test.ts` (AZ-2188), `when-on-written-values.test.ts` (AZ-2197), `flag-group-presence.test.ts` (AZ-2128), `split-bits-field-order.test.ts` (AZ-2135), `split-form-reference.test.ts` (AZ-2115), with the seeded generator in `tests/support/random.ts`
  - Package build (loop 16, AZ-2103): `typescript/tsconfig.build.json` and the `build` script of `typescript/package.json` compile `src` to `dist` (`typescript/dist/` is gitignored; the npm package ships `dist/` only); the tests and the CI drivers keep running from `src`
- **Owns (exclusive write during implementation)**: `typescript/**`
- **Imports from**: none
- **Consumed by**: Vue, React, and Node

> See ADR 001_runtime-primitives-no-generator.

### Component: python

- **Epic**: AZ-1861
- **Directory**: `python/`
- **Public API**:
  - `python/src/packbin/__init__.py`
- **Internal (do NOT import from other components)**:
  - `python/src/packbin/**` except `python/src/packbin/__init__.py`
  - Construction checks: `python/src/packbin/_validate.py` (`_validate_order` for ids, references and bool placement, `_validate_flag_bits` for split flag bits, `_validate_round_nesting`; new in loop 16, `_validate_order` moved there from `_nodes.py`)
  - Walkers: `python/src/packbin/_pack.py` (pack), `python/src/packbin/_unpack.py` (unpack, with the per-call `_Budget` of the round limits, loop 16); `python/src/packbin/_scheme.py` holds `Scheme` (`with_limits`, `max_rounds`, `max_slots`) and `BinaryPacker`; the field builders and nodes are `python/src/packbin/_nodes.py`
  - Tests: `python/tests/test_reference_scope.py` (AZ-2113), `test_star_import.py` (AZ-2104), `test_times_longer_list.py` (AZ-2186), `test_float_pack_strict.py` (AZ-2192), `test_split_form.py` (AZ-2100), `test_round_lists.py` (AZ-2134), `test_flag_group_presence.py` (AZ-2128), `test_round_limits.py` (round and slot limits); the hostile `limit` cases are replayed in `test_hostile_vectors.py` with the schemes of `hostile_support.py`
- **Owns (exclusive write during implementation)**: `python/**`
- **Imports from**: none
- **Consumed by**: tools and scripts

> See ADR 001_runtime-primitives-no-generator.

### Component: rust

- **Epic**: AZ-1862
- **Directory**: `rust/`
- **Public API**:
  - `rust/src/lib.rs`
- **Internal (do NOT import from other components)**:
  - `rust/src/**` except `rust/src/lib.rs`
  - Construction checks (`MapScheme::new`): `rust/src/field/order.rs`, `field/shape.rs`, `field/integrity.rs` (`when` source and element kinds, loop 13; the scope of every `when` and count, by name and by id, loop 16)
  - Typed layer: `rust/src/scheme/mod.rs` and `scheme/bound.rs`; `scheme/times.rs` (the typed `times` over a `Vec<E>`, loop 13) is reached through `SchemeItem::times`
  - Walkers: `rust/src/walk/pack.rs`, `walk/unpack.rs`, `walk/element.rs`, and `walk/times.rs` (round lists, the list/rounds agreement check, loop 13, and `check_aligned` for a member below `flags` or `when`, loop 16); `walk/unpack.rs` holds the per-call `Cursor` with the round limits (loop 15); `session/mod.rs` holds `PackSession` and `SessionPackError` (loop 16)
  - Tests: `rust/tests/round_limits_tests.rs` (round limits, AZ-2219); the hostile `limit` cases are replayed in `rust/src/hostile_tests.rs`. Loop 16: `rust/src/name_scope_tests.rs` (AZ-2117), `rust/src/flag_group_tests.rs` (AZ-2128), `rust/src/session_hostile_tests.rs` (AZ-2114), and the session pack tests in `rust/tests/session_tests.rs` (AZ-2105), the map `times` under `flags` tests in `rust/src/times_tests.rs` (AZ-2189) and the checked-count test in `rust/src/borrowed_count_tests.rs` (AZ-2118)
- **Owns (exclusive write during implementation)**: `rust/**`
- **Imports from**: none
- **Consumed by**: a native node

> See ADR 001_runtime-primitives-no-generator.

### Component: cpp

- **Epic**: AZ-1863
- **Directory**: `cpp/`
- **Public API**: the headers in `cpp/include/packbin/`
  - `codec.hpp` (`scheme`, `pack`, `unpack`, `on`, `validate`), `session.hpp` (`PackSession`, `RandomFn`), `os_random.hpp` (host random source)
  - `core.hpp` (`Result`, `Error`, `Reader`, `Writer`), `fields.hpp`, `fields_grouped.hpp`, `fields_counted.hpp` (field builders), `order.hpp` (field-order rules), `table.hpp` (`Field`, `Opt`, `View`, `Text`, `Blob`, `Array`, `Entry`)
  - `packbin.hpp` includes `codec.hpp`, `os_random.hpp` and `session.hpp`; `cpp/arduino/packbin.h` includes `codec.hpp` and `session.hpp`
- **Internal (do NOT import from other components)**:
  - `cpp/src/core/*.cpp` and `cpp/src/core/values.hpp` (the walker: `pack.cpp`, `unpack.cpp`, `values.cpp`, `session.cpp`)
  - `cpp/src/os_random.cpp` (host only; firmware does not compile it)
  - Split flag bits (loop 16, AZ-2135): `find_flag_byte` and `bit_position` in `cpp/include/packbin/order.hpp` bind a bit to a flag byte of its container read before it and outside a closed `when`; `unpack_when` in `cpp/src/core/unpack.cpp` restores the flag byte values when a taken `when` ends; tests in `cpp/tests/core/grouped_tests.cpp`
- **Tests**: `cpp/tests/core/*_tests.cpp` (the vector suites also run on firmware), `cpp/tests/core/hostile_host_tests.cpp` (runs `fixtures/hostile/cases.txt` on the host), `cpp/tests/compile-fail/` (cases that must not compile)
- **Embedded and packaging**:
  - `cpp/embedded/` — the target driver `run.sh`, the arm and ESP stages, the Dockerfile for the `cpp-embedded` image; `lib.sh` holds `run_target` (which always returns 0: a target is FAIL on a non-zero exit of its function or on the marker `<id>.failed` that `fail` leaves, and `run.sh` exits 1 when any target failed; loop 16, AZ-2099) and `cpp/embedded/lib.test.sh` tests it (30 checks, run by the `scaffold` job)
  - `cpp/examples/` — the Pico (PlatformIO), Arduino-ESP32 and ESP-IDF examples
  - `cpp/arduino/` — `library.properties` and `packbin.h` for the Arduino layout
  - `cpp/library.json` (PlatformIO), `cpp/idf_component.yml` and `cpp/CMakeLists.txt` (ESP-IDF component and plain CMake library)
- **Owns (exclusive write during implementation)**: `cpp/**`
- **Imports from**: none
- **Consumed by**: a C++ program or firmware

> See ADR 001_runtime-primitives-no-generator, ADR 003_cpp-vcpkg-git-registry.

### Component: java

- **Epic**: AZ-1864
- **Directory**: `java/`
- **Public API**:
  - `java/src/main/java/packbin/Packbin.java`
- **Internal (do NOT import from other components)**:
  - `java/src/**` except `java/src/main/java/packbin/Packbin.java`
  - API-level check (loop 14, AZ-2094): `java/api-check.sh`, `java/tools/ApiCheck.java`, `java/tools/Fetch.java`, run from `java/test.sh`; tool cache `java/out/api-tools` (gitignored)
  - Round limits (loop 15, AZ-2218): `Cursor.java` (read position and round budget of one unpack call, replaces the `int[] offset` of every unpack method), `Scheme.java` (`withLimits`), `Rounds.java`; tests `java/src/test/java/packbin/RoundLimitsTest.java` (run from `PackbinTest`), the hostile `limit` cases in `HostileVectorTest.java`
  - Loop 16 tests, all run from `PackbinTest`: `NestedRoundTest` (AZ-2127), `TimesLongerTest` (AZ-2187), `PackStrictTest` (AZ-2190), `TypedNestedRowTest` (AZ-2101), `FlagPresenceTest` (AZ-2128), `HostileSessionTest` (AZ-2114), `FlagScopeContainerTest` (AZ-2121), `SplitBitOrderTest` (AZ-2135). The split flag bits are bound and numbered in `SchemeOrder.bindFlagBits` (the `Scheme` constructor calls it after `SchemeOrder.validate`)
- **Owns (exclusive write during implementation)**: `java/**`
- **Imports from**: none
- **Consumed by**: Android and other Java programs

> See ADR 001_runtime-primitives-no-generator.

## Shared / Cross-Cutting

No shared code package. The library does not log, authenticate, or load configuration. Each package implements the connection session in its own public entry. None imports another.

### fixtures

- **Directory**: `fixtures/`
- **Purpose**: `golden.hex`, the position row `4001000065cd1d00a3e1110100`
- **Owned by**: AZ-1866
- **Consumed by**: all six packages, as a file read, not an import

### fixtures/hostile

- **Directory**: `fixtures/hostile/`
- **Purpose**: `cases.txt`, packets and schemes that crafted input can send, with the expected outcome kinds; `check-cases.sh` checks the file format and `cases.test.sh` proves that check fails on corrupted copies. Since loop 15 (AZ-2220) the file holds 19 cases; the `limit` stage (two cases, a `repeat` and a `times` past a low round limit) is replayed by C#, TypeScript, Java, Rust and (since loop 16) Python, and skipped by C++
- **Owned by**: AZ-2070
- **Consumed by**: every package, as a file read. The C++ runner is `cpp/tests/core/hostile_host_tests.cpp`

### workflows

- **Directory**: `.github/workflows/`
- **Purpose**: test on every branch push and pull request (jobs `scaffold`, `embedded` for the C++ targets, and `ring`, the cross-language hand-offs, loop 16); publish on a version tag, after `publish.yml` has called `test.yml` on the tagged commit (loop 14). The helper scripts (`run-suite.sh`, `publish-*.sh`, `stage-arduino.sh`, `report-row.sh`) and the `drivers/` for the language-pair run live in the same directory. `language-pair.sh` has the `roundflags` and `roundwhen` rings since loop 13 (AZ-2179): producers C#, TypeScript, Rust, Java and C++, readers TypeScript, Rust, Java and C++ (C# has no public reader, AZ-2092); the Rust driver builds them in `drivers/handoff-rust/src/rounds.rs`. The ring runs on every push and pull request in the `ring` job of `test.yml` (AZ-2193, loop 16): `ring-toolchains.sh` checks the six toolchain versions, `ring-cxx.sh` is the `CXX` wrapper that compiles C++ in the `gcc:16` image, and `ring-wiring.test.sh` (a `scaffold` step) guards the wiring. The `bitwhen` ring has a Python participant since loop 16: six hand-offs, C# to TypeScript, TypeScript to Python, Python to Rust, Rust to Java, Java to C++ and C++ to C#
- **Publish scripts** (loop 14, AZ-2095 to AZ-2097): `publish-gate.sh` (golden check, writes the plan), `publish-registries.sh` (entry point: plan, credential and tool preflight, build, upload; `PACKBIN_BUILD_ONLY=1` is the build-only dry run), `publish-build.sh` with `publish-inside.sh` (language packages in their toolchain image), `publish-embedded.sh` (vcpkg, PlatformIO, ESP-IDF, Arduino) and `publish-sign.sh` (Maven bundle signature), `publish-check.py` (artifact checks), `publish-upload.sh` with `publish-query.sh` and `publish-published.py` (existence queries), `publish-lib.sh` (target table `PACKBIN_TARGETS`, credentials, `publish_container` and `pip_install_pinned` since loop 15), `crates-token.sh`, `publish-position.sh`
- **Pins and read-only containers** (loop 15, AZ-2214, AZ-2215): `tool-pins.txt` (one exact version per tool) and `tool-pin.sh` (prints one) are read by `publish-lib.sh`, `publish-inside.sh`, `run-suite.sh`, `publish.yml` and `cpp/embedded/examples.sh`; every non-local `uses:` is a commit SHA with a tag comment. `docker-compose.publish.yml` (repo root, the second compose file) mounts the repo read-only in the golden-gate and build containers, and only `publish_container` passes it
- **Publish tests**: `publish-gate.test.sh` (workflow structure parsed with Ruby `yaml`, gate and static checks; it sources `publish-phases.test.sh` for the two-phase scenarios and `publish-rerun.test.sh` for the credential matrix, re-run and registry scenarios); each file stays at or under 500 lines (`publish-phases.test.sh` is 501 in the working tree, one over, from the uncommitted C# multi-target change, `publish-gate.test.sh` 467, so a new check goes in a new sibling file). Loop 15 added two such files, sourced by `publish-gate.test.sh`: `publish-pins.test.sh` (the `uses:` pin check, the pins file and its reader, the pip install lines, AZ-2214) and `publish-readonly.test.sh` (the read-only mount in every service, the artifacts mount, the unchanged tree after a gate and a build-only run, AZ-2215). Loop 16 added `publish-npm.test.sh` (AZ-2103: the npm tarball layout checks of `publish-check.py`, `package.json` and a build through the real `publish-inside.sh`; `bash publish-gate.test.sh --npm` runs only these)
- **Owned by**: AZ-1866 owns `test.yml` and the workflow files existing. AZ-1875 owns the publish behavior in `publish.yml`; AZ-2095 to AZ-2097 own the structure of `publish.yml` and the publish scripts and tests above; AZ-2214 and AZ-2215 own the pins and the read-only containers
- **Consumed by**: the six registries

> See ADR 002_publish-from-version-tag.

## Allowed Dependencies (layering)

The six packages are peers. None imports another.

| Layer | Components | May import from |
|-------|------------|-----------------|
| 1. Packages | csharp, typescript, python, rust, cpp, java | none |
| 0. Fixture and workflows | fixtures, .github/workflows | none |

## Layout Conventions (reference)

| Language | Root | Per-component path | Public API file | Test path |
|----------|------|-------------------|-----------------|-----------|
| C# | `csharp/` | `csharp/` | `csharp/Packbin.cs` | `csharp/tests/` |
| TypeScript | `typescript/` | `typescript/src/` | `typescript/src/index.ts` | `typescript/tests/` |
| Python | `python/` | `python/src/packbin/` | `python/src/packbin/__init__.py` | `python/tests/` |
| Rust | `rust/` | `rust/src/` | `rust/src/lib.rs` | `rust/tests/` |
| C++ | `cpp/` | `cpp/include/packbin/`, `cpp/src/core/` | the headers in `cpp/include/packbin/` | `cpp/tests/core/`, `cpp/tests/compile-fail/` |
| Java | `java/` | `java/src/main/java/packbin/` | `java/src/main/java/packbin/Packbin.java` | `java/src/test/` |
