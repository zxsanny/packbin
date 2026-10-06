# Code Review Report

**Batch**: 4 (loop 16): AZ-2098 (vcpkg port builds, vendored sources) | **Date**: 2026-10-06 | **Mode**: Full, one read-only reviewer (CMake, port staging, the consumer check; scratch copies, a real vcpkg), then a fix pass | **Verdict**: PASS_WITH_WARNINGS (no Critical or High)

## Findings and disposition

| # | Severity | Category | File:Line | Title | Disposition |
|---|----------|----------|-----------|-------|-------------|
| F1 | Medium | Spec-Gap (test) | `publish-vcpkg.test.sh` | The top-level install guard of `cpp/CMakeLists.txt` had no test (mutant `if(TRUE)` left the gate green) | FIXED: the AC-3 parent installs its own files and the check asserts no `lib/libpackbin.a` and no `lib/cmake/packbin` |
| F2 | Medium | Spec-Gap | `publish-vcpkg.test.sh`, `publish-gate.test.sh` | A skipped vcpkg check exits 0 and the last line began with "publish gate tests passed" (an old smoke script, `_docs/loops/loop13/smoke13.md`, matched that phrase and would record PASS with AC-1 and AC-2 never executed) | FIXED (wording): an incomplete run no longer prints a "passed" line; exit 0 outside CI and exit 1 in CI are unchanged (the instruction was: a skip is NOT RUN, never a pass) |
| F3 | Low | Spec-Gap (test) | `publish-vcpkg.test.sh` | The consumer used an unversioned `find_package`; the version file and the `debug/include` removal were untested | FIXED: `find_package(packbin 0.1 CONFIG REQUIRED)` and an assertion that `debug/include` is absent; both mutants now fail |
| F4 | Low | Architecture | `cpp/CMakeLists.txt` | `SameMajorVersion` is loose for a 0.x library: an installed 0.x satisfies a request for an older or equal 0.x | Open for the owner (one word, `SameMinorVersion`); documented; vcpkg pins the exact version, so it matters only for manual `cmake --install` flows |
| F5 | Low | Spec-Gap | README | The install row was still the old text | Closed by the docs patch (row, `vcpkg-configuration.json` example, upgrade sentence) |
| F6 | Low | Maintainability | `publish-vcpkg.test.sh`, `cpp/CMakeLists.txt` | (a) an empty baseline on a vcpkg root without `.git`; (b) the guard blocks a parent that exports a static library linking `packbin::packbin` privately | (a) FIXED (clear early failure); (b) documented only |

## Existing tests changed

`publish-gate.test.sh`: only the `not_run` variable, the source line, the `--vcpkg` branch, the `vcpkg_checks` call and the last-line suffix were added; no check weakened.

## Evidence

Real vcpkg (arm64-osx): consumer prints the golden hex; `find_package(packbin 0.1)` accepted, `0.2` and `1.0` rejected; the ESP-IDF branch and the first 15 lines of `cpp/CMakeLists.txt` are byte-identical to HEAD (md5); the port tree hash is identical across umask 022/077/027, another checkout path, `TZ`/`LC_ALL` and mtimes set to 2000 (all 20 files mode 100644); re-staging adds no commit; staging 0.2.3 on a clone of the real `vcpkg` branch (14 versions) builds and leaves the 0.2.2 entry unchanged; old-layout versions stay reachable (immutability). The runner's vcpkg was verified from the actions/runner-images sources: a full git clone at `/usr/local/share/vcpkg`, `chmod 0777 -R`, so `buildtrees` and `downloads` are writable and `HEAD` serves as the builtin baseline; Ubuntu 24.04 ships CMake 3.31.6, Ninja 1.13.2 and g++ 13.3.

Mutants rejected: HEAD `CMakeLists.txt`, HEAD staging script, portfile with a literal copyright, a timestamp file in the port, the `vcpkg-cmake-config` dependency dropped, no `INSTALL_INTERFACE` include dir, headers not installed; after the fix pass also the guard `if(TRUE)`, no `PACKBIN_VERSION` and no `debug/include` removal.

## Only the Ubuntu runner proves

gcc 13.3 compiling `src/core/*.cpp` and `os_random.cpp` (`getrandom`) on x64-linux in debug and release with `-fPIC`; the cold wall time of vcpkg building the host ports plus packbin; whether vcpkg picks the system CMake and Ninja or downloads its own; GNU `cp -R` and `sed` in the scripts; the ESP-IDF stage (the parent re-runs it); the tag-time push to the real `vcpkg` branch.
