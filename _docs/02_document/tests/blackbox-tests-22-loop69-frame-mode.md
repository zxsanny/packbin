# Blackbox tests 22 — frame mode of the session, primitive vectors (loop 69)

Loop 69 (AZ-3200 to AZ-3204, epic AZ-3199, umbrella AZ-3192). Frame mode is in Rust only (`--features frame`); the other seven packages are later tasks. Shared files: `fixtures/crypto/vectors.txt` (27 rows) and `fixtures/frame/vectors.txt` (170 rows).

## FT-X-156: primitive reference vectors

| Item | Value |
|------|-------|
| Input | `fixtures/crypto/vectors.txt`: SHA-256 (FIPS 180-4, one million `a`), HMAC-SHA256 (RFC 4231 cases 1 to 7), HKDF-SHA256 (RFC 5869 A.1 to A.3), ChaCha20 block and cipher (RFC 8439 §2.3.2, A.1, §2.4.2, A.2), two derived rows |
| Expected | every row matches in `scripts/crypto/check_vectors.py` (`hashlib`, `hmac`, pure-Python ChaCha20) and in the Rust private primitives; a copy with one changed byte per primitive fails |
| Run by | `fixtures/crypto/check-vectors.test.sh`; Rust `crypto_vectors_tests` |
| Not run by | the other seven packages (owner follow-up) |

## FT-X-157: frame mode vectors, Rust through the public API

| Item | Value |
|------|-------|
| Input | `fixtures/frame/vectors.txt`: E1 to E5 (meshbell's independent values), `keys` for 3 directions at 5 epochs, seal and open refusals, 11 plaintext lengths, clear parts of 0, 3, 40 bytes, `ad` of 0, 11, 255 bytes, tag 4, 8, 16, 33 tamper rows, the previous-slot rows, the 17-step replay sequence, open rows with a window, MAC-only rows |
| Expected | every non-`keys` row matches in `tests/frame_vectors_tests.rs` with `--features frame` and `--no-default-features --features frame`; `keys` rows match in `frame_core_tests`; a refused call writes 0 bytes; a failed open leaves the window equal |
| Run by | Rust (both feature sets); the reference `framefmt.py` and the independent `independent_check.py` |
| Not run by | the other seven packages |

## FT-X-158: tampering, replay before crypto, previous slot

In-crate tests (`frame_core_tests.rs`): every single bit of `ad`, clear part, ciphertext and tag of E1 to E3 flipped, and `msg_id`, `kind`, direction, epoch, key changed: `TagMismatch`, output sentinel untouched, window unchanged; a duplicate or too-old counter runs 0 SHA-256 compressions and 0 ChaCha20 blocks; a fresh valid body commits, a fresh tampered one does not; a session at (B, 7) with previous (A, 6) opens bodies of both (`Previous`, `Current`) and refuses the old one with no previous slot; seal and open at most 4 ChaCha20 blocks and 6 compressions for 236 B plaintext, 11 B `ad`.

## FT-X-159: refusals, hostile input, in-place load, sizes

`frame_hostile_tests.rs`: refusal kinds with no partial output, 2,000 random hostile bodies (no panic, output untouched on failure), a frame call on a stream session and the reverse refused (`session` on), `load_frame_in_place` equals `load_frame` and replaces keys, a session with stream state is refused frame keys, 300 random round trips, a 5,000-step model of the replay window; `size_of`: `ReplayWindow` 16 B, `MacKey` 68 B, frame-only `Session` 588 B.

## FT-X-160: frame set on the Cortex-M4F image

Embedded stage `frame` set (`rust/embedded`): the probe seals and opens E1 with a window and verifies E4 on QEMU `mps2-an386`; 19,772 B flash (limit 20,480 B), 1,896 B stack (limit 1,991 B), 0 B RAM, no heap or panic symbol, no stream-session symbol (`stream_hits`); base, text, ecc and session figures equal to the run on the commit before (14,700 / 456, 26,632 / 2,760, 17,980 / 760, 18,404 / 1,832). CI figures are read after the push.
