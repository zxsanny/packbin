# Acceptance criteria — loop 73, Rust wipes through one volatile helper

Inherited and unchanged: the frame-mode criteria of loop 69 (Rust frame mode, AZ-3192 / AZ-3203) and the stream session criteria of the Rust package, which this loop must keep green. The criteria below are new.

## AC-1 One wipe helper

- **AC-1.1**: `rust/src/session_core` holds exactly 1 wipe function. It overwrites each element of a mutable slice with zero through `core::ptr::write_volatile`, then calls `core::sync::atomic::compiler_fence(Ordering::SeqCst)`. It has exactly 1 `unsafe` block, with a `SAFETY:` comment saying why the write is sound.
- **AC-1.2**: `rust/src/nostd/frame/mod.rs` keeps `#![forbid(unsafe_code)]`; `rust/src` has 0 `unsafe` outside the helper.
- **AC-1.3**: `grep -rn black_box rust/src` finds 0 wipes; the only hits left are `timing_support.rs` and the constant-time compare in `nostd/frame/mod.rs`.
- **AC-1.4**: a unit test fills a 64-byte buffer with 0xA5 and a 16-word buffer with 0xA5A5A5A5, calls the helper on each and finds 64 and 16 zeros.

## AC-2 HKDF temporaries

- **AC-2.1**: before every return of `hmac_sha256` (`session_core/hkdf.rs`), `block` (64 B), `digest` (32 B) and the `state` (8 words) and `block` (64 B) of both SHA-256 hashers are overwritten through the helper.
- **AC-2.2**: before every return of `derive`, `prk` (32 B) and `previous` (32 B) are overwritten through the helper: the normal end and both early returns (counter past 255 blocks, `get_mut` miss).
- **AC-2.3**: RFC 5869 case 1 (`rfc5869_case_1`) and the HKDF and HMAC rows of `fixtures/crypto/vectors.txt` pass with output byte for byte as at HEAD.

## AC-3 Stream pad temporaries

- **AC-3.1**: `block` (`session_core/pad.rs`) overwrites `state` (16 words) and `work` (16 words) through the helper before it returns.
- **AC-3.2**: `xor` and `xor_with_nonce` overwrite the 64-byte keystream `pad` through the helper before they return.
- **AC-3.3**: the RFC 8439 block vector (`rfc8439_block_vector`) and the ChaCha20 rows of `fixtures/crypto/vectors.txt` pass unchanged.

## AC-4 Existing wipes move to the helper

- **AC-4.1**: these 9 wipes call the helper and nothing else clears them: `Pads::new` `ipad` and `opad`, `Pads::wipe` (`session_core/hmac.rs`); `split_keys` `both` (`session_core/mod.rs`); `PackSession::open` `seed` (`session/mod.rs`); `wipe` (`nostd/session.rs`); `fill` `mac`, the key slot `wipe` and `SlotKeys::wipe` (`nostd/frame/mod.rs`); `MacKey::derive` `derived` (`nostd/frame/mac.rs`).
- **AC-4.2**: the task record holds a code-read list of every Rust temporary that held key bytes, key-derived words, a pad block or keystream, each with its wipe line or the reason it has none (by-value moves, L73-1; the `compress` schedule, owner decision).

## AC-5 Embedded figures

- **AC-5.1**: `docker compose -f docker-compose.test.yml run --rm rust-embedded` passes on both rows. `base`, `text` and `ecc` keep their HEAD figures exactly (M4F 15,060 / 27,156 / 18,692 B flash; M33F 15,132 / 27,268 / 18,764 B; stack 456 / 2,736 / 744 B), since none of them links `session_core`.
- **AC-5.2**: `session` and `frame` grow by at most 384 B of flash and 32 B of stack each on each row. The M4F `frame` set stays at or under the owner's bound of 20,480 B (316 B of room at HEAD); a figure above it stops the loop for the owner.
- **AC-5.3**: the M33F pins of `session` and `frame` in `rust/embedded/limits-m33f.txt` are set to the measured figures, and `_docs/AGENT_GOTCHAS.md` has a line saying what the bytes bought.

## AC-6 Speed

- **AC-6.1**: `pad::xor` over 1 MiB in a release build takes at most 1.15 times as long as the same build of a HEAD copy, on this Mac, the smallest of 3 runs each, both run in the same session. The figures go in the task record.
- **AC-6.2**: every existing Rust load-aware timing check passes (`timing_support.rs` helpers, no new fixed bound).

## AC-7 Bytes unchanged

- **AC-7.1**: all 27 rows of `fixtures/crypto/vectors.txt` and all 157 rows of `fixtures/frame/vectors.txt` pass in Rust (`docker compose -f docker-compose.test.yml run --rm rust`, the full CI step list).
- **AC-7.2**: the stream session vectors and the cross-language session match (`scripts/loop-tests.sh` stages `rust` and `ring`) pass unchanged, and the embedded golden packet decodes on both rows.

## AC-8 Docs

- **AC-8.1**: the Rust package description (`_docs/02_document/components/04_rust_package/description.md`) names the wipe helper, what it guarantees (the writes are not removed by the compiler) and what it does not (copies left by moves, L73-1; the SHA-256 round schedule). The contract `pack-session.md` keeps "best effort".

## Out of scope

A `Drop` wipe for the std `PackSession` keys (the managed stream sessions have none either); the `zeroize` crate; wiping the SHA-256 round schedule; a replay window per key slot (F69-2); frame mode with `std`; frame mode in Python, TypeScript, Go and C++; a cross-language frame ring; any change to C#, Java or Swift.
