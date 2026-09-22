# Module Layout

**Language**: mixed
**Layout Convention**: custom
**Root**: ./
**Last Updated**: 2026-09-22

## Layout Rules

1. Each language package owns one top-level directory.
2. The packages do not import each other. There is no `shared/` code package.
3. The golden fixture is data, owned by the bootstrap task. Every package reads it. None of them import it as a library.
4. Public API is the file named below. Other files in that directory are internal.
5. Tests live in `<language>/tests/`.

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
- **Owns (exclusive write during implementation)**: `rust/**`
- **Imports from**: none
- **Consumed by**: a native node

> See ADR 001_runtime-primitives-no-generator.

### Component: cpp

- **Epic**: AZ-1863
- **Directory**: `cpp/`
- **Public API**:
  - `cpp/include/packbin/packbin.hpp`
- **Internal (do NOT import from other components)**:
  - `cpp/**` except `cpp/include/packbin/packbin.hpp`
- **Owns (exclusive write during implementation)**: `cpp/**`
- **Imports from**: none
- **Consumed by**: a C++ program

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

No shared code package. The library does not log, authenticate, or load configuration.

### fixtures

- **Directory**: `fixtures/`
- **Purpose**: `golden.hex`, the position row `4001000065cd1d00a3e1110100`
- **Owned by**: AZ-1866
- **Consumed by**: all six packages, as a file read, not an import

### workflows

- **Directory**: `.github/workflows/`
- **Purpose**: test on every push and pull request; publish on a version tag
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
| C++ | `cpp/` | `cpp/include/packbin/` | `cpp/include/packbin/packbin.hpp` | `cpp/tests/` |
| Java | `java/` | `java/src/main/java/packbin/` | `java/src/main/java/packbin/Packbin.java` | `java/src/test/` |
