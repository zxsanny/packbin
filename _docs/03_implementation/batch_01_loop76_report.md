# Batch Report

**Batch**: 1
**Tasks**: AZ-3329_probe_fixes, AZ-3330_timing_selftest_no_pipe, AZ-3331_rust_feature_set_tests, AZ-3332_docs_swift_docc_vcpkg_reason, AZ-3333_session_names
**Date**: 2026-10-27

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-3329_probe_fixes | Done | 3 edited (`fixtures/hostile/fuzz/csharp/PackbinProbe.csproj`, `EdgesText.cs`, `fixtures/hostile/fuzz/java/packbin/ProbeEdgesText.java`) | C# `edges` 64 PASS 0 FAIL exit 0; Java `edges` 65 PASS 0 FAIL exit 0; C# probe build 0 errors 0 warnings; ns20 probe build 0 errors | None |
| AZ-3330_timing_selftest_no_pipe | Done | 1 edited (`.github/workflows/publish-timing.selftest.sh`, 231 to 239 lines) | 15 to 0 `printf \| grep` pipelines; mutated copy fails with the `alpha` message and the captured output; unmutated exit 0; 20 runs under 8 CPU burners all exit 0 (worker); 20 of 20 under 12 CPU burners in the smoke trial (AC-4) | The cause of the one past flake is not proven (not reproduced in 3,000 trials) |
| AZ-3331_rust_feature_set_tests | Done | 26 edited (`rust/src/lib.rs`, 2 test modules of `session_core/`, 22 std-only files and `nostd_dict_tests.rs` of `rust/tests/`) | `cargo test --no-run`: 8 of 8 feature sets exit 0 (7 of 8 failed); `frame` set 26 passed 0 failed; default suite 809 passed 0 failed (HEAD 809) | `vec::Vec` dropped from the `sha256.rs` import (unused there) |
| AZ-3332_docs_swift_docc_vcpkg_reason | Done | 4 edited (`Packbin.md`, ADR-003, `05_cpp_package/description.md`, `08_swift_package/description.md`) | 10 of 10 frame types listed, members checked against the declarations; `os_random` is no longer a reason in the two docs | none |
| AZ-3333_session_names | Done | 4 renamed (2 C# test files, 2 fuzz probes), 6 readers edited | C# tests listed 4,220 before and 4,220 after; test project build 0 errors; both fuzz probes exit 0, 0 mismatches | The probes print no `PASS` lines; AC-2 reworded |

Parallel wave of five workers with disjoint write sets; the parent reviewed each diff, then made four small edits (below).

## Code Review Verdict: not run per batch

Owner preference (loop 16): one total review per loop, after feature-assess and before the total test run.

## CI-parity

No `Local pre-push checks` section exists in `_docs/04_deploy/ci_cd_pipeline.md`. The bar for any push is `scripts/loop-tests.sh --all` (the stages of `.github/workflows/test.yml`) at the closing commit; this commit is local and is not pushed before that run is green.

## Parent edits after the workers

- AZ-3332: dropped the worker's sentence "the line stays until a Windows build is tested" (an undecided policy); added the four frame error kinds (`tagMismatch`, `duplicate`, `tooOld`, `bufferFull`) to the DocC `PackbinError/Kind` list without claiming the hostile vectors name them; rewrote the stale clause of `08_swift_package/description.md` line 17.
- AZ-3330: converted the last `bash driver.sh | grep -q '::notice'` pipe to a captured variable and a here-string.
- AZ-3333: AC-2 and `acceptance_criteria.md` H7.2 reworded (the fuzz probes print no `PASS` lines; compare exit 0, 0 mismatches, the verdict line).

## Discovered during implementation

| Spec ref | Discovery | Proposed handling | Class |
|----------|-----------|-------------------|-------|
| AZ-3331 | `frame` and `text,ecc,frame` test builds print 4 dead-code warnings in `#[cfg(test)]` items only (`nostd/frame/mod.rs:363` `test_previous_is_zero` and `test_material`, `session_core/hkdf.rs:76` `hmac_sha256_of`, `session_core/pad.rs:89` `block_of`); the default build prints 1 (`session_core/counters.rs:18` `take`, module gated `cfg(all(test, feature = "std"))`). Their callers are std-only test files | not fixed in this loop (warnings only, CI runs no `-D warnings`); a cfg-only cleanup (`cfg(all(test, feature = "std"))`) that cannot move an embedded pin; candidate for a later loop (reviewer finding F1) | clear |
| AZ-3332 | DocC link resolution (`swift package generate-documentation`) was not run; the new links use the existing double-backtick form and point at public types | not run; the Swift suite runs at step 11 | clear |
| AZ-3333 | `EccTextTests` is already a Swift struct, so the C# class is `EccProtectedTextTests` | none | clear |
| AZ-3330 | the cause of the flake is unproven | the next failure prints the matched text | unclear |
