# vcpkg port declares its platforms and a 0.x version rule

**Task**: AZ-2232_vcpkg_supported_platforms_minor_version
**Name**: vcpkg port limited to Linux and macOS, `find_package` version rule "same minor" for 0.x
**Description**: The staged `vcpkg.json` declares `"supports": "linux | osx"`, so vcpkg refuses the port on any other triplet with a clear message; the installed package version file uses `SameMinorVersion` while the version is below 1, so an installed 0.x does not satisfy a request for another 0.x minor. The README names the supported platforms.
**Complexity**: 2 points
**Dependencies**: AZ-2098_vcpkg_port_builds (done; the port, the consumer check and the CMake install rules this task changes)
**Component**: vcpkg
**Tracker**: AZ-2232
**Epic**: AZ-2069

## Problem

Loop 16 feature assessment, Q3 (owner option A) and Q10 (owner option B), answered by the owner on 2026-10-06 ("take all recommendations, implement everything now").

- README line 27 says "CMake 3.16+ or vcpkg on desktop and server", and the C++ install row (README line 409) names no platform. The staged port (`stage_vcpkg_port` in `.github/workflows/publish-embedded.sh`) writes a `vcpkg.json` with no `supports` field, so vcpkg offers the port on every triplet.
- Windows is unproven. The C++ core has been compiled only with gcc on Linux and clang on macOS (the `ring` job, the container suite, the vcpkg consumer check on `arm64-osx`). `cpp/src/os_random.cpp` picks `getrandom` only under `__linux__` and `arc4random_buf` only under `__APPLE__`; every other platform, Windows included, takes the last branch, which opens `/dev/urandom` with `fopen` and returns `false` when that fails. Reading the code, that branch compiles but `os_random` cannot return random bytes on Windows (`PackSession::start` with `os_random` would fail at run time). The ticket text says `getrandom` "does not build there"; the code says the `getrandom` branch is never compiled there and the fallback fails at run time. I could not build for Windows (macOS host, no Windows triplet toolchain), so "does not work on Windows" is read from the code, not run.
- `cpp/CMakeLists.txt` (host branch, line 46-47) writes the installed `packbin-config-version.cmake` with `write_basic_package_version_file(... COMPATIBILITY SameMajorVersion)`. Probe at HEAD (committed 2eb9875), observed with CMake 4.1.1 on macOS: configure `cpp/` with `-DPACKBIN_VERSION=0.9.0`, build, `cmake --install`, then `find_package(packbin <request> CONFIG)` in an empty project:

  | request | found |
  |---------|-------|
  | `0.2` | yes (version 0.9.0) |
  | `0.9` | yes |
  | `0.9.0` | yes |
  | `0.1.0` | yes |
  | `0.9.1` | no |
  | `1.0` | no |

  So an installed 0.9 satisfies a request for 0.2, and this project's upgrade notes break things between 0.x minors. vcpkg pins exact versions, so the rule matters for a manual `cmake --install` and for a project that asks for a version range.
- The consumer check `.github/workflows/publish-vcpkg.test.sh` builds the port at `vcpkg_version="0.1.0"` and asks for `find_package(packbin 0.1 ...)`. With the version rule "same major" no request can fail against 0.1.0 except a newer one (0.1.0 is older than any other 0.x minor request except 0.0), so the check cannot detect a loose rule. At HEAD the gate runs green: `PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)" VCPKG_ROOT=<vcpkg checkout> bash .github/workflows/publish-gate.test.sh --vcpkg` prints `vcpkg port checks passed` in 10 s (arm64-osx, vcpkg tool 2026-09-26-51bf87c).

## Outcome

- `ports/packbin/vcpkg.json` carries `"supports": "linux | osx"`. `vcpkg install packbin` on any other triplet fails before any build with vcpkg's own message, which names the expression and the triplet.
- The installed `packbin-config-version.cmake` uses `SameMinorVersion` while `PACKBIN_VERSION` is below 1 and `SameMajorVersion` from 1.0 on. An installed 0.9.x answers a request for 0.9 and for nothing else.
- The README says the vcpkg port and `add_subdirectory` are for Linux and macOS and that Windows is not supported; ADR-003 says the same in its Consequences.
- Nothing else changes: the target `packbin::packbin`, the install layout, wire bytes, the ESP-IDF branch and the embedded targets.

## Scope

### Included
- `cpp/CMakeLists.txt` host branch, the `write_basic_package_version_file` call (lines 44-49): `SameMinorVersion` when `PACKBIN_VERSION VERSION_LESS 1`, `SameMajorVersion` otherwise.
- `stage_vcpkg_port` in `.github/workflows/publish-embedded.sh`: one `"supports": "linux | osx"` line in the written `vcpkg.json`.
- `.github/workflows/publish-vcpkg.test.sh`: the `supports` assertion, the unsupported-triplet check, the version-rule checks, and `vcpkg_version` raised to `0.9.0` (see AC-3).
- Docs, done by the docs step of the loop and not by the code implementer: README line 27 and the C++ install row (line 409), and the ADR-003 Consequences wording (a "Negative" bullet: the port is for Linux and macOS only).

### Excluded
- Proving Windows (a `windows-latest` MSVC job and a real random source for `os_random`): Q3 option B, only when Windows is wanted.
- Any change to `src/os_random.cpp` or to the C++ API.
- Versions already pushed to the registry (a pushed port version stays; ports of 0.1.x keep no `supports` line and no `SameMinorVersion`).
- The PlatformIO, Arduino and ESP-IDF packages (embedded targets; they do not go through vcpkg).
- `PACKBIN_OS_RANDOM` as a vcpkg feature (AZ-2098 flagged it out of scope).

## Acceptance Criteria

**AC-1: The staged port declares its platforms**
Given the port staged by `publish-registries.sh` into a bare git registry (version `0.9.0`, as `vcpkg_stage_registry` does)
When `ports/packbin/vcpkg.json` is read back with `git show vcpkg:ports/packbin/vcpkg.json`
Then the field `supports` is exactly `linux | osx`. The check is the manifest block of `vcpkg_port_checks` in `publish-vcpkg.test.sh`; with `supports` removed from `stage_vcpkg_port` the gate fails with `vcpkg.json supports is None, not 'linux | osx'` and `FAIL: ... port metadata` (observed on a scratch copy at HEAD plus this change).

**AC-2: vcpkg refuses an unsupported triplet and accepts the supported ones**
Given the AC-1 registry, and a manifest project that depends on `packbin` with the git registry of `vcpkg_consumer_check`
When `vcpkg install --triplet x64-windows` is run in it
Then it exits 1 and prints `packbin is only supported on 'linux | osx', which does not match x64-windows.` (the sentence continues with vcpkg's `--allow-unsupported` hint), before any compiler is detected. The same message names `arm64-android` and `x64-uwp` (observed). For `x64-linux` and `x64-osx` the output holds no `only supported` text: vcpkg starts to build `packbin` and the run fails later (`building packbin:x64-linux failed with: BUILD_FAILED`, observed) only because this macOS host has no compiler for those triplets; the supported host triplet builds in AC-3. So the check asserts the refusal message for `x64-windows` and the absence of `only supported` for `x64-linux`. The check is a new function `vcpkg_supports_check` in `publish-vcpkg.test.sh`, called from `vcpkg_checks`; it needs the vcpkg tool and prints `NOT RUN` without it, as the consumer check does. Observed on `arm64-osx`; the Linux runner is proven by its first CI run.

**AC-3: A 0.x minor does not satisfy another minor through the port**
Given the port staged at version `0.9.0` (`vcpkg_version` in `publish-vcpkg.test.sh` becomes `0.9.0`) and installed by the consumer of `vcpkg_consumer_check`
When that consumer asks `find_package(packbin 0.9 CONFIG REQUIRED)` (it already asks `${vcpkg_version%.*}`) and a second project of the same manifest asks `find_package(packbin 0.2 CONFIG)`
Then the first configures, builds and prints the golden hex `4001000065cd1d00a3e1110100`; the second finds nothing (`packbin_FOUND` false). The check lives in `vcpkg_consumer_check`; with `SameMajorVersion` restored the gate fails with `AZ-2232 AC-3 a request for another 0.x minor was satisfied by the installed port` (observed). Port version `0.1.0` cannot hold this check, because 0.1.0 is older than every 0.x request but 0.0; that is why the test version moves to `0.9.0`.

**AC-4: The version rule, without vcpkg**
Given `cpp/` configured with `-DPACKBIN_VERSION=<v>` and installed with `cmake --install` to a prefix
When an empty CMake project calls `find_package(packbin <request> CONFIG)` with `CMAKE_PREFIX_PATH` on that prefix
Then, observed at HEAD plus the change (CMake 4.1.1):

| installed | found | not found |
|-----------|-------|-----------|
| `0.9.0` | `0.9`, `0.9.0` | `0.1`, `0.2`, `0.10`, `0.1.0`, `0.9.1`, `0`, `1.0` |
| `0.10.2` | `0.10` | `0.1`, `0.2`, `0.9`, `0.9.0`, `1.0` |
| `1.4.0` | `1.0`, `1.2`, `1.4` | `1.5`, `2.0`, `0.9` |

The check is a new function `vcpkg_version_rule_check` in `publish-vcpkg.test.sh`, called from `vcpkg_checks`; it needs only cmake (a missing cmake is the same `NOT RUN` as the add_subdirectory check). It configures and builds once, installs to two prefixes by reconfiguring `-DPACKBIN_VERSION` (about 2 s on this host), and asks the requests of the first two rows plus `1.2`, `1.5`, `0.9` for the `1.4.0` row. With HEAD's `SameMajorVersion` the requests `0.2` and `0.1.0` against `0.9.0` are found, so the check fails.

**AC-5: Docs state the platforms**
Given the README and ADR-003 after this task
When a C++ user reads line 27 and the install row
Then both name Linux and macOS as the vcpkg and `add_subdirectory` platforms and say Windows is not supported (and why: not built or tested there); ADR-003 Consequences carries the same sentence. No script holds this check: it is prose, read in the docs review.

**AC-6: Nothing else moves**
Given the AZ-2098 acceptance criteria and the embedded targets
When the whole gate runs (`bash .github/workflows/publish-gate.test.sh --vcpkg`, then the full `publish-gate.test.sh`)
Then AZ-2098 AC-1 to AC-5 still pass (consumer golden hex, `add_subdirectory` with both target names, port metadata, idempotent re-stage), lines 1-14 of `cpp/CMakeLists.txt` (the `ESP_PLATFORM` branch) are byte-identical, and `make -C cpp test` is unchanged. The checks are the existing AZ-2098 checks in `publish-vcpkg.test.sh`; the ESP-IDF branch is confirmed by the diff of the change.

## Non-Functional Requirements

**Compatibility**
- Supported: any vcpkg triplet whose platform expression matches `linux | osx` (observed: `x64-linux`, `x64-osx`, `arm64-osx` pass the platform check; `x64-windows`, `arm64-android`, `x64-uwp` do not). `--allow-unsupported` still lets a user try.
- Versions from 1.0 keep "same major"; the CMake package files of a 1.x install behave as at HEAD (AC-4 row 3).

**Reliability**
- A check that did not run is `NOT RUN` in the gate's last line, never a pass (AZ-2098 rule): `vcpkg_supports_check` and the consumer part of AC-3 need the vcpkg tool, `vcpkg_version_rule_check` needs cmake. On GitHub Actions a missing tool fails.

**Performance**
- The added checks cost under 10 s on this host: one extra configure for the second consumer project (binary cache hit), one rejected `vcpkg install`, two reconfigures.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | staged `vcpkg.json` `supports` | `linux \| osx`; red with the line removed |
| AC-4 | version file matrix for installs 0.9.0, 0.10.2 (optional), 1.4.0 | found and not-found sets as in the table |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | bare registry with the port, real vcpkg | `vcpkg install --triplet x64-windows` | exit 1, message names `linux \| osx` and `x64-windows` | Compatibility |
| AC-3 | port `0.9.0`, real vcpkg, consumer project | request `0.9` builds and prints the golden hex; request `0.2` finds nothing | as stated | Compatibility |
| AC-6 | existing gate | `publish-gate.test.sh --vcpkg` | `vcpkg port checks passed` | Reliability |

## Constraints

- ADR-001: no shared code; `cpp/CMakeLists.txt` and the staging script are the only product files, no C++ source or header changes.
- Files at or under 500 lines: `publish-vcpkg.test.sh` is 311 lines today; the three additions stay under about 80 lines. `cpp/CMakeLists.txt` stays far below.
- Error kind and label of existing errors unchanged (decision C15); no wire change.
- Canonical path only: the checks use the local bare registry and never push; no tokens (AZ-2098 constraint).
- `bash.md` rules for the scripts; temp dirs through `mktemp` and `trap`; the new checks follow the `vcpkg_run` pattern (output to a log, to stderr on failure).
- The wire bytes in the ACs come from the runs listed above; the implementer re-derives them from a real run on the arm64 Mac (`PACKBIN_CXX_SYSROOT`, `VCPKG_ROOT`).

## Risks & Mitigation

**Risk 1: A request that names only the major (`find_package(packbin 0 CONFIG)`) no longer finds a 0.x install**
- *Risk*: observed with `SameMinorVersion`: installed 0.9.0 is not found for the request `0` (CMake has no minor to compare). Under `SameMajorVersion` it was found. A project that wrote `0` gets a configure error.
- *Mitigation*: that request means "any 0.x", which is the loose rule this task removes; the README install row shows `find_package(packbin CONFIG REQUIRED)` with no version, which is unchanged.

**Risk 2: `linux | osx` excludes triplets that may work (FreeBSD, iOS)**
- *Risk*: a user on another Unix triplet gets the refusal.
- *Mitigation*: `--allow-unsupported`; widen the expression when a platform is proven. Embedded targets use PlatformIO, Arduino and ESP-IDF, not vcpkg.

**Risk 3: The unsupported-triplet message differs on the Linux runner or in another vcpkg version**
- *Risk*: the text was read on `arm64-osx` with vcpkg 2026-09-26.
- *Mitigation*: the check greps the stable part (`only supported on 'linux | osx'`) and the triplet name; the first CI run is the proof for Linux.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The ticket says `os_random.cpp` (`getrandom`) does not build on Windows. The code: `getrandom` is compiled only under `__linux__`; Windows takes the `/dev/urandom` `fopen` fallback, which compiles in principle and fails at run time. Windows was not built here, so the reason in the README stays "not built or tested there" | implementer / docs | open | Low |
| A request with only a major (`0`) is rejected by `SameMinorVersion` for a 0.x install (observed). Confirm that this is wanted | owner | open | Low |
| The unsupported-triplet message was observed on an `arm64-osx` host only; Linux runner proof comes from the first CI run | CI | accepted-risk | Low |
| Moving the test port version to `0.9.0` changes only `publish-vcpkg.test.sh`; the real tag version comes from the release tag | implementer | open | Low |

## Owner decision (2026-10-06)

DECIDED, take all recommendations (feature assessment of loop 16, "implement everything now"): Q3 option A, declare the port Linux and macOS only in the staged `vcpkg.json` and say so in the README, Windows only when it is wanted (option B stays a later job); Q10 option B, "same minor" while the major version is 0. The open concerns above are resolved by this section except the two Low rows that name the implementer or owner.

## Loop 16 result (2026-10-06)

Done in loop 16 (round 2), with AZ-2240 in one worker. AC-5 (docs) is in the README patch, the C++ description and `tests.md`, ADR-003 and `module-layout.md`.

What shipped:
- `cpp/CMakeLists.txt` (host branch, +6/-1): `PACKBIN_VERSION_RULE` is `SameMinorVersion` while `PACKBIN_VERSION VERSION_LESS 1`, else `SameMajorVersion`. Lines 1-15 are identical to HEAD (md5).
- `.github/workflows/publish-embedded.sh` (+1): `stage_vcpkg_port` writes `"supports": "linux | osx"`.
- `.github/workflows/publish-vcpkg.test.sh` (311 to 490 lines, with AZ-2240): `supports` in the manifest key loop of `vcpkg_port_checks` (AC-1); `vcpkg_supports_check` (AC-2: `vcpkg install --dry-run` refuses `x64-windows` with exit 1 and `packbin is only supported on 'linux | osx', which does not match x64-windows.`; `x64-linux` exits 0 and plans `packbin:x64-linux@0.9.0`); a second consumer project that asks `find_package(packbin 0.2 CONFIG)` and must print `packbin 0.2 not found` (AC-3; `vcpkg_version` is now 0.9.0); `vcpkg_version_rule_check` (AC-4, cmake only: installs `cpp/` as 0.9.0, 0.10.2 and 1.4.0). Two helpers, `vcpkg_manifest_project` and `vcpkg_configure`, are shared.

Evidence (re-derived from real runs): CMake 4.1.1 gives the AC-4 matrix exactly: 0.9.0 is found for `0.9` and `0.9.0` and refused for `0.1`, `0.2`, `0.10`, `0.1.0`, `0.9.1`, `0` and `1.0`; 0.10.2 is found for `0.10`; 1.4.0 is found for `1.0`, `1.2`, `1.4` and refused for `1.5`, `2.0`, `0.9`. HEAD found 0.9.0 for `0.1`, `0.2`, `0.1.0` and `0`. The staged port is refused on `x64-windows`, `arm64-ios`, `x64-mingw-dynamic`, `arm64-android`, `x64-uwp` and planned on `x64-linux`, `arm64-linux`, `x64-linux-release`, `x64-osx`, `arm64-osx` (vcpkg 2026-09-26). Mutants killed: `supports` removed, set to `linux`, `linux | osx | windows`, `!windows`; `SameMajorVersion` restored (AC-3 and eight AC-4 rows); `SameMinorVersion` unconditional (the 1.4.0 rows); threshold `VERSION_LESS 2`. `bash publish-gate.test.sh --vcpkg` passes; `make test` in a scratch copy of `cpp/`: all tests passed.

Review findings (harness review, PASS_WITH_WARNINGS, six Low):
- F2: ranges that span minors are refused too (`0.9...0.10`, `0.9...<1.0`, `0.8...0.9`; `0.9...0.9.5` and `0.9...<0.10` are found), which HEAD found. This is CMake's own `SameMinor` template: documented in the README patch (version-rule paragraph) and the C++ description, not changed in code.
- F6: the `--vcpkg` gate takes 19 to 21 s against 9.7 s at HEAD; the spec asked for added checks under 10 s: exceeded by about 1 s, accepted and noted here.

Open: the tag-time guard does not assert `supports` (the spec excludes it; a one-line `need(manifest.get("supports") == "linux | osx", ...)` plus a mutant case in `vcpkg_guard_checks` would add it; open Low, shared with AZ-2240). Only the Ubuntu runner proves: the runner vcpkg's refusal wording (the check greps the stable sentence), the native `x64-linux` plan, the second consumer under the vcpkg toolchain, the version-rule check on the runner's cmake. `vcpkg_supports_check` and `vcpkg_version_rule_check` print `NOT RUN` without vcpkg or cmake. For the owner: README line 27 (the C++ bullet) is in the uncommitted block, so the patch left it; the suggested sentence is "C++: C++17; CMake 3.16+ or vcpkg on Linux and macOS (Windows is not supported: the package is not built or tested there); 32-bit microcontrollers (ESP32, RP2040, nRF52, STM32) through PlatformIO, Arduino and ESP-IDF 5.1+.".
