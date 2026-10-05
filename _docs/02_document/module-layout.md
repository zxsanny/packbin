# Module Layout

**Language**: mixed
**Layout Convention**: custom
**Root**: ./
**Last Updated**: 2026-10-05

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
  - Walkers: `csharp/Walker*.cs`, with `csharp/Walker.Rounds.cs` (round pack and aligned unpack, loop 13); per-call state in `csharp/Scope.cs`
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
  - Walkers: `typescript/src/walker.ts` (unpack), `typescript/src/pack-fields.ts` (pack), `typescript/src/rounds.ts` (round names, count, slice and aligned lists, loop 13)
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
  - Construction checks (`MapScheme::new`): `rust/src/field/order.rs`, `field/shape.rs`, `field/integrity.rs` (`when` source and element kinds, loop 13)
  - Typed layer: `rust/src/scheme/mod.rs` and `scheme/bound.rs`; `scheme/times.rs` (the typed `times` over a `Vec<E>`, loop 13) is reached through `SchemeItem::times`
  - Walkers: `rust/src/walk/pack.rs`, `walk/unpack.rs`, `walk/element.rs`, and `walk/times.rs` (round lists and the list/rounds agreement check, loop 13)
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
- **Tests**: `cpp/tests/core/*_tests.cpp` (the vector suites also run on firmware), `cpp/tests/core/hostile_host_tests.cpp` (runs `fixtures/hostile/cases.txt` on the host), `cpp/tests/compile-fail/` (cases that must not compile)
- **Embedded and packaging**:
  - `cpp/embedded/` — the target driver `run.sh`, the arm and ESP stages, the Dockerfile for the `cpp-embedded` image
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
- **Purpose**: `cases.txt`, packets and schemes that crafted input can send, with the expected outcome kinds; `check-cases.sh` checks the file format and `cases.test.sh` proves that check fails on corrupted copies
- **Owned by**: AZ-2070
- **Consumed by**: every package, as a file read. The C++ runner is `cpp/tests/core/hostile_host_tests.cpp`

### workflows

- **Directory**: `.github/workflows/`
- **Purpose**: test on every push and pull request (including the `embedded` job for the C++ targets); publish on a version tag. The helper scripts (`run-suite.sh`, `publish-*.sh`, `stage-arduino.sh`, `report-row.sh`) and the `drivers/` for the language-pair run live in the same directory. `language-pair.sh` has the `roundflags` and `roundwhen` rings since loop 13 (AZ-2179): producers C#, TypeScript, Rust, Java and C++, readers TypeScript, Rust, Java and C++ (C# has no public reader, AZ-2092); the Rust driver builds them in `drivers/handoff-rust/src/rounds.rs`
- **Owned by**: AZ-1866 owns `test.yml` and the workflow files existing. AZ-1875 owns the publish behavior in `publish.yml`
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
