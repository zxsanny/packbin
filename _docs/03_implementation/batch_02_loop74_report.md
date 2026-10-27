# Batch Report

**Batch**: 2
**Tasks**: AZ-3284_rust_stream_removal, AZ-3285_swift_stream_removal_and_names, AZ-3286_cpp_stream_removal_crypto, AZ-3287_go_stream_removal_crypto
**Date**: 2026-10-27

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-3284_rust_stream_removal | Done | 6 deleted, 1 renamed test, about 25 edited (`rust/`, `rust/embedded/`, `fixtures/hostile/fuzz/rust/`) | CI step list in the `rust` service: 912 passed, 0 failed, 1 ignored (104 s) | None |
| AZ-3285_swift_stream_removal_and_names | Done | 4 deleted, about 20 edited (`swift/`, `fixtures/hostile/fuzz/swift/`); README Swift hunks by the parent | `swift test` 427 tests (HEAD 461; -34 session tests), release build with strict flags 0 warnings, speed run 6 passed | None |
| AZ-3286_cpp_stream_removal_crypto | Done | 7 deleted, 3 new (`src/core/crypto.hpp`, `crypto.cpp`, `tests/core/crypto_vectors_host_tests.cpp`), about 20 edited (`cpp/`, `cpp/embedded/`, 3 CI scripts, `fixtures/hostile/fuzz/cpp/`) | host `make -C cpp test` and `gcc:16` both exit 0, 0 warnings; embedded arm 0 failed; vcpkg port checks no failures | ESP-IDF stage not run locally (image not on the host) |
| AZ-3287_go_stream_removal_crypto | Done | 7 deleted, 2 new (`crypto.go`, `crypto_vectors_test.go`), 12 edited (`go/`, `fixtures/hostile/fuzz/go/`) | `golang:1.27`: gofmt 0, vet 0, `go test -race` 325 passed, 0 failed, 1 skipped (HEAD 355); 60 s fuzz PASS | None |

Parallel wave of four workers with disjoint write sets. The Rust and C++ workers lost their API connection once (`ENOTFOUND`) and were resumed with their context; the Rust edits were already complete, the C++ worker finished the CI scripts and probes after the resume.

## Code Review Verdict: not run per batch

Owner preference (loop 16): one total review per loop (step 14).

## AC evidence

| Task / AC | Evidence |
|-----------|----------|
| AZ-3284 AC-1 | `git grep -nE 'PackSession\|feature = "session"\|split_keys\|SEED_SIZE\|NONCE_SIZE' rust fixtures/hostile/fuzz/rust`: 0 hits; `cargo build --features session`: "the package 'packbin' does not contain this feature: session" |
| AZ-3284 AC-2 | `build` default, `--no-default-features`, `--no-default-features --features frame`, `--no-default-features --features text,ecc,frame`, `--features frame,text,ecc`: 0 warnings, 0 errors; `frame_vectors_tests` 2/2 in each set, lib `frame_` 12/12 (157 rows) |
| AZ-3284 AC-3 | default `cargo test`: the 5 crypto tests cover 27 of 27 rows (`session_core` gated `any(feature = "frame", all(test, feature = "std"))`) |
| AZ-3284 AC-4 | `rust/embedded/run.sh host` exit 0, no `session` set, every figure equals HEAD (table below); `checks.test.sh` "all checks passed", its missing-line mutant now drops `frame` |
| AZ-3284 AC-5 | `docker compose -f docker-compose.test.yml run --rm -T rust`: 11 steps, 912 passed, 0 failed, 1 ignored; warnings as at HEAD |
| AZ-3285 AC-1 | `git grep -nE 'PackSession\|sessionKeys\|MessageContext' swift Package.swift fixtures/hostile/fuzz/swift`: 0 hits |
| AZ-3285 AC-2 | `FrameVectorTests` (157 rows) and `CryptoVectorTests` (`ran == 27`) pass |
| AZ-3285 AC-3 | `scripts/frame/readme-examples.sh` on the joined tree: PASS C#, Java, Swift; `ReadmeExampleTests` + `FrameReadmeExampleTests` 5/5 (worker, scratch copy with the README hunks the parent then applied) |
| AZ-3285 AC-4 | `swift test` 427 tests; `swift build -c release --build-tests -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete`: 0 warnings; speed run 6 tests in 3 suites pass |
| AZ-3286 AC-1 | `git grep -nE 'PackSession\|session\.hpp\|session\.cpp\|os_random\|RandomFn' cpp .github fixtures/hostile/fuzz/cpp`: 0 hits |
| AZ-3286 AC-2 | `crypto_vectors_host_tests.cpp`: 27 of 27 rows (SHA and HMAC also fed in 37-byte pieces), 6 of 6 one-digit copies fail on their own row; six broken copies of `crypto.cpp` (round constant, rotate, HKDF counter, opad, two removed limits) each fail it |
| AZ-3286 AC-3 | `cpp-m4f` 7,712 / 540 B, `cpp-m33f` 25,720 / 724 B (pins), core data+bss 0 B, AVR Uno 15,402 B flash / 196 B RAM (as HEAD); vector runners 268 asserted, 268 run (HEAD 290; `session_tests.cpp` had 22) |
| AZ-3286 AC-4 | host and `gcc:16` `make test` exit 0, 0 warnings; plain CMake build and install with `-Werror`; `publish-gate.test.sh --vcpkg` no failures (supports and consumer checks NOT RUN: no vcpkg on this Mac); `publish-position.sh cpp` prints the golden bytes; `ring-lib.test.sh` passed. ESP-IDF stage NOT RUN locally (the `espressif/idf` image is a multi-GB download); the example source compiled and ran with host clang and passed `gcc:16 -fsyntax-only` |
| AZ-3287 AC-1 | `go doc -all . \| grep -ic session`: 31 at HEAD, 0 after; `git grep -n PackSession go fixtures/hostile/fuzz/go`: 0 hits |
| AZ-3287 AC-2 | `crypto_vectors_test.go`: 27 of 27 rows, 6 of 6 mutant copies caught; a scratch `SetCounter` off-by-one fails the 7 rows with counter 1 or more |
| AZ-3287 AC-3 | `golang:1.27`: `gofmt -l` 0 files, `go vet` 0, `go test -race` 325 passed (3,001 with subtests), `TestAC7SpeedRoundTrips` PASS, 60 s `FuzzUnpack` PASS (1,407,872 execs), `go mod tidy -diff` none, `go_deps` only `golang.org/x/crypto` |

## Embedded figures (Rust 1.98.1, QEMU), unchanged

| Set | M4F flash / stack | M33F flash / stack |
|-----|-------------------|--------------------|
| base | 15,060 / 456 | 15,132 / 456 |
| text | 27,156 / 2,736 | 27,268 / 2,736 |
| ecc | 18,692 / 744 | 18,764 / 744 |
| frame | 20,332 / 1,728 (bound 20,480) | 20,404 / 1,728 (pin) |

C++: the largest single core frame (informational) dropped from 528 B (`PackSession::open`) to 328 B (`Sha256::compress`).

## Mixed-file test counts (before / after)

| File | Before | After |
|------|--------|-------|
| Rust `ecc_session_dispatch_tests.rs` to `ecc_dispatch_tests.rs` | 16 | 8 |
| Rust `times_shapes_tests.rs` | 11 | 9 |
| Rust `frame_hostile_tests.rs` | 8 | 6 (the 2 removed were `session`-gated) |
| Swift `EccSchemeTests.swift` | 23 | 16 |
| Swift `EccDispatchOrderTests.swift` | 2 | 2 (no-scheme test now on clear unpack) |
| Swift `ReadmeExampleTests.swift` | 5 | 4 |
| C++ `dict_order_host_tests.cpp` (tests / expects) | 5 / 19 | 5 / 13 |
| C++ `no_ecc_tests.cpp` | 3 / 9 | 2 / 6 |
| C++ `host_tests.cpp` | 3 / 3 | 4 / 6 (received the core OS scan) |
| Go `ecc_scheme_test.go` | 20 | 12 |
| Go `nil_scheme_test.go` (subtests) | 8 | 6 |
| Go `example_test.go` | 6 | 5 |

## Union check (parent)

- `git grep -n -E 'PackSession|MessageContext|split_keys|os_random|session\.hpp'` over rust, swift, cpp, go, `.github`, `scripts`, `fixtures/hostile/fuzz`: only the TypeScript probes (AZ-3288, batch 3).
- `scripts/frame/readme-examples.sh`: PASS C#, Java, Swift.
- Ring on the joined tree: `STAGE ring: PASS (77s)`, language pairs passed, `ring-ecc: 64 pairs, 45440 rows, mismatched rows: 0` (load 3 to 9). CI-parity: PASS (each package's CI suite by the workers: the `rust` compose service, `golang:1.27`, `gcc:16` and host `make`, `swift test` and the release build; the ring here)

## Discovered during implementation

| # | Spec ref | Finding | Proposed handling | Clarity |
|---|----------|---------|-------------------|---------|
| 1 | AZ-3284 AC-2 | `cargo test --no-default-features --features frame` over all targets does not compile at HEAD (18 errors) or now (13): std-only integration test files have no `#![cfg(feature = "std")]`; the suite runs `--test frame_vectors_tests` for that set | pre-existing; the AC is met by the suite's frame runs; candidate | clear |
| 2 | AZ-3284 | `rust/embedded` `stream_hits` guarded names that cannot exist any more | deleted with its tests; AC-1 grep covers it | clear |
| 3 | AZ-3285 | The DocC catalog's "whole API" list never named the frame types (pre-existing) | AZ-3291 adds them or drops the claim | unclear |
| 4 | AZ-3285 | `ChaCha20.swift` error reasons start "session: " | left: frame mode is a session too | clear |
| 5 | AZ-3286, AZ-3287 | New refusals in the kept crypto: HKDF over 8,160 bytes (the old C++ code wrapped its block counter), a ChaCha20 stream past block counter 2^32 - 1; the C++ XOR loop now counts remaining bytes (the old offset step could wrap on AVR's 16-bit `size_t`) | kept, tested | clear |
| 6 | AZ-3286 | The C++ crypto header is in `src/core` (not installed) | the frame port (AZ-3292) moves it to `include/` only if a public template needs it | unclear |
| 7 | AZ-3286 | ESP-IDF example stage not run locally | CI covers it; NOT RUN here | clear |
| 8 | all | Each package's "duplicate type before parity mix" check (AZ-2704 AC-3) moved to the clear unpack path | as batch 1 | clear |

## README hunks for AZ-3291 (parent)

- Applied in this batch: the "Encrypted session / Swift" block; `MessageContext` to `MsgContext` in the Swift frame example.
- Rust (with `rust/tests/nostd_docs_tests.rs`, which asserts the "`session`" row): l.364 features list, l.369 std row, l.373 `session` row becomes a `frame` row, l.408 the heap-free session paragraph, l.881 ECC row, l.2004.
- C++: l.492 "(ESP-IDF with the hardware RNG)", l.494 the `RandomFn` / `os_random` sentences, l.516-519 the four `PackSession` migration rows, l.885 ECC row.
- Go: l.28 `x/crypto` "(the session only)", l.737 the concurrency sentence, l.883 ECC row, l.1091-1133 "Encrypted session / Go", l.2168.
- `_docs/AGENT_GOTCHAS.md` l.18: the largest single C++ core frame is now `Sha256::compress` at 328 B.
