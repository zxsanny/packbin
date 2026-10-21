# Security review — the heap-free Rust API, session and raw memo (loop 53, AZ-2756, AZ-2757)

**Date**: 2026-10-21 · **Scope**: `git diff df7ac02..HEAD -- rust/src rust/embedded` (`nostd::Session`, `session_core`, the walk split, the raw memo, `present.rs`) · **Verdict**: PASS (no Critical, High or Medium; one Low found by the review and fixed in this loop; four observations)

## Trust boundary

`Session::unpack` and `unpack_repair` read untrusted bytes from the radio in firmware that cannot catch a panic, with keys derived from a seed the node holds. New since loop 52: the pad, hash and key derivation on caller buffers (`session_core/`), a session type that keeps secret state, a text memo in the caller's scratch words, and a stricter presence rule in `pack`.

## Surfaces

| Input | Bound | Evidence |
|-------|-------|----------|
| Seed (32 B) and nonce (16 B) | any other length is `BadValue` before any key is made; a refused nonce leaves the seed in place | `nostd_session_tests::ac3_a_seed_of_the_wrong_size_is_refused`, `ac3_a_nonce_of_the_wrong_size_*` |
| Payload bytes | the pad is a byte-wise XOR over the caller's slice; the packet is then read by the same walk as `unpack` (every read through `Reader::take`) | `ac3_random_bytes_of_every_length_never_panic`, the hostile corpus under every case scheme |
| Protected payload | detect-only or repair with the limit checked before the position moves; repair writes only after its result is verified (loop 52) | `protected::ac3_*` |
| Pack failure | the written bytes are zeroed and the send position is unused; found by the review: a `bits`/`packed` field could leave earlier values in the buffer past the zeroed length (L53-1, fixed) | `ac3_a_refused_bits_value_leaves_no_plaintext_anywhere_in_the_buffer` |
| Raw text memo | offset and length live in the caller's scratch; a pack clears them first, the memo is believed only when the bytes inside the written output equal the string, so a stale or forged memo can only select the raw form for a text whose raw bytes are really there | `nostd_raw_repeat_tests::a_memo_left_in_the_scratch_is_not_believed` |

No count sets an allocation (there is none) or a recursion depth beyond the scheme's nesting.

## Panic and heap freedom

- The deny list (`unwrap`, `expect`, `panic`, indexing, unchecked arithmetic) is clean on `nostd` in six feature combinations (`cargo clippy`).
- The linked Cortex-M4F images of the `base`, `text`, `ecc` and `session` sets have no heap and no panic symbol. The check found a real defect on the way: `chunks_mut(64)` and `chunks_exact` link `panic_const_div_by_zero` and `panic_fmt` at opt-level z, so the pad, hash and HKDF read bytes by index with `get` and a 16-word message window instead (the agent gotcha now names every `chunks*`).
- The `session` set runs a round trip on the device (seed, nonce, seal on one node, open on the peer).

## Cryptographic notes

- The hash, HKDF-SHA-256 and the ChaCha20 block are checked against the RFC vectors (`session_core` unit tests: RFC 5869 case 1, RFC 8439 block, NIST SHA-256 vectors including a multi-block message and pieces) and, end to end, against the `std` `PackSession` bytes for parity 0, 2, 4, 8 and 32 and both directions.
- No branch or table index depends on a key byte (add, rotate, xor only), so the pad is constant time on a core without a data cache; the parity check works on public data.
- `Session` is not `Clone`, wipes the seed when a session opens, and wipes the seed and both keys on drop (best effort). The send key is borrowed, not copied, in `pack` (review finding, fixed).

## Findings

| id | severity | finding | remediation |
|----|----------|---------|-------------|
| L53-1 | Low (fixed) | A refused `bits` or `packed` value left the values before it in the caller's buffer, past the length that failure zeroes: plaintext of the row stayed in `out` after `Session::pack` returned an error | `small()` checks every value before it writes; test added |

## Observations (not counted)

- **O1**: the pad is not a MAC. A flipped bit flips the same plaintext bit; only the type number, the structure of the packet and the parity (which an attacker can recompute) refuse a change. Frame mode with a tag is excluded from the epic (meshbell PB-04) and the same holds for `PackSession`.
- **O2**: a packet that reaches the pad moves the receive position, a refused one included, so an attacker who injects an extra packet shifts the position and the next real packet is read at the wrong index; there is no resync. This is the `std` and C++ behaviour (documented), and the replay window of PB-04 is where it is handled.
- **O3**: `rust/src/session_core/` sits outside `nostd/`, so the clippy deny list does not cover it (it uses `+= 1` on counters bounded by 64 and `i - 15` on an index of at least 16). The embedded link check covers it for panic symbols. Moving the lints to the crate root of that module is the cheap fix.
- **O4**: nonce reuse under one seed derives the same keys and so the same pad for the same packet index (two-time pad). The library cannot detect it (the nonce is the caller's); the rustdoc of `Session` says so.
- **O5 (L52-1, still open)**: a repair stays in the buffer when the field read then fails (documented).
