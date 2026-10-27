# Batch Report

**Batch**: 3
**Tasks**: AZ-3288_typescript_stream_removal_crypto, AZ-3289_rust_frame_names, AZ-3290_java_frame_names (and the parent's README, contract and Swift `Freshness` parts of AZ-3291)
**Date**: 2026-10-27

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-3288_typescript_stream_removal_crypto | Done | 3 deleted, 2 new (`src/crypto.ts`, `tests/crypto-vectors.test.ts`), 9 edited (`typescript/`, `fixtures/hostile/fuzz/typescript/`) | `npm test` 2,446 passed, 0 failed (HEAD 2,442); `tsc -p tsconfig.build.json --noEmit` exit 0 | None |
| AZ-3289_rust_frame_names | Done | 1 deleted (`nostd/session.rs`; `FrameSession` now in `nostd/frame/mod.rs`), 9 edited | `run-suite.sh rust` on the host (Rust 1.98) exit 0, 0 failed, 1 ignored | None |
| AZ-3290_java_frame_names | Done | 5 new top-level types, 2 main and 10 test files edited | `java/test.sh` exit 0, 9,725 checks, api-check PASS | None |

Parallel wave of three workers; the parent wrote the README, the contract 3.0.0, `rust/tests/nostd_docs_tests.rs`, `scripts/frame/readme-examples.sh` (Rust entry) and moved the Swift `Freshness` to a top-level enum (a D1 gap the Java worker found).

## Code Review Verdict: not run per batch

Owner preference (loop 16): one total review per loop (step 14).

## AC evidence

| Task / AC | Evidence |
|-----------|----------|
| AZ-3288 AC-1 | built `dist/index.js` exports 30 names, none session, pad, crypto, chacha, hkdf, hmac or sha; `git grep -n PackSession typescript fixtures/hostile/fuzz/typescript`: 0 hits |
| AZ-3288 AC-2 | `tests/crypto-vectors.test.ts` 45 tests: 27 of 27 rows, 6 mutant copies each failing on its own row, 10 refusals, an entry-exports check; 4 broken copies of `crypto.ts` each fail 9 to 16 tests |
| AZ-3288 AC-3 | `npm test` 2,446 passed; `dependencies` only `@noble/hashes` 2.4.0; `publish-gate.test.sh --npm` (offline) "npm dist checks passed" |
| AZ-3289 AC-1 | `cargo doc --no-deps --features frame`: `FrameSession`, `FrameConfig`, `FrameDirection`, `FrameDirections`, `FrameSlot`, `FrameOpened`, `MsgContext`, `ReplayWindow`, `Freshness`, `MacKey` public; 0 of `Session`, `Direction`, `Directions`, `Slot`, `Opened`, `MsgCtx`; no aliases |
| AZ-3289 AC-2 | 157 rows (137 seal/open/mac/replay rows + 20 key rows); `rust/embedded/run.sh host` exit 0, every SIZE line equal (0 B moved), `rust-mutants` PASS |
| AZ-3289 AC-3 | the `nostd::frame` module doc test is now the README Rust example byte for byte; `scripts/frame/readme-examples.sh` gained a Rust entry: "PASS Rust: the README example equals the doc test of rust/src/nostd/frame/mod.rs" |
| AZ-3290 AC-1 | `javap -public`: `FrameSession`, `FrameDirection`, `FrameSlot`, `FrameSealed`, `FrameOpened`, `Freshness`, `ReplayWindow`, `MsgContext`, `MacKey`; 0 of `FrameSession$Slot`, `$Opened`, `$Sealed`, `ReplayWindow$Freshness`, int `UP`/`DOWN`/`GROUP` |
| AZ-3290 AC-2 | "frame vectors: 157 rows checked, 0 mismatches" (the test now prints the count); crypto 27 rows |
| AZ-3290 AC-3 | seal and open with `GROUP` on a session loaded with `UP` and `DOWN`: `BadValue`; a null direction: `BadValue` (seal, open) and null (load) |
| AZ-3290 AC-4 | `readme-examples.sh`: PASS Java |
| Swift `Freshness` (parent) | `swift build --build-tests` complete; `swift test --filter 'Frame\|Replay\|CryptoVector'`: 39 tests in 9 suites passed |
| AZ-3291 (parent part) | `rust/tests/nostd_docs_tests.rs` 1 passed (now asks for "`frame`"); `readme-examples.sh`: PASS C#, Java, Swift, Rust |

## Mixed-file test counts (before / after)

| File | Before | After |
|------|--------|-------|
| TypeScript `ecc-scheme.test.ts` | 16 | 9 |
| TypeScript `ecc-dispatch-order.test.ts` | 8 | 4 |
| TypeScript `int-range.test.ts` | 12 | 11 |
| TypeScript `hostile.test.ts` | 97 | 96 |
| Java `FrameMacRefusalsTest` (checks) | 195 | 194 (direction 0 and 4 refusals became null-direction refusals) |

## Union check (parent)

- `git grep` for `PackSession`, `MessageContext`, `MsgCtx`, the old Java nested names, `ReplayWindow.Freshness`, `nostd::Session` over every package, `.github`, `scripts`, the hostile probes and README: only the README history note, the README removal row and intro sentence, and `python/tests/test_star_import.py` (the absence guard).
- Ring on the joined tree: `STAGE ring: PASS (66s)`, language pairs passed, `ring-ecc: 64 pairs, 45440 rows, mismatched rows: 0`. CI-parity: PASS (`npm test` and the build type check, `run-suite.sh rust`, `java/test.sh`, the Swift build and frame tests, the ring here)

## Discovered during implementation

| # | Spec ref | Finding | Proposed handling | Clarity |
|---|----------|---------|-------------------|---------|
| 1 | AZ-3290, D1 | Swift nested `Freshness` inside `ReplayWindow` while C#, Java and Rust have it at top level | fixed by the parent (top-level enum, 2 tests) | clear |
| 2 | AZ-3290, D1 | Java has no `FrameConfig` or `FrameDirections`: `load(key, epoch, tagLen, FrameDirection...)` (varargs, not `EnumSet`: `Set.of` needs Android API 30) | kept; README and contract say so | clear |
| 3 | AZ-3289 AC-3 | `readme-examples.sh` never checked the Rust example | Rust entry added; the module doc test is the example | clear |
| 4 | AZ-3290 | `java/api-check.sh` is the Android API 26 check, not a public list | AC checked with `javap -public` | clear |
| 5 | AZ-3288 | `dist/crypto.js` ships in the npm tarball but is unreachable (`exports` names only `.`); `@noble/hashes` installs unused until AZ-3295 | D2 accepted | clear |
| 6 | AZ-3288 | `ecc.ts` `checkSize` is exported with no outside caller | left for the frame seal (AZ-3295) | clear |
| 7 | AZ-3288 | No key wipe in `crypto.ts` (JavaScript cannot guarantee one) | the frame port documents best effort | clear |
