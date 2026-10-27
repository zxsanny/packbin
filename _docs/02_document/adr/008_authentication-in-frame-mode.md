# ADR-008: Frame mode authenticates; stream mode does not

- **Status**: Accepted
- **Date**: 2026-10-25
- **Deciders**: project owner (route A, 2026-10-19)
- **Supersedes**: —
- **Superseded by**: —
- **Amended by**: ADR-009 (the stream mode beside frame mode is removed; this ADR's frame-mode decision stands)

## Context

Packbin's problem statement and `architecture.md` say authentication is not in the library, and restriction R-08 says the wire carries only the fields. The stream session (`pack-session.md` 1.0.0) matches that: a per-direction counter that is never sent, and no tag. meshbell, a LoRa field mesh whose whole field stack is Rust, needs the library to seal radio frames: LoRa frames are lost, reordered and duplicated; anyone with a 433 MHz radio can flip ciphertext bits (with a stream cipher, flipping bit k flips plaintext bit k, so a target position can be shifted without the key); there is no connection to hold a handshake; and field devices get captured, so each needs its own key. The owner decided on 2026-10-19 (route A) that this is a `frame` mode of the session, chosen by configuration next to `stream`, so one session type serves the websocket and the radio.

- Acceptance criteria addressed: `_docs/02_task_plans/rust-m33f-and-frame-mode/acceptance_criteria.md` AC-F1.1 to AC-F1.6
- Contract: `_docs/02_document/contracts/library/pack-session.md` 2.0.0

## Decision

Frame mode encrypts and authenticates; stream mode does not authenticate (it runs inside a protected connection). The tag is a truncated HMAC-SHA256 (4, 8 or 16 bytes, the caller's choice per loaded key) over the nonce, the associated data, the clear part and the ciphertext (encrypt-then-MAC), with ChaCha20 for the encryption and HKDF-SHA256 keys per (key, epoch, direction). The nonce is built from an 8-byte `msg_id` and a 4-bit `kind` that the caller supplies; packbin draws no randomness. R-08 gets exactly one exception: a frame-mode body ends with its tag (the length bytes of the MAC input are never sent). The new error kinds `TagMismatch`, `Duplicate` and `TooOld` join the existing error kinds, with the same names in every package. A MAC-only call (an HKDF-derived label key, the HMAC pad states precomputed) serves per-hop checks and key fingerprints.

## Alternatives Considered

| Alternative | Rejected because |
|-------------|------------------|
| Poly1305 (ChaCha20-Poly1305) | A polynomial MAC is not truncated to 32 bits, so a 4-byte tag would be unsafe or the tag would be 16 bytes on a link that carries about 1 kbit/s; truncated HMAC down to 32 bits is allowed (NIST SP 800-107 Rev. 1, SP 800-224) and LoRaWAN carries a 4-byte MIC on every frame |
| MAC-then-encrypt, or encrypt-and-MAC | A receiver would decrypt before checking; encrypt-then-MAC refuses a changed byte before any plaintext exists |
| A random nonce drawn by packbin | The core is heap-free and has no randomness source on a part with none; a caller `msg_id` that is unique by construction (meshbell: source, wave and sequence) needs no state; the cost is the uniqueness rule, which the contract and README state in bold |
| An implicit counter as in stream mode | The first lost frame would break every later one |
| A separate authentication library | The key schedule, the nonce and the tag must be one decision; meshbell needs the same bytes in every language, and the shared fixtures live here |
| Authentication in stream mode too | Stream mode runs inside TLS; changing its bytes would break every existing packet |

## Consequences

### Positive

- A changed byte, a replayed frame and a frame under another key or epoch are refused before any plaintext is written
- One session type serves the websocket (stream) and the radio (frame); stream bytes are unchanged
- A captured device reveals only its own key; epochs derive new keys without a handshake

### Negative

- A frame-mode body is longer than the fields by `tag_len` bytes; ADR-001's "the wire size is the sum of the present fields" holds for frame mode only with that tag counted, as it holds for ADR-007's parity bytes
- A caller who reuses a `msg_id` for different contents under one key, epoch and direction loses the confidentiality of both messages; packbin cannot check it
- A 4-byte tag is a forgery chance of 2^-32 per try; callers count tag failures per sender
- Every package that gains frame mode needs HMAC and HKDF tests of its own (PB-02 starts with Rust)

### Neutral / Open

- Frame mode ships in Rust first (AZ-3203); the other packages followed: C#, Java and Swift in loop 71, C++, Go, Python and TypeScript in loop 75
- A frame-mode security audit is a later task
