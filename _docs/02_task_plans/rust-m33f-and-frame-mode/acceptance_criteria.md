# Acceptance criteria — loop 69 (frame mode, Rust first)

The full Given/When/Then text of each is in the specs under `input/`; this list is the loop-level set the decomposed tasks inherit. Project ACs exercised: AC-3 (shared golden fixtures, 0 mismatched bytes), AC-10 (speed, unchanged), AC-11 (CI on every push); the Out of scope line "Authentication ... inside the library" changes for frame mode only (PB-01).

## F1: Contract and ADR (PB-01)

- **AC-F1.1 Every byte determined.** Given `pack-session.md` 2.0.0 alone, when a reader implements seal, open, the replay window and the MAC-only call, then every byte of keys, nonce, ciphertext, M, tag and body, and every result, is determined: 0 open choices.
- **AC-F1.2 Examples follow.** Given the contract and an independent script written only from it, when E1 to E5 are recomputed, then 5 of 5 match `results_report.md`.
- **AC-F1.3 Stream unchanged.** Given `mode = stream`, when the contract is compared with 1.0.0, then 0 stream bytes, operations or results changed.
- **AC-F1.4 Scope recorded.** Given ADR 008 and `_docs/00_problem/`, when read, then frame mode authenticates, stream mode does not, and R-08 has exactly 1 exception (the body ends with its tag).
- **AC-F1.5 Open order.** Given the open procedure, then no MAC runs for a duplicate or too-old counter, 0 plaintext bytes are written before the tag matched, and a failed open changes the window 0 times.
- **AC-F1.6 Uniqueness rule.** The README and the contract state the `msg_id` uniqueness rule in bold with meshbell's `msg_id` as the example.

## F2: Primitive vectors (PB-02, Rust and the Python reference)

- **AC-F2.1 Rust matches.** Given `fixtures/crypto/vectors.txt`, when the Rust suite runs, then every SHA-256, HMAC-SHA256, HKDF-SHA256 and ChaCha20 row matches byte for byte (0 mismatched rows). The seven other packages: out of scope this loop.
- **AC-F2.2 Not vacuous.** Given a copy with 1 expected byte changed in each primitive's rows, when the Rust suite and `check_vectors.py` run, then each reports the failing row (4 of 4 primitives).
- **AC-F2.3 Published rows.** Every non-`derived` row names an RFC or FIPS section and `check_vectors.py` recomputes it with `hashlib`/`hmac`: 0 unmatched rows.
- **AC-F2.4 Pure-Python ChaCha20.** `scripts/crypto/chacha20.py` reproduces every RFC 8439 row (0 mismatches).

## F3: Frame golden vectors (PB-03)

- **AC-F3.1 Every row reproduces.** `check_vectors.py` re-derives every row of `fixtures/frame/vectors.txt` with the reference (0 mismatches) and the coverage list of PB-03 is complete (all 13 groups).
- **AC-F3.2 Independent check.** E1 to E5 and 3 other rows of different kinds recomputed by an implementation written independently of `framefmt.py` match: 8 of 8.
- **AC-F3.3 Not vacuous.** Copies with 1 byte changed in a `body`, a `tag`, a `result` and a `results` list each fail `check-vectors.test.sh` (4 of 4).
- **AC-F3.4 Deterministic.** Two generator runs give identical files (0 differing bytes).

## F4: Rust frame mode (PB-04)

- **AC-F4.1 Vectors.** With default features and with `--no-default-features --features frame`, every PB-03 row matches (0 mismatches), E1 to E5 included.
- **AC-F4.2 Tampering gives no plaintext.** Flipping each single bit of `ad`, `clear`, ciphertext and tag of E1 to E3 in turn, and changing `msg_id`, `kind`, direction, epoch and key, gives `TagMismatch` every time, the output buffer keeps its sentinel bytes, and the window is unchanged.
- **AC-F4.3 Replay before crypto.** A duplicate or too-old counter gives `Duplicate` or `TooOld` with 0 SHA-256 compressions run; a fresh valid body commits its counter; a fresh tampered body does not.
- **AC-F4.4 Previous slot.** At (B, 7) with previous (A, 6): a body sealed under (A, 6) opens `Ok` with `Previous`; under (B, 7) opens `Ok` with `Current`; with no previous slot the first is `TagMismatch`.
- **AC-F4.5 MAC-only.** E4 and E5 give the same tags for 1, 2 and 3 parts; a flipped tag bit verifies `false`; `size_of::<MacKey>()` is at most 72 B.
- **AC-F4.6 Cost per message.** For a 236 B plaintext, 11 B `ad`, no clear part, tag 4: seal and open each use at most 4 ChaCha20 blocks and 6 SHA-256 compressions; `tag` over 255 B uses at most 6 compressions.
- **AC-F4.7 Device.** On the Cortex-M4F embedded stage (`mps2-an386`) with the `frame` set, no heap or panic symbol is linked, the E1 round trip and the E4 verify match on the device, stack is at most 2,048 B and flash at most 20,480 B, both recorded in `limits.txt` at the measured figure plus 5%.
- **AC-F4.8 Feature switch.** With `frame` off, the flash and stack of base, text, ecc and session are unchanged (0 B difference); with `frame` on and `session` off, 0 stream-session symbols are linked.
- **AC-F4.9 Stream unchanged.** The existing session vectors, std/core cross-open tests and the ring pass with 0 changed stream bytes.
- **AC-F4.10 Refusals and hostile input.** Each PB-01 refusal returns its error kind (`BadValue`, `TooLong`, `BufferFull`, `ShortPacket`, `TagMismatch`, `Duplicate`, `TooOld`), seal leaves 0 partial output bytes, and random hostile bodies, lengths and `clear_len` values cause 0 panics.
- **AC-F4.11 Sizes.** `size_of::<ReplayWindow>()` is 16 B; a frame `Session` with two slots and three directions is at most 640 B and is recorded in the Rust component description.

## Out of scope

- The Rust Cortex-M33F embedded row (loop 70).
- PB-02 vector tests, and frame mode, in C#, Java, Swift, Python, TypeScript, C++, Go (later tasks); the cross-language frame ring.
- Hardware cycle counts on a real nRF52840; a frame-mode security audit (later task).
- Any change to stream-mode bytes, operations or results.
