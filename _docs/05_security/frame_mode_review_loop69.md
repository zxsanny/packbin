# Security review: frame mode of the session (Rust), loop 69

**Scope**: `rust/src/nostd/frame/{mod,seal,mac,window}.rs`, the frame additions in `rust/src/nostd/session.rs` and `error.rs`, `rust/src/session_core/{hmac,pad,sha256,hkdf}.rs`, against `_docs/02_document/contracts/library/pack-session.md` 2.0.0 (sections Configuration, Frame mode, MAC-only call) and ADR 008. Reference and vectors (`scripts/frame/framefmt.py`, `fixtures/frame/vectors.txt`) and the three test files were read for context only. Branch `dev`, HEAD `7ec05f9`. Read-only review; the only file written in the repository is this one.

**What was run**: `cargo test --offline --features frame --lib frame_` (10 passed); `cargo test --offline --features frame --test frame_vectors_tests` (2 passed); `cargo clippy --offline --no-default-features --features frame,session --lib` (no warnings); a release build with `--emit asm` of the library (aarch64 host) to read `MacKey::verify`; three throwaway programs in the session scratchpad (`exp/src/main.rs`, `exp/src/bin/resid.rs`, `exp/src/bin/wipe.rs`) that depend on the crate by path: protocol probes, a model check of `ReplayWindow` and a key-residue scan. Nothing else was run. A formal review on Cortex-M33 code generation was not done.

## Findings

| Id | Severity | Location | Issue | Impact | Recommended fix |
|----|----------|----------|-------|--------|-----------------|
| F69-1 | High (API and contract, not an implementation bug) | `seal.rs:170,186-192,224-226`; `mod.rs:30-37` (doc example); `pack-session.md:147` | The replay counter is a separate caller argument. Nothing binds it to `msg_id`, `ad` or the tag. Probe E1: a valid frame opened under counter 5, then the same bytes opened as counter 6 returned `Ok`; the same bytes under counter `u64::MAX` returned `Ok` and set `top = u64::MAX`; the next genuine frame (counter 7) was then `TooOld`. The doc example passes `7`, unrelated to `ctx` or `ad`, and no text tells the caller to derive it from authenticated bytes. | An attacker with a radio and one captured valid frame (not yet in the window, or the window empty after a reboot) bypasses replay protection (any counter is `Fresh` once) and can make every later frame from that sender `TooOld`, i.e. a permanent denial of service per sender until the window is reset. | State in the contract, the module doc and the README that the counter must be a function of authenticated bytes (inside `msg_id` or `ad`); make the example do so. Better: derive the counter inside `open_frame` from a caller-named authenticated field, or take it as a function of `ctx.msg_id`, so a free counter cannot be passed. |
| F69-2 | Medium | `seal.rs:201-212,224-226` | A frame that opens with the previous slot commits into the same caller window as current-slot frames, and the call reports the slot only after the commit. Probe E2: after `set_previous`, a captured old-epoch frame sent with its old counter 1 000 000 opened as `Previous` and moved the window top from 3 to 1 000 000. | If counters restart per epoch, one captured and not yet delivered old-epoch frame makes all new-epoch frames `TooOld`. The previous key never expires on its own (`mod.rs:326-341`), so this stays possible until the caller calls `clear_previous`. | Document that counters must be monotonic across epochs, or give each slot its own window (`open_frame` takes two windows, or returns the slot before a separate commit call). Tell callers to call `clear_previous` after a bounded time. |
| F69-3 | Low | `mod.rs:301-306` (`load_frame_in_place`) | Reload sets `has_previous = false` but does not wipe `previous`. Probe `wipe`: after `set_previous(key 0x5A)` then a reload, the old K_enc was still found in the 588-byte session; after `clear_previous` it was gone. The doc says reload "drops the previous slot". | A memory capture after a key rotation yields the retired key. The old current slot is overwritten correctly (probe C: 0 hits). | Add `state.previous = SlotKeys::empty();` before `fill`, as `clear_previous` does (`mod.rs:338-341`). |
| F69-4 | Low | `hkdf.rs:7-34,38-61`; `mod.rs:186-191`; `mac.rs:26-36`; `hmac.rs:30-41`; `mod.rs:314-318` | Best-effort wiping misses temporaries. The zeroing loops on `mac`, `derived`, `ipad`, `opad` have no `black_box`, unlike `wipe()`, and `hkdf::derive` never wipes `prk`, `previous` (= the derived key) or the 64-byte key block. Probe `resid` (release, aarch64): after `MacKey::derive` + drop, K_label was found once in dead stack; after `load_frame` + `seal_frame` + drop, K_enc, K_mac and `prk ^ 0x5c` were each found once. `load_frame` also moves the 588-byte session by value. The contract promises wiping only for the session and key objects. | Keys of a captured, running device survive on the stack until overwritten. Does not affect a device that is powered off. | Wipe `prk`, `previous` and the block in `hkdf.rs`, use `black_box` after each zeroing loop, prefer `load_frame_in_place`, and say in the contract that stack temporaries are not covered. |
| F69-5 | Low | `seal.rs:58,163-199` | `open_frame` has no body cap and does not check `clear_len <= 255`. Probe E3: a 10 000-byte body gives `TagMismatch` (after hashing the whole body, about 160 compressions per slot); `clear_len` 300 gives `TagMismatch` with no MAC run (`length_byte` fails inside `verify`, `seal.rs:46-58,96`), and the previous slot is tried the same way. The contract's 255 limit is stated for seal only; the Python reference behaves the same. | CPU grows with the body the caller hands in (the caller owns the read limit). A misuse (`clear_len` above 255) is reported as `TagMismatch`, which callers count as an attack indicator. | In open, return `TooLong` for `body.len() > MAX_BODY` and for `clear_len > 255` (contract and reference change first). |
| F69-6 | Info | `window.rs:30-32` | `ReplayWindow::from_parts` accepts any pair. `from_parts(100, 0)` is empty (all counters `Fresh`), and `from_parts(100, 0b10)` has bit 0 clear so `check(100)` is `Fresh` (probe E4). | A window restored from erased or corrupted flash silently turns replay protection off for the first frames. Not reachable by an attacker. | Document it; optionally reject `bits` with bit 0 clear unless `bits == 0`. |
| F69-7 | Info | `seal.rs:109,163` | `seal_frame` takes `&self`, is deterministic, and keeps no counter. Two threads, a retry that changes content, or a restart that repeats a `msg_id` reuses (key, nonce) with no protection from the library (the documented caller duty). | Two-time pad for both messages. | Already stated in bold in the contract and module doc; keep it in the README and in meshbell's design. |
| F69-8 | Info | contract, key design | Symmetric keys: any holder of a direction key, in particular the group key, can forge a frame for any source. `tag_len` is not part of M, so two sessions with different `tag_len` under one (key, epoch) share K_mac (no attack found, since the split point moves M, but the contract's "fixed per loaded key" must hold across devices). | Design property, not a defect. | None. |

No Critical findings. No finding in the cryptographic core (schedule, nonce, tag, order of checks, constant-time compare).

## Q1. Contract conformance: pass

Checked line by line against the contract and by the shared vectors (`every_seal_open_mac_and_replay_row_matches` passes).
- Salt `"packbin-frame" ‖ epoch` as 4 little-endian bytes: `mod.rs:69-78`. Info `[d] ‖ "enc"` and `[d] ‖ "mac"`, HKDF output 32 bytes, one block: `mod.rs:182-188`; `hkdf::derive(ikm, salt, info)` extracts with `HMAC(salt, ikm)` (`hkdf.rs:39`).
- Nonce `msg_id(8) ‖ (kind<<4 | d) ‖ epoch` as 3 bytes: `seal.rs:12-29`. `kind <= 15` is checked before use (`seal.rs:37`), so the shift loses no bits.
- ChaCha20 counter starts at 0: `pad.rs:90`. Longest body is 255 bytes, so 4 blocks and no counter wrap.
- M is `N ‖ len(ad) ‖ ad ‖ len(clear) ‖ clear ‖ ciphertext`: `seal.rs:58-62`. Tag is the first `tag_len` bytes: `seal.rs:146-148`, `seal.rs:97`. Body is `clear ‖ ciphertext ‖ tag`: `seal.rs:138,148`.
- Seal: argument checks (direction loaded, kind, ad length, body length, buffer) all run before the first write (`seal.rs:118-131`); the late-error path zeroes `out[..body_len]` (`seal.rs:149-152`; unreachable in practice). It reports `BufferFull` for that case.
- Open order: arguments (`BadValue`, `TooLong`, `ShortPacket`, `BufferFull`) at `seal.rs:173-185`; replay check at `186-192`, before any hashing; current slot then previous slot at `201-212`; decrypt only after a match at `213-223`; commit at `224-226`. `out` is written only at `220-223`, after the match. Probe E1 and the repository test `every_single_bit_flip_...` confirm no write and no window change on failure.
- `Slot`, `clear_len`, `plain_len` are returned as the contract says (`seal.rs:227-231`).
- Stream and frame calls are kept apart: `frame_state()` is `None` for a stream session (`mod.rs:320-322`); a stream `start` on a frame session finds no seed (`session.rs:124`); `load_frame_in_place` refuses a session with stream state (`mod.rs:297-300`).
- Epoch above 0xFFFFFF is `BadValue` at load, `set_previous` and `MacKey::derive` (`mod.rs:269-274`, `mac.rs:18`); `tag_len` not 4, 8, 16 is `BadValue` (`mod.rs:294`).
- MAC-only: `K_label` uses info `0x00 ‖ label`, label 1 to 32 bytes, `n` in {4, 8, 16, 32}, `MacKey` is 68 bytes (`mac.rs:17-66`).

## Q2. Constant time: pass

- `ct_eq` (`mod.rs:81-90`) returns early only on unequal lengths. Both lengths are public (`tag.len()` always equals `tag_len`, because the tag slice is `body[cipher_end..]` with `cipher_end = len - tag_len`). It folds every byte with `|=` and `black_box`es the result. In the release aarch64 assembly of `MacKey::verify` the loops are vectorised `eor`/`orr` accumulations; the only branches are on the length, none on a data value. Cortex-M33 code was not inspected.
- `MacKey::verify` (`mac.rs:60-66`) rejects a bad tag length before hashing (public) and then uses `ct_eq`.
- SHA-256 (`sha256.rs:23-78`) and ChaCha20 (`pad.rs:1-64`) index only with loop counters; no secret-dependent table index or branch. `K` is indexed by the round number.
- Current versus previous slot: a forged frame costs one MAC per loaded slot (`seal.rs:201-212`); a frame that opens with the previous key costs two. The only thing the time shows is which slot matched, which the result already says. A frame that fails both slots costs the same whichever byte differs.
- Replay check time (`window.rs:40-58`) depends on the public window state and the public counter; neither is secret (counters are on the air). It does let a forger learn which counters the receiver committed, but that is already visible from the traffic.

## Q3. Nonce and key misuse, domain separation: pass, with F69-7 and F69-8

- Every (key, nonce) pair is a function of `msg_id`, `kind`, direction and the epoch of the slot. No API path changes the nonce without the caller changing `msg_id`/`kind`: `seal_frame` uses only `state.current` (`seal.rs:132-136`), is stateless, and never uses the previous slot. Two sessions loaded from the same (key, epoch) produce identical keys by design; the uniqueness rule then covers both.
- Direction is in the key (info byte) and in the nonce byte; `Group` (3) never shares a key or nonce with `Up` (1) or `Down` (2). `kind` is in the nonce, so it separates keys' nonces and the tag.
- K_enc and K_mac use different info strings (`enc` and `mac`) from the same PRK, so they are independent; a K_mac is never used as a cipher key.
- MAC-only keys use info starting with `0x00`; frame keys start with 1 to 3; a label cannot change the first byte. No collision with frame keys is possible, and the label is the whole rest of the info (HKDF info length is part of the HMAC input, so `0x00 ‖ "enc"` and `[1] ‖ "enc"` differ in the first byte anyway).
- Ranges: epoch (above), `tag_len`, `kind > 15` (`seal.rs:37`), directions (`seal.rs:37` and `Directions` has a private field with only the 3 bits, `mod.rs:120-134`), `ad` above 255 (`seal.rs:40`), body above 255 (`seal.rs:123-128`).
- The 24-bit nonce epoch and the 32-bit salt epoch agree because the epoch is capped at 0xFFFFFF.

## Q4. Memory safety and panics: pass

- The module forbids `unsafe` (`mod.rs:46`); `nostd/mod.rs:54-59` denies unwrap, expect, panic, indexing and unchecked arithmetic, and clippy is clean for `frame,session`. In the frame code every length goes through `checked_*`, `saturating_*` or `get`.
- Attacker bytes reach only `body`, the counter and the caller's header. `clear_len = usize::MAX` gives `ShortPacket` (probe E3, `seal.rs:178-182`); `clear_len` 256 to body length gives `TagMismatch` (F69-5); the three slices are cut with `get` (`seal.rs:194-200`).
- `session_core` is outside the deny list; read by hand: indices are `get`-based, `filled` stays below 64, `i - 15` and `i - 2` run only for `i >= 16`, `i - 4` only in `4..=11`, byte counters wrap.
- `ReplayWindow`: `behind` is below 64 when shifted in `check`; `u32::try_from(...).unwrap_or(64)` turns any shift of 64 or more into `checked_shl/shr = None -> 0` (`window.rs:48-52,68-71,76-78`). Probe E4 checked shifts of 1, 63, 64, 65, 2^32 and about 2^63, and 120 000 random runs at bases 0, 1, 63, 64, `u64::MAX - 70`, `u64::MAX` against a set-based model: 0 mismatches.
- The ChaCha counter is a `u32` with `wrapping_add` and cannot pass 4 for a 255-byte body; for a larger body on open it wraps only after 256 GB.

## Q5. Replay window: logic pass, usage findings F69-1, F69-2, F69-6

- Edges match the contract: empty window (`bits == 0`) is `Fresh` for any counter; counter 0 commits as `top = 0, bits = 1` and then reads `Duplicate`; `top = u64::MAX` works because only `counter > top` shifts; shifts of 64 or more clear the bits (probe E4); `top - n >= 64` is `TooOld`; `commit` of a counter 64 or more behind is ignored (`window.rs:74-80`).
- A failed open never changes the window: the only call to `commit` is `seal.rs:224-226`, after the tag matched and the plaintext was written; `check` takes `&self`. Unauthenticated frames can therefore not advance or poison the window by themselves. They can when the counter is not authenticated (F69-1) or when an old-epoch frame is valid under the previous key (F69-2).
- `bits` always keeps bit 0 set after a `commit`, so `bits == 0` means empty only for a new or restored window.

## Q6. Secret hygiene: pass with F69-3, F69-4

- `SlotKeys::drop` zeroes every `enc` and calls `Pads::wipe` (`mod.rs:229-240`, `hmac.rs:56-61`), with `black_box`. Probe `wipe`: after `drop_in_place`, the session memory held 0 occurrences of K_enc; a reload over the current key leaves 0. `MacKey::drop` wipes its pads (`mac.rs:69-73`).
- `Session` is not `Clone` or `Copy` (`session.rs:43`, no derive); `DirKeys`, `SlotKeys`, `FrameState`, `Pads` derive nothing. `MacKey`'s `Debug` prints the epoch only (`mac.rs:75-81`). `FrameConfig`, `MsgCtx` and `Fault` hold no key material.
- The zeroed temporary `mac` in `DirKeys::fill` (`mod.rs:186-191`) is the HMAC key as bytes; the `Pads` hold the equivalent state anyway, so the temporary adds nothing beyond F69-4.
- Gaps: F69-3 (previous slot after reload) and F69-4 (stack temporaries and unprotected zeroing loops).

## Q7. API risks for callers

- The uniqueness rule for `msg_id` is caller-only and unenforceable (F69-7); it is stated in the contract (`pack-session.md:153-155`), in `mod.rs:11-14` and on `seal_frame`.
- The previous-slot window: no expiry, no limit on which epoch it holds, shared replay window (F69-2). Rotation procedure for callers: `load_frame_in_place` with the new key, `set_previous` with the old, reset or keep monotonic counters, `clear_previous` after the last old frame can arrive.
- `load_frame_in_place` on a session that already holds keys: the current keys are overwritten in place (probe C, 0 hits of the old key) and `has_previous` is cleared, but the previous slot is not wiped (F69-3). A session that holds stream state is refused (`mod.rs:297-300`).
- `Session::frame_unloaded` (`mod.rs:279`) gives a session whose every frame call is `BadValue` (`frame.loaded == false`); safe.
- `ReplayWindow::from_parts`: F69-6.

## Q8. Availability and other

- Cost of a forged frame that is `Fresh` by the window: one HMAC per loaded slot, no ChaCha20 (decryption only after a match, `seal.rs:213-223`). Compressions per slot: `ceil((14 + len(ad) + len(clear) + len(ct) + 9) / 64) + 1` (the pad block is precomputed, `hmac.rs:44-53`). With no associated data and a 255-byte body that is 6 (matches the test `seal_open_and_tag_stay_within_four_blocks_and_six_compressions`); with 255 bytes of `ad` it is at most 10. The previous slot doubles it. The amplification is 2x at most; the library has no rate limit, and callers must bound frames per second per sender. A duplicate or too-old counter costs no hashing.
- Open has no body cap (F69-5).
- ChaCha20 and HMAC use no secret-dependent allocation (there is none); the module is heap-free.
- Error kinds: `TagMismatch`, `Duplicate`, `TooOld` are added (`error.rs:25-31`) with no payload that depends on secrets (`needed` is 0 or a length).

## Dependencies

The crate has no new dependency. `rust/Cargo.toml` has no `[dependencies]` section; the change for frame mode is the empty feature `frame = []`. `rust/Cargo.lock` lists only the package `packbin` 0.1.0. The embedded probe (`rust/embedded/probe/Cargo.toml`) gains only the feature pass-through `frame = ["packbin/frame"]` and depends on `packbin` by path.

## Final verdict: PASS_WITH_WARNINGS

The implementation matches the contract byte for byte, the open order is as normative, the compare is constant-time, nothing reachable from untrusted bytes can panic or overflow, and the window commits only after a tag match. F69-1 should be fixed in the contract and API text before meshbell consumes the code: as documented, a caller who passes a counter that is not covered by the tag gets no replay protection and a one-frame denial of service. F69-2 and F69-3 are small to fix. F69-4 to F69-8 are hardening and documentation.

## Disposition (parent, 2026-10-25, same loop)

| Id | Decision | What changed |
|----|----------|--------------|
| F69-1 | Fixed in the documents (the counter is the caller's by contract) | Contract Replay window: the counter must come from bytes the tag covers; rustdoc of `open_frame`; the README example derives nothing from the wire. No byte or result changed |
| F69-2 | Documented, accepted as a caller duty | Contract: a frame that opens under the previous key commits into the same window, so the previous key is kept only for the changeover and cleared after it; rustdoc of `open_frame`. A window per slot would be a contract change (owner) |
| F69-3 | Fixed | `load_frame_in_place` and `clear_previous` overwrite the previous slot in place (`SlotKeys::wipe`); test `reloading_or_clearing_overwrites_the_previous_slot` |
| F69-4 | Fixed in the frame code; the shared part is a leftover | `black_box` after the zeroing of `DirKeys::fill`, `MacKey::derive` and `Pads::new` temporaries. The `prk`, `previous` and pad-block temporaries in `session_core/hkdf.rs` are shared with the stream session and untouched (changing them moves the stream figures): a hardening task for the owner |
| F69-5 | Fixed (contract, reference, fixture, Rust) | Open refuses a body or `clear_len` above 255 as `TooLong` before any hashing; fixture rows `refuse.open.body256` and `refuse.open.clear256`; test `a_body_or_clear_part_above_255_bytes_is_refused_before_any_hashing` (0 compressions) |
| F69-6 | Documented | Contract and rustdoc of `ReplayWindow::from_parts`: a restored window with `bits = 0` is empty |
| F69-7 | Documented | already bold in the contract and README |
| F69-8 | Documented | Contract security notes: symmetric keys, one `tag_len` per (key, epoch) across devices |

Verdict after the dispositions: PASS_WITH_WARNINGS (F69-2 and the shared `hkdf.rs` temporaries stay open). Device figures after the changes: `frame` 19,772 B flash, 1,896 B stack; the four existing sets unchanged.
