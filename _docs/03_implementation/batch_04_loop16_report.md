# Batch Report

**Batch**: 4 (loop 16)
**Tasks**: AZ-2098 (vcpkg port builds, vendored sources)
**Date**: 2026-10-06

One worker (C++ CMake, the port staging, the consumer check), a review, a fix pass found by the parent (the new checks did not honor the Mac host recipe), parent-run checks with a real vcpkg.

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2098_vcpkg_port_builds | Done (AC-1 to AC-5; owner decision: vendored sources). Verified with a real vcpkg on this arm64 Mac (`arm64-osx`); `x64-linux` and the Ubuntu runner are not proven here | `cpp/CMakeLists.txt` (host branch: alias, install and export rules, version file), `.github/workflows/publish-embedded.sh` (`stage_vcpkg_port`: the functions moved there from `publish-registries.sh` in AZ-2096), new `.github/workflows/publish-vcpkg.test.sh`, `publish-gate.test.sh` (+16/-1, sources it), ADR-003 (+6) | `publish-vcpkg.test.sh` runs the real `publish-registries.sh` into a bare repo and the real vcpkg; `bash publish-gate.test.sh --vcpkg` | tag-time guard `check_vcpkg` in the owner's `publish-check.py` does not assert the new port parts |

## Code Review Verdict: see `_docs/03_implementation/reviews/batch_04_loop16_review.md`

## Test Suite

- `--vcpkg` run with a real vcpkg (`vcpkg-macos` 2026-09-26, shallow clone of microsoft/vcpkg commit `434307d…` under the session scratchpad, 73 MB plus the 12.4 MB tool, vcpkg's own CMake 4.4.3 and ninja downloads): "vcpkg port checks passed" in 9.8 s warm. The consumer packs the golden position row and prints `4001000065cd1d00a3e1110100`; `add_subdirectory(cpp)` builds under both target names; port metadata, `copyright` equal to `LICENSE`, `git-tree` pointers and idempotent re-staging pass.
- Four mutants rejected by the intended check (HEAD staging, HEAD `CMakeLists.txt`, portfile without `vcpkg_install_copyright`, a timestamp file in the port).
- Without a vcpkg tool outside CI: `vcpkg consumer check NOT RUN: no vcpkg tool`, exit 0, last line `publish gate tests passed; NOT RUN: ...`; with `GITHUB_ACTIONS=true` a missing vcpkg fails the job.
- The check honors `PACKBIN_CXX_SYSROOT` (the Mac recipe) for its cmake builds and the vcpkg consumer; unset on the runner. The parent found the gap (the AC-3 build failed on this Mac without the recipe) and had it fixed.
- C++ host suite unchanged (no C++ source touched).

CI-parity: the full gate, the C++ Docker suite and the ESP stage (`cpp/CMakeLists.txt` is also the ESP-IDF component's file) are re-run in step 11 from a clean export of the committed tree.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | The tag-time guard `check_vcpkg` in `publish-check.py` (the owner's file) does not assert the new port parts (`CMakeLists.txt`, `LICENSE`, host dependencies); the gate checks them only at test time | AZ-2098 AC-4 | add three `need(...)` lines in a TypeScript-style hunk after the owner commits their C# work, or with the owner's approval now | clear |
| 2 | Real consumers need a `default-registry` entry with a microsoft/vcpkg baseline next to the git registry (vcpkg refuses a git registry without it) | AZ-2098 | README example added in the docs pass | clear |
| 3 | `write_basic_package_version_file` uses `SameMajorVersion`: an installed 0.x satisfies a request for an older or equal 0.x (verified with CMake 4.1.1 on an installed 0.3.0: 0.1.0 and 0.3.0 succeed, 0.4 and 1.0 fail; an installed 0.1.0 fails a request for 0.2), so `find_package` does not flag a breaking change between two 0.x versions | AZ-2098 | `SameMinorVersion` is one word if the owner wants stricter 0.x behavior | unclear (low) |
| 4 | vcpkg on the runner may download its own cmake and ninja; the cold time of the `scaffold` step is unmeasured | AZ-2098 NFR | measure on the first green run | unclear |
| 5 | Port versions already in the registry stay unbuildable (immutable); users move to the next version | AZ-2098 | upgrade note | clear |
| 6 | Only the Ubuntu runner proves: `VCPKG_INSTALLATION_ROOT` is a writable git checkout with a usable `HEAD` as the builtin baseline; the `x64-linux` build in debug and release; gcc 13 on the runner compiling the library and `getrandom`; the tag-time push to the real `vcpkg` branch | AZ-2098 | first CI run | clear |

## Commit

`[AZ-2098] Build the vcpkg port and check a consumer` (≤72 chars). Body: one line + `Loop: 16`.

## Next: steps 10.5 (feature assessment), 11 (run tests), 13 (docs delta), 14 (security), 17 (retrospective), then loop close
