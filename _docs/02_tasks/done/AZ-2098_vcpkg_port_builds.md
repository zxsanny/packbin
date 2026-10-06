# vcpkg port builds the library and exports a CMake target

**Task**: AZ-2098_vcpkg_port_builds
**Name**: Buildable vcpkg port with consumer check
**Description**: `vcpkg install packbin` from the project's git registry builds the C++ core and gives `find_package(packbin CONFIG)` a linkable `packbin::packbin` target; CI proves it with a consumer build against a fake registry.
**Complexity**: 3 points
**Dependencies**: None. If AZ-2096_publish_build_before_upload lands first, the port staging lives in its build phase; keep that structure.
**Component**: vcpkg
**Tracker**: AZ-2098
**Epic**: AZ-2069

## Problem

The C++ package is published as port `packbin` in a git registry: branch `vcpkg` of `https://github.com/zxsanny/packbin.git` (ADR-003). The port is not usable:

- `stage_vcpkg_port` (`.github/workflows/publish-registries.sh:80-101`):
  - copies `cpp/include/packbin` into `ports/packbin/include/packbin` and `cpp/src/.` into `ports/packbin/src`;
  - writes `vcpkg.json` with name, version, description, license and homepage only — no `vcpkg-cmake` dependencies;
  - writes a 4-line `portfile.cmake` that installs headers into `include/` and **copies the sources into `share/packbin/src`**;
  - writes `copyright` as the literal `MIT\n`, not the LICENSE text.
- Nothing compiles `src/core/*.cpp`. The public headers declare functions that live only in those sources: `detail::pack_table` / `unpack_table` (`cpp/include/packbin/codec.hpp:65-67`) and the `PackSession` methods (`session.hpp:31-42`, defined in `src/core/session.cpp`). A consumer that includes `<packbin/packbin.hpp>` and calls `pack(...)` gets unresolved symbols at link time.
- No CMake package config is installed, so `find_package(packbin CONFIG REQUIRED)` fails.
- `README.md:329` promises "vcpkg port `packbin`, or `add_subdirectory(cpp)` → target `packbin`". `cpp/CMakeLists.txt:16-26` does define a `STATIC` library `packbin` for `add_subdirectory`, plus option `PACKBIN_OS_RANDOM` (ON) adding `src/os_random.cpp`. It has **no `install()` or `export()` rules**.
- `publish-gate.test.sh` `registry_checks` (`:91-115`) only checks that `ports/packbin/vcpkg.json` contains the name and license, and that the `vcpkg` ref exists. No consumer was ever built.

Sources: `components/07_ci_publish.md` F2, `scan_ci_docs.md` LF2/D3, `doc_drift.md` #7, `list-of-changes.md` C12.

## Outcome

- The port builds `cpp/CMakeLists.txt` with vcpkg's CMake helpers. It installs the static library, the public headers and a CMake config exporting **`packbin::packbin`**. The copyright file is the repository `LICENSE`.
- `add_subdirectory(cpp)` keeps target `packbin` and also offers the alias `packbin::packbin`, so both README forms work with one name.
- A CI check builds a tiny consumer through the port from a fake git registry (a local bare repo, as in `registry_checks`). The consumer packs the golden position row and must print `4001000065cd1d00a3e1110100`, the content of `fixtures/golden.hex`.
- The ESP-IDF component path (`cpp/CMakeLists.txt:10-14`, `if(ESP_PLATFORM)`) is unchanged. The embedded `esp` stage and the ESP-IDF example keep building (`cpp/embedded/esp.sh`, `examples.sh:78-105`).
- README's C++ install row shows the vcpkg use: `find_package(packbin CONFIG REQUIRED)` + `target_link_libraries(app PRIVATE packbin::packbin)`.

## Scope

### Included
- `cpp/CMakeLists.txt` (host branch only): install rules for the library and headers, export set → `packbin-config.cmake` (+ version file) with namespace `packbin::`, and alias `packbin::packbin`. This is C++ package scope, done here because the port needs it; no source or header changes.
- `stage_vcpkg_port` in `publish-registries.sh`:
  - the port carries the sources it builds: `CMakeLists.txt`, `include/`, `src/`, `LICENSE`, either vendored into the port directory as today or fetched from the tag — see Flagged concerns;
  - `vcpkg.json` declares the host dependencies `vcpkg-cmake` and `vcpkg-cmake-config`;
  - the portfile configures, installs, fixes up the config and installs the copyright from `LICENSE`.
- `record_vcpkg_version` (`:103-120`) and the `git-tree` logic (`:144-149`) stay. The tree hash must still match the committed `ports/packbin`.
- Consumer check in `publish-gate.test.sh` after the existing vcpkg registry dry run (`:90-115`):
  - create a consumer project in a temp dir: `vcpkg.json` depending on `packbin`; `vcpkg-configuration.json` with a git registry whose `repository` is the bare repo, `reference` `vcpkg`, `baseline` = that branch's head commit, `packages: ["packbin"]`; a `CMakeLists.txt` with `find_package(packbin CONFIG REQUIRED)`; a `main.cpp` packing the golden position (the scheme in `.github/workflows/drivers/position.cpp:5-19`);
  - configure with the vcpkg toolchain, build, run, and compare stdout with `fixtures/golden.hex`.
- README row `README.md:329` and ADR-003 "Consequences" wording (`find_package` usage).

### Excluded
- Upstreaming to microsoft/vcpkg (ADR-003 rejects it).
- PlatformIO, Arduino and ESP-IDF packaging.
- Making the core header-only.
- C++ core API changes (task 09/12 and C13).

## Acceptance Criteria

**AC-1: Consumer builds and links through the port**
Given the port staged by `publish-registries.sh` into a bare git registry (`VCPKG_REGISTRY_URL=<bare repo>`, version `0.1.0` as in `registry_checks`)
When a consumer project installs `packbin` from that registry and builds with `find_package(packbin CONFIG REQUIRED)` and `target_link_libraries(... packbin::packbin)`
Then configure, build and link succeed with 0 errors.

**AC-2: Consumer produces the golden bytes**
Given the AC-1 consumer packing the position row
When it runs
Then stdout (whitespace trimmed) equals `fixtures/golden.hex`.

**AC-3: add_subdirectory unchanged plus alias**
Given a CMake project with `add_subdirectory(<repo>/cpp packbin)`
When it links `packbin` or `packbin::packbin`
Then both build. The C++ host suite (`make -C cpp test`) and the embedded `esp` stage are unaffected.

**AC-4: Port metadata is valid**
Given the staged `ports/packbin`
When vcpkg reads it
Then `vcpkg.json` has name `packbin`, the tag version, license `MIT` and the `vcpkg-cmake`/`vcpkg-cmake-config` host dependencies. `share/packbin/copyright` holds the repository `LICENSE` text. `versions/baseline.json` and `versions/p-/packbin.json` point at the committed `git-tree`.

**AC-5: Re-staging the same version is a no-op**
Given a registry that already holds this version's port
When the port is staged again with identical sources
Then no new commit is created (idempotent re-run, consistent with task 28).

## Non-Functional Requirements

**Compatibility**
- The port builds with the vcpkg default triplet on the CI Linux host (`x64-linux`), C++17 (`target_compile_features ... cxx_std_17` already declared).

**Performance**
- The consumer check adds at most a few minutes to the `scaffold` job. vcpkg tool bootstrap is cached or preinstalled.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-4 | staged port files (`vcpkg.json` deps, portfile uses vcpkg CMake helpers, `LICENSE` present) | pass |
| AC-5 | stage twice into the same bare repo | second run: `git rev-list --count vcpkg` unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1, AC-2 | bare vcpkg registry from `registry_checks`; vcpkg tool on the CI host | consumer install + build + run | prints the golden hex | Compatibility |
| AC-3 | temp project with `add_subdirectory` | build both target names | success | — |

## Constraints

- Canonical path only: the port reaches users only through the tag job's `git push` to branch `vcpkg` (ADR-003). The consumer check uses a local bare repo and never pushes to GitHub.
- No tokens in the test: the bare registry needs none.
- No product source changes, except `cpp/CMakeLists.txt` install/export rules.
- `bash.md` rules for any script change. Temp dirs via `mktemp` + `trap`.

## Risks & Mitigation

**Risk 1: vcpkg tool availability and version drift**
- *Risk*: GitHub's `ubuntu-latest` image ships vcpkg (`VCPKG_INSTALLATION_ROOT`), but its version moves. A local developer may have none.
- *Mitigation*: Use a pinned vcpkg commit (clone + bootstrap, cached), or the runner's copy with its version logged. If vcpkg is absent, the check **fails** with a clear message; it never silently skips.

**Risk 2: The port tree hash changes on every publish**
- *Mitigation*: AC-5. The vendored sources only change when the C++ sources change.

**Risk 3: The ESP-IDF branch breaks**
- *Mitigation*: Install rules sit after the `if(ESP_PLATFORM) … return()` block. The embedded CI `esp` stage is the guard.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Source location: keep the sources vendored inside the port directory (today's model: self-contained, no network, larger port tree) or switch to `vcpkg_from_github` with REF `v<version>` + SHA512 of the GitHub tag archive (vcpkg-standard; relies on archive checksum stability and the tag existing before the push). Recommend vendored; confirm | user / implementer | open | Medium |
| Where the consumer check runs: `scaffold` job on the runner host (vcpkg preinstalled) vs a container (no vcpkg/cmake in `gcc:16`). The runner host is not the compose canonical env — record the choice | implementer | open | Low |
| `PACKBIN_OS_RANDOM` defaults ON, so the port builds `os_random.cpp` (needs `getrandom`/`arc4random`). Fine for host triplets; a vcpkg feature to turn it off is out of scope | C++ owner | accepted-risk | Low |
| Ports already in the registry (`0.1.x`) remain unbuildable; registries are immutable | release owner | accepted-risk | Low |

## Owner decision (2026-10-06)

DECIDED, the proposed default: vendored sources in the port (not `vcpkg_from_github`). The open DECISION rows above are resolved by this section.

## Loop 16 result (2026-10-06)

Done in loop 16 (batch 4), owner decision followed: vendored sources. `stage_vcpkg_port` (in `publish-embedded.sh` since AZ-2096) vendors `CMakeLists.txt`, `LICENSE`, `include/packbin` and `src` into `ports/packbin`; the port declares the host dependencies `vcpkg-cmake` and `vcpkg-cmake-config`, links statically (`vcpkg_check_linkage(ONLY_STATIC_LIBRARY)`), fixes up the config and installs the copyright from `LICENSE`. `cpp/CMakeLists.txt` host branch: alias `packbin::packbin`, install and export rules (only when packbin is the top-level project), `packbin-config.cmake` and a version file when `PACKBIN_VERSION` is set; the ESP-IDF branch is byte-identical. New `publish-vcpkg.test.sh` (`publish-gate.test.sh --vcpkg`) builds a consumer through the port from a bare git registry with a real vcpkg (the runner's preinstalled one: no new pin) and compares its output with `fixtures/golden.hex`; outside CI a missing vcpkg prints NOT RUN (exit 0, last line `publish gate: no failures, NOT RUN: ...`), in CI it fails. Verified on this arm64 Mac (`arm64-osx`); the `x64-linux` build, the runner's vcpkg checkout and run time are proven only by the first CI run. Open: the tag-time guard `check_vcpkg` in the owner's `publish-check.py` does not assert the new port parts; port versions published before this change do not link (use the next version).
