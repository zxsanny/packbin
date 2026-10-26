# Batch Report

**Batch**: 1
**Tasks**: AZ-3275_rust_key_wipes
**Date**: 2026-10-26

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-3275_rust_key_wipes | Done | 11 source files (1 new), 1 limits file | 972 / 972 pass (1 ignored) | None |

Parent alone (one component; every change touches `session_core`).

Source: `rust/src/session_core/wipe.rs` (new), `hkdf.rs`, `sha256.rs`, `pad.rs`, `hmac.rs`, `mod.rs`; `rust/src/session/mod.rs`; `rust/src/nostd/session.rs`; `rust/src/nostd/frame/mod.rs`, `mac.rs`. Limits: `rust/embedded/limits-m33f.txt`. Docs: Rust description, `module-layout.md`, `AGENT_GOTCHAS.md`.

## Code Review Verdict: not run per batch

Owner preference: one total review per loop. The loop plan runs one independent read-only security review of the diff (step 14).

## AC evidence

| AC | Evidence |
|----|----------|
| AC-1.1, 1.2 | `session_core/wipe.rs` `wipe<T: Copy + Default>`: `write_volatile` per element, then `compiler_fence(SeqCst)`; one `unsafe` block with a `SAFETY:` comment. `grep -rn unsafe rust/src`: the helper, plus `#![forbid(unsafe_code)]` and a doc line in `nostd/frame/mod.rs` |
| AC-1.3 | `grep -rn black_box rust/src`: `timing_support.rs` (4 lines) and `nostd/frame/mod.rs:89` (constant-time compare); no wipe |
| AC-1.4 | `session_core::wipe::tests::wipe_zeroes_bytes_and_words` passes |
| AC-2 | `hmac_sha256` wipes `block`, `digest`, `inner`, `outer` (and the hash of a long key) before the tag is returned; `derive` has one exit (the two early returns became `break`) and wipes `prk` and `previous` there. `rfc5869_case_1`, `every_hkdf256_row_matches`, `every_hmac256_row_matches`, `every_sha256_row_matches` pass |
| AC-3 | `block` wipes `state` and `work`; `xor` and `xor_with_nonce` wipe `pad`. `rfc8439_block_vector`, `every_chacha_row_matches` pass |
| AC-4.1 | the 9 listed wipes call the helper (code-read list below); two more found (Discovered 1, 2) |
| AC-5 | `rust/embedded/run.sh host` on the final tree, exit 0, table below |
| AC-6.1 | bench below: ratio 1.044 |
| AC-6.2, AC-7 | `docker compose -f docker-compose.test.yml run --rm rust` (the full CI step list): 13 steps, 972 passed, 0 failed, 1 ignored, 95 s, exit 0 |

## Embedded figures (Rust 1.98.1, QEMU)

| Row | Set | HEAD flash / stack | This tree flash / stack | Change | Limit |
|-----|-----|--------------------|-------------------------|--------|-------|
| rust-m4f | base | 15,060 / 456 | 15,060 / 456 | 0 / 0 | 16,384 / 512 |
| rust-m4f | text | 27,156 / 2,736 | 27,156 / 2,736 | 0 / 0 | 27,964 / 2,898 |
| rust-m4f | ecc | 18,692 / 744 | 18,692 / 744 | 0 / 0 | 18,879 / 798 |
| rust-m4f | session | 18,812 / 1,528 | 18,828 / 1,504 | +16 / -24 | 19,325 / 1,924 |
| rust-m4f | frame | 20,164 / 1,752 | 20,316 / 1,728 | +152 / -24 | 20,480 / 1,991 |
| rust-m33f | base | 15,132 / 456 | 15,132 / 456 | 0 / 0 | pin |
| rust-m33f | text | 27,268 / 2,736 | 27,268 / 2,736 | 0 / 0 | pin |
| rust-m33f | ecc | 18,764 / 744 | 18,764 / 744 | 0 / 0 | pin |
| rust-m33f | session | 18,884 / 1,528 | 18,900 / 1,504 | +16 / -24 | re-pinned 18,900 / 1,504 |
| rust-m33f | frame | 20,236 / 1,752 | 20,388 / 1,728 | +152 / -24 | re-pinned 20,388 / 1,728 |

Log lines (final tree): `SIZE frame ram=0 B flash=20316 B (limit 20480) stack=1728 B (limit 1991) raw=1792 meter=64` (M4F), `SIZE frame ram=0 B flash=20388 B (limit 20388) stack=1728 B (limit 1728) raw=1792 meter=64` (M33F); `rust-m4f: PASS`, `rust-m33f: PASS`, `rust-mutants: PASS`, golden decoded on every image.

Helper inlined or not (Risk 1): the compiler keeps `wipe` out of line (two copies, `u8` and `u32`). A run with `#[inline(always)]` gave `session` 18,940 / 1,496 and `frame` 20,260 / 1,752 on the M4F row (+128 B and +96 B of flash against HEAD, stack -32 B and 0 B). Kept: the compiler's choice, 168 B in total against 224 B, 24 B less frame stack, no attribute. The M4F `frame` set keeps 164 B of flash under its owner bound (220 B with inlining).

## Speed (AC-6.1)

`pad::xor` over 1 MiB, 32 passes per run, release build, this Mac (load 5 to 10), HEAD copy (`git archive HEAD rust`) and this tree side by side in the scratchpad, interleaved:

| Run | HEAD ms per MiB | This tree ms per MiB |
|-----|-----------------|----------------------|
| 1 | 3.364 | 3.585 |
| 2 | 2.792 | 2.915 |
| 3 | 2.804 | 2.953 |
| smallest | 2.792 | 2.915 |

Ratio 2.915 / 2.792 = 1.044 (bound 1.15). The output check byte is equal on both sides.

## Code-read list (AC-4.2)

Every Rust temporary that holds key bytes, key-derived words, a pad block or keystream.

| Place | Temporary | Wipe or reason |
|-------|-----------|----------------|
| `session_core/hkdf.rs` `hmac_sha256` | `block` (key, then key XOR pads) | `wipe(&mut block)` |
| same | `hashed` (SHA-256 of a key longer than 64 B) | `wipe(&mut hashed)` |
| same | `inner` hasher (key-pad midstate, then inner hash) | `inner.wipe()` (state and block) |
| same | `digest` (inner hash) | `wipe(&mut digest)` |
| same | `outer` hasher | `outer.wipe()` |
| same | returned tag | moved to the caller (`prk`, `previous`), wiped there; by-value copies: L73-1 |
| `hkdf.rs` `derive` | `prk`, `previous` | `wipe` at the single exit (normal end and both early ways out) |
| `session_core/sha256.rs` `hash` | `sha` hasher | `sha.wipe()` |
| `sha256.rs` `compress` | round schedule `w`, working words | not wiped (owner, 2026-10-26; as the platform hashes of C#, Java, Swift) |
| `sha256.rs` `finish`, `midstate` | `out`, `state` results | returned by value: L73-1 |
| `session_core/pad.rs` `block` | `state` (key words 4 to 11), `work` | `wipe(&mut state)`, `wipe(&mut work)` |
| `pad.rs` `le_word` | `word` (4 key bytes) | not wiped: a register-sized value returned by value (L73-1); a volatile wipe would force it to the stack on every key word |
| `pad.rs` `xor`, `xor_with_nonce` | `pad` (keystream) | `wipe(&mut pad)` |
| `session_core/hmac.rs` `pad_block` | returned block | moved into `ipad` / `opad`: L73-1 |
| `hmac.rs` `Pads::new` | `ipad`, `opad` | `wipe(&mut ipad)`, `wipe(&mut opad)` |
| `hmac.rs` `Pads::wipe` | `inner`, `outer` states | `wipe` each |
| `hmac.rs` `Pads::mac` | `inner`, `outer` hashers, `digest` | not wiped: after `finish` they hold the inner hash and the full tag of the message, no key words (the key midstate is compressed away by `finish`); per-message cost. See Discovered 6 |
| `session_core/mod.rs` `split_keys` | `both` (64 B HKDF output) | `wipe(&mut both)` |
| same | `first`, `second` | returned by value into the session: L73-1 |
| `session/mod.rs` `PackSession::open` | `self.seed` | `wipe(seed)` in place, then `None` (Discovered 3) |
| `session/mod.rs` `PackSession` | `send`, `recv` | not wiped: no `Drop` (out of scope, as the managed stream sessions) |
| `session/mod.rs` `PackSession::load` | `owned` seed copy | moved into `Some(owned)`: L73-1 |
| `nostd/session.rs` `Session::open` | `self.seed` | `wipe(seed)` in place, then `None` (Discovered 2, 3) |
| `nostd/session.rs` `Drop` | seed, `keys.send`, `keys.recv` | `wipe` each |
| `nostd/frame/mod.rs` `DirKeys::fill` | `mac` (derived MAC key) | `wipe(&mut mac)` |
| `nostd/frame/mod.rs` `DirKeys::wipe` | `enc`, pads | `wipe(&mut self.enc)`, `self.pads.wipe()` |
| `nostd/frame/mod.rs` `SlotKeys::wipe` | every direction | `keys.wipe()` per direction (`epoch` is not secret) |
| `nostd/frame/mac.rs` `MacKey::derive` | `derived` | `wipe(&mut derived)` |
| `nostd/frame/mac.rs` `Drop` | pads | `self.pads.wipe()` |
| `nostd/frame/mac.rs` `tag`, `verify`; `seal.rs` `verify`, `seal` | `full` (32-byte HMAC) | not wiped: not key material, and the same bytes stay in the `outer` hasher of `Pads::mac` (Discovered 6) |

## Test Suite

- Total: 973 tests in 60 test binaries over the 13 steps of `run-suite.sh rust` (Rust 1.98 container, 95 s)
- Passed: 972
- Failed: 0
- Skipped: 1 (ignored, as at HEAD)
- Before that, on the host (Rust 1.79): `cargo check` with no features, `session`, `frame`, `frame,session,ecc`, and `--tests` with `std` and `frame,session,ecc,text`: no new warning (two old ones in `counters.rs` and `tests/nostd_support/hostile.rs`)

CI-parity: PASS — `docker compose -f docker-compose.test.yml run --rm rust` (the `rust` job's `run-suite.sh rust`) and `rust/embedded/run.sh host` (the `embedded-arm` job's Rust rows). CI runs no clippy or rustfmt; `rustfmt --check` on the changed files shows one diff, on a line this change did not touch (`pad.rs` `mixed`; the crate is not rustfmt-clean at HEAD).

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | `xor_with_nonce` already cleared its `pad` with a plain loop (a tenth existing wipe) | AZ-3275 AC-3.2 | moved to the helper | clear (AC-3.2 names the `pad` of `xor_with_nonce`) |
| 2 | the heap-free `Session::open` cleared its seed with a plain loop (an eleventh) | AZ-3275 AC-4 | moved to the helper | clear (owner: "every Rust wipe" through the helper) |
| 3 | both `open`s used `Option::take` on the seed: the bytes can stay in the session's own slot after `None` is written | AZ-3275 problem ("the wipe method is a hint") | the seed is wiped where it lives, then the slot is set to `None` | clear (the seed is key material the code can reach) |
| 4 | `sha256::hash` hashes an HMAC key longer than 64 B; its hasher held the key bytes | AZ-3275 AC-2.1 (hashers) | `hash` wipes its hasher | clear |
| 5 | `Sha256::finish` took the hasher by value, so its state could not be wiped where it lives | AZ-3275 AC-2.1 | `finish(&mut self)` (crate-private; every caller holds a `let mut`) | clear |
| 6 | full 32-byte HMAC outputs (`mac.rs` `tag` / `verify`, `seal.rs`) are not wiped; Java wipes its `full` arrays since loop 72 (AC-2.2 there) | none | left: not key material, and the same bytes stay in the outer hasher; wiping the hasher too costs every frame MAC | unclear (owner: a candidate for parity with Java) |
| 7 | the `.unwrap()` on the seed in the std `PackSession::open` | none | replaced by `let … else` on the lines this change rewrote | clear |

## Commit

`[AZ-3275] Wipe Rust key material through one volatile helper`. Body: one line + `Loop: 73`.

## Next Batch: All tasks complete
