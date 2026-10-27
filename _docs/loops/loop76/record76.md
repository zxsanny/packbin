# Autodev loop record — loop 76

loop: 76
branch: dev
plan_artifact: _docs/loops/loop76/plan76.md
tasks_shipped: [AZ-3329_probe_fixes, AZ-3330_timing_selftest_no_pipe, AZ-3331_rust_feature_set_tests, AZ-3332_docs_swift_docc_vcpkg_reason, AZ-3333_session_names, AZ-3334_py_ts_edges_key_order]
decisions:
  - owner (2026-10-27): the loop is the hygiene loop, "Accept all recommended": items 1 to 5 and 7, item 6 investigate-first, the AVR runtime check out
  - owner (2026-10-27, assessment round 1): swap the NFC/NFD keys in the Python and TypeScript `edges` probes too (AZ-3334); run each of the six non-default Rust feature sets once at test time and record the counts
  - agent: epic AZ-2645, the one earlier hygiene tasks (AZ-3163, AZ-3164, AZ-3256) used
  - agent: the vcpkg `supports: linux | osx` line stays; ADR-003 and the C++ description lose the stale `os_random` reason (dropping the line is an owner decision and needs a Windows build)
  - agent: the Rust gates are inner `#![cfg(feature = "std")]` attributes (the repo's pattern, 14 files already), not `required-features` entries in `Cargo.toml`
  - agent: the C# classes are `TopRangeTests` and `EccProtectedTextTests` (`EccTextTests` is already a Swift struct); the fuzz probes are `fuzz_ecc.py` and `fuzz_ecc.ts`
  - agent: `vec::Vec` dropped from the `sha256.rs` test import (unused there)
measurements:
  - probes on a50e750 changed three of the seven descriptions: the C# probe crashed (exit 134) on `ns20/Program.cs`; the Rust failure is in 22 std-only test files and the library test modules (7 of 8 feature sets failed); the NFC/NFD FAIL is a probe key-order error (proved on scratch copies)
  - C# `edges` 64 PASS 0 FAIL (63 PASS and 1 FAIL after the csproj fix alone); Java `edges` 65 PASS 0 FAIL (64 and 1); Python 86 PASS and TypeScript 87 PASS, 0 FAIL, the NFC/NFD info line from `refused` to `accepted as two keys`
  - Rust: `cargo test --no-run` 8 of 8 sets exit 0 (7 failed); at test time none 19, alloc 20, text 28, ecc 29, text+ecc 38, text+ecc+frame 45 passed, 0 failed; frame set 26; default suite 809 passed (HEAD 809)
  - timing selftest: 15 to 0 `printf | grep` pipes (plus the last early-exit reader), 231 to 240 lines; the old pattern failed 0 of 3,000 trials, idle and under 12 burners (cause unproven); the new file passes 20 of 20 under 12 burners
  - C# lists 4,220 tests before and after the rename; the specs say "listed" (the run reports a different figure)
  - step 11 `scripts/loop-tests.sh --all` at 48412cd, host load 5 to 33: typescript 34 s, csharp 62 s, go 182 s, python 156 s, java 16 s, rust 142 s, cpp 76 s, scaffold 284 s, swift 431 s, cpp-embedded-arm 19 s, rust-embedded 10 s, ring 59 s, ac10 5 s, publish-gate 299 s (8 shares PASS, 1,725 s summed, tree equal before and after): 14 passed, 0 failed, 1,021 s; NOT RUN on this host: the vcpkg supports check and the vcpkg consumer check (no vcpkg tool)
  - smoke `smoke76.sh` 10 of 10 at 48412cd (the trial failed 2 steps on a script bug, fixed)
review: "independent read-only agent over a50e750..f102eba (feature assessment round 1 CLARIFY, 2 unclear angles answered by the owner; round 2 COMPLETE after AZ-3334; assessment76.md): 0 Critical, High or Medium, 5 Low and 4 Info; the Lows fixed or recorded; no per-batch code review (owner preference)"
retro: not due (last: loop 74; next due after loop 79)
leftovers:
  - owner (unchanged): CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; whether to drop the M4F row; the release notes of the next 0.x; meshbell renames its Rust `Session` to `FrameSession`
  - owner: whether the vcpkg port should drop `supports: linux | osx` (needs a Windows build and test first)
  - candidates: a cross-language frame ring (`fixtures/frame/ring-cases.txt`); a public-key pairing step; the AVR runtime check of `chacha20_xor`; a cfg-only cleanup of the 4 dead-code warnings in `cfg(test)` items of the `frame` test builds (`nostd/frame/mod.rs`, `session_core/hkdf.rs`, `pad.rs`, `counters.rs`); the comment in `swift/Sources/Packbin/PackbinError.swift:4-5` that calls every raw value a shared hostile-vector term (false for the four frame kinds); DocC link resolution not run; `--all-features` Rust set not in the matrix
  - open: the cause of the `publish-timing.selftest.sh` broken-pipe flake (L75-2) is unproven; Go intermittent failure L74-3 did not show in step 11
  - Jira: AZ-3329..AZ-3334 In Testing (read back); earlier AZ-3280..AZ-3295 and AZ-3322 In Testing; epic AZ-2645
lessons:
  - Probe a handoff candidate on HEAD before writing its spec: 3 of 7 descriptions were wrong or incomplete, and one wrong key order also sat in two probes the handoff did not list.
  - A std-only Rust test file needs an inner `#![cfg(feature = "std")]`; CI hid its absence because the suite names each no-std target with `--test`.
smoke: PASS
smoke_artifact: _docs/loops/loop76/smoke76.md
assessment_artifact: _docs/loops/loop76/assessment76.md
loop_end_merge: main
