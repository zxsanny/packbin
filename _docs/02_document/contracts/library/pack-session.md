# Contract: pack session

**Component**: library
**Producer task**: AZ-3200 (frame mode text), AZ-3202 (vectors), AZ-3203 (Rust); umbrella AZ-3192; stream session removed by AZ-3280..AZ-3291 (loop 74, ADR 009)
**Consumer tasks**: AZ-3232, AZ-3233, AZ-3234 (C#, Java, Swift); AZ-3292..AZ-3295 (C++, Go, Python, TypeScript, loop 75)
**Version**: 3.0.0
**Status**: current
**Last Updated**: 2026-10-27

## Purpose

One optional session beside clear pack: frame mode, sealed and authenticated frames for links that lose, reorder and duplicate messages (ADR 008). It is the only session since 3.0.0: the stream mode of 1.0.0 and 2.0.0 (a shared seed, an opener nonce, an implicit packet counter, no tag) is removed (ADR 009). Clear pack and unpack are unchanged. Each language implements frame mode itself, with the type names `FrameSession`, `FrameConfig`, `FrameDirection`, `FrameDirections`, `FrameSlot`, `FrameOpened`, `MsgContext`, `ReplayWindow`, `Freshness` and `MacKey`, spelled the same in every package (Java also has `FrameSealed` for its seal result).

## Configuration

A session's settings are fixed when it is loaded and never sent.

| Setting | Value |
|---------|-------|
| Key input | the caller's 32-byte key and a 32-bit `epoch` of at most 0xFFFFFF; no opener, no handshake |
| Directions | the directions the caller names at load, any of 1 (up), 2 (down), 3 (group); a call in a direction not loaded is refused |
| `tag_len` | 4, 8 or 16 bytes, fixed for the lifetime of the loaded key (any other value is `BadValue` at load) |
| Nonce | built per message from the caller's 8-byte `msg_id`, a 4-bit `kind` and the epoch |
| Associated data | caller bytes, 0 to 255, authenticated and not sent by packbin |
| Previous key | an optional second (key, epoch) slot, used by open only |
| Replay window | caller-owned, 64 messages per sender, optional per call |

## Frame mode

Frame mode is for links that lose, reorder and duplicate messages, have no connection, and can be written to by anyone with a radio. It encrypts and **authenticates**: it is the only part of packbin that does (ADR 008). It is the only session mode since 3.0.0 (ADR 009).

All integers are little-endian unless a row says otherwise. `‖` is concatenation. `HKDF` is HKDF-SHA256 (RFC 5869) with output length 32. `HMAC` is HMAC-SHA256 (RFC 2104, RFC 4231). `ChaCha20` is the RFC 8439 block function and cipher.

### Per-message inputs

| Input | Size | Meaning |
|-------|------|---------|
| `d` | 1 to 3 | direction; must be one the session loaded |
| `msg_id` | 8 bytes | caller bytes that are unique per (key, epoch, `d`) for every message ever sealed |
| `kind` | 0 to 15 | a caller nibble mixed into the nonce |
| `ad` | 0 to 255 bytes | associated data |
| `clear` | 0 to 255 bytes | a clear part: sent as is, authenticated |
| `plain` | 0 to 255 bytes | the part that is encrypted |

Limit: `len(clear) + len(plain) + tag_len` is at most 255 (the body). A longer body is `TooLong`.

### Key schedule

For each loaded direction `d`, at load time and never per message:

```
salt      = "packbin-frame" (13 ASCII bytes) ‖ epoch as a 32-bit integer (4 bytes)
K_enc(d)  = HKDF(IKM = key, salt, info = [d] ‖ "enc", L = 32)
K_mac(d)  = HKDF(IKM = key, salt, info = [d] ‖ "mac", L = 32)
```

`[d]` is the one byte 0x01, 0x02 or 0x03. `epoch` above 0xFFFFFF is `BadValue`.

### Nonce (12 bytes)

```
N = msg_id (8) ‖ ((kind << 4) | d) (1) ‖ epoch as a 24-bit integer (3 bytes)
```

### Encryption

`ciphertext = plain XOR ChaCha20(K_enc(d), N)` with the 32-bit block counter starting at 0 (the RFC 8439 cipher with initial counter 0). A 255-byte body needs at most 4 blocks.

### Tag (encrypt-then-MAC)

```
M   = N (12) ‖ len(ad) as one byte ‖ ad ‖ len(clear) as one byte ‖ clear ‖ ciphertext
tag = the first tag_len bytes of HMAC(K_mac(d), M)
```

### Body

```
body = clear ‖ ciphertext ‖ tag
```

`N` and the length bytes of `M` are never sent. Because `M` starts with `N`, the tag binds `msg_id`, `kind`, the direction and the epoch: a body replayed under another `msg_id` fails its tag. The receiver knows `len(clear)` from its own message layout and passes it to open.

### Seal

1. Check the arguments (direction loaded, `kind` at most 15, lengths); on a refusal nothing is written.
2. Write `clear`, then the ciphertext, then the tag into the caller's buffer; return the body length. A buffer shorter than the body is `BufferFull`.
3. On any error after writing started, the written bytes are zeroed.

Seal is deterministic: the same inputs give the same bytes. It never uses the previous key and never changes state.

### Open (the order is normative)

1. Argument checks: direction loaded and `kind` at most 15 (else `BadValue`); `len(ad)`, `len(body)` and `clear_len` each at most 255 (else `TooLong`, as in seal; a longer body is refused before any hashing). `len(body) < clear_len + tag_len` is `ShortPacket`. An output buffer shorter than `len(body) - clear_len - tag_len` is `BufferFull`.
2. Replay check (only when the caller passes a window and the message's counter): `Duplicate` or `TooOld` ends the call here, with no MAC computed.
3. Tag check with the current key: build `N` from the caller's `msg_id`, `kind`, `d` and the current epoch, recompute the tag over `M` from the received bytes, and compare all `tag_len` bytes in constant time.
4. On a mismatch, if a previous (key, epoch) is loaded, repeat step 3 once with it (keys and nonce from the previous epoch). Still no match: `TagMismatch`.
5. Decrypt the ciphertext into the caller's buffer with the keys of the slot that matched.
6. Commit the counter into the window (only now; a failed open never changes the window).
7. Return `Ok` with which slot opened (`Current` or `Previous`), the clear part's length and the plaintext's length.

The output buffer is not written unless the result is `Ok`.

### Replay window (one per sender, caller-owned)

- State: `top` (a 64-bit integer, the highest committed counter) and `bits` (a 64-bit integer; bit i set means counter `top - i` was committed). `bits = 0` means empty. 16 bytes.
- `check(n)`: if empty or `n > top`: `Fresh`. If `top - n >= 64`: `TooOld`. If bit `top - n` is set: `Duplicate`. Otherwise `Fresh`. `check` never changes the state.
- `commit(n)`: if empty: `top = n`, `bits = 1`. If `n > top`: shift `bits` left by `n - top` (0 when the shift is 64 or more), set bit 0, `top = n`. Otherwise set bit `top - n`.
- The counter is the caller's: a value that increases with every message of one sender. **It must come from bytes the tag covers** (for example the `msg_id` or the associated data), never from an unauthenticated field of the wire: the counter is an argument of open and is not part of the tag, so a captured frame replayed under a counter the attacker chooses would be accepted and could move the window (meshbell derives it from the same source, id field and creation wave that build `msg_id`).
- A window serves one sender and one key lifetime. A frame that opens under the previous key commits into the same window, so a caller keeps the previous key only for the changeover and calls clear-previous when it ends.
- A window restored from stored `(top, bits)` with `bits = 0` is empty: replay protection is off until the next commit. A caller that restores a window validates it (bit 0 set when `bits` is not 0).

### Results and error kinds

Frame mode reuses `BadValue` (configuration or argument out of range), `TooLong`, `BufferFull` and `ShortPacket`, and adds `TagMismatch`, `Duplicate` and `TooOld` to the same error kinds (ADR 008). The names are the same in every package. A replay check outcome is `Fresh`, `Duplicate` or `TooOld`; `Duplicate` and `TooOld` are also what open returns for them.

### Uniqueness rule (the caller's duty)

**For one (key, epoch, direction), a `msg_id` is never sealed twice with different contents.** Reuse breaks the confidentiality of both messages. Packbin cannot check it. Moving to a new epoch derives new keys and nonces. Example: meshbell builds `msg_id` as source (2 bytes) ‖ id field (2 bytes) ‖ creation wave (4 bytes); sequences restart every wave, waves never repeat and source ids are never reissued, so it is unique by construction.

### Security notes

- A tag truncated to 32 bits is allowed for HMAC (NIST SP 800-107 Rev. 1, carried into SP 800-224); LoRaWAN uses a 4-byte MIC on every frame. Polynomial MACs (GHASH, Poly1305) are not truncated to 32 bits.
- Forgery odds with a 4-byte tag are 2^-32 per try (about 68 years on average at one try per second). Callers count tag failures per sender as an attack indicator.
- The compare has no early exit and no secret-dependent branch; SHA-256 and ChaCha20 use no secret-indexed tables.
- A captured device reveals only its own key; callers rotate shared keys after a loss. The keys are symmetric: any holder of a direction key can forge any source for that direction, and `tag_len` is not in `M`, so one `tag_len` is used per (key, epoch) across all devices.
- Derived keys and HMAC states are overwritten when the session or key object is dropped, closed or disposed (best effort: a managed runtime or a compiler may keep copies the library cannot reach).

## MAC-only call

A tag without encryption, for a per-hop network check and for key fingerprints.

```
K_label = HKDF(IKM = key (32 bytes), salt = "packbin-frame" ‖ epoch as a 32-bit integer, info = 0x00 ‖ label, L = 32)
tag     = the first n bytes of HMAC(K_label, message)
```

- `label` is 1 to 32 bytes; the leading 0x00 keeps these keys apart from the frame keys (directions are 1 to 3). Any other length is `BadValue`.
- `n` is 4, 8, 16 or 32; any other value is `BadValue`. `epoch` above 0xFFFFFF is `BadValue`.
- The message is passed in parts (for example a 4-byte wave and the frame bytes) and hashed with no joined copy; the tag does not depend on how the message is split.
- The key object holds the HMAC state precomputed from `K_label` (the inner and outer pad states, 64 bytes), so a call costs only the message's SHA-256 compressions plus one. The object is at most 72 bytes.
- Verify compares all `n` bytes in constant time and returns a boolean.

## Worked examples

The values E1 to E5 of `_docs/02_task_plans/rust-m33f-and-frame-mode/input_data/expected_results/results_report.md` are the first known answers; `fixtures/frame/vectors.txt` (AZ-3202) is the shared fixture. They were computed from this text with an independent implementation (Python `hmac` and `hashlib`, ChaCha20 and HKDF from the `cryptography` package, checked against RFC 8439 §2.4.2).

## Change Log

| Version | Date | Change |
|---------|------|--------|
| 3.0.0 | 2026-10-27 | Removes the stream mode (Shape, Construction, the `stream` column of Configuration and its refusal rule) from every package (ADR 009, loop 74, AZ-3280..AZ-3291); names the frame types, the same in every package (owner D1). The Frame mode and MAC-only sections are unchanged from 2.0.0 apart from two sentences: the intro's stream sentence and the Security note that compared the wipe with the stream session. Frame bytes and `fixtures/frame/vectors.txt` are unchanged, so citations of "2.0.0" for the frame text stay valid. |
| 2.0.0 (consumers) | 2026-10-25 | C#, Java and Swift implement frame mode and the MAC-only call (AZ-3232, AZ-3233, AZ-3234, loop 71) and pass every row of `fixtures/frame/vectors.txt` and `fixtures/crypto/vectors.txt`; no byte, rule or version changed. |
| 2.0.0 | 2026-10-25 | Adds the Configuration section, `frame` mode and the MAC-only call (AZ-3192, ADR 008). Stream mode text, bytes, operations and results are unchanged from 1.0.0. |
| 1.0.0 | 2026-10-14 | Stream session (removed in 3.0.0). |

## Consumers

Frame mode: Rust (AZ-3203), C#, Java and Swift (loop 71); C++, Go, Python and TypeScript are scheduled for loop 75 (AZ-3292..AZ-3295) and keep verified SHA-256, HMAC-SHA256, HKDF-SHA256 and ChaCha20 for it (27 rows of `fixtures/crypto/vectors.txt`). meshbell (a separate repository) pins the packbin commit and renames its Rust `Session` to `FrameSession` when it moves past loop 74. The README. Archangel is not a consumer in this repository.
