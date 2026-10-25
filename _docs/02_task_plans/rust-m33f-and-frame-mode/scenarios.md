# Scenarios — rust-m33f-and-frame-mode (frame mode, Rust first)

Source of rows: `intake` (new-task Step 4.7). Status: confirmed / out-of-scope / deferred.

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | a node seals its first status frame (up, tag 4) and the server opens it | confirmed | the body equals E1 byte for byte; open returns `Ok`, slot `Current`, the plaintext | AZ-3203 AC-1 | intake |
| S2 | a station hears one frame twice (duplicate counter) | confirmed | the second open is `Duplicate` with 0 SHA-256 compressions and the window unchanged | AZ-3203 AC-3 | intake |
| S3 | frames arrive out of order, inside 64 counters of the highest | confirmed | a never-seen counter is `Fresh` and opens; a seen one is `Duplicate`; one 64 or more behind is `TooOld` | AZ-3203 AC-3, AZ-3202 AC-1 | intake |
| S4 | someone flips a bit of ciphertext, tag, `ad`, `clear`, or changes `msg_id`, `kind`, direction, epoch or key | confirmed | `TagMismatch`, the output buffer keeps its sentinel bytes, the window is unchanged | AZ-3203 AC-2 | intake |
| S5 | the network key rotates: a frame sealed under the old (key, epoch) arrives at a node that holds the new key and the old one as previous | confirmed | `Ok` with slot `Previous`; with no previous slot `TagMismatch` | AZ-3203 AC-4 | intake |
| S6 | a stream call on a frame session, or a frame call on a stream session | confirmed | `BadValue`, nothing written, no state change | AZ-3203 AC-8 | intake |
| S7 | a body of 256 bytes, `ad` of 256 bytes, a body shorter than `clear_len + tag_len`, an output buffer one byte short | confirmed | `TooLong`, `TooLong`, `ShortPacket`, `BufferFull`; seal leaves 0 partial bytes | AZ-3203 AC-8, AZ-3202 AC-1 | intake |
| S8 | epoch 0xFFFFFF (largest) and 0x1000000, direction 0 and 4, `kind` 16, `tag_len` 0, 5 and 32 | confirmed | the largest values work and match the vectors; the others are `BadValue` | AZ-3203 AC-1, AZ-3202 AC-1 | intake |
| S9 | a relay computes and checks the 4-byte network MIC over a message split in two or three parts, label of 1 and 32 bytes | confirmed | the tag does not depend on the split; a flipped tag bit verifies `false`; label of 0 or 33 bytes and `n` of 0, 2, 5 are `BadValue` | AZ-3203 AC-5 | intake |
| S10 | a caller seals two different messages under one (key, epoch, direction, `msg_id`) | out-of-scope | the library cannot check it; the uniqueness rule is in bold in the README, the contract and the rustdoc of `seal_frame` and `MsgCtx` | AZ-3200 AC-6 (documented, not code) | intake |
| S11 | the nRF52840 build with `frame` on, and a build with `frame` off | confirmed | frame on: no heap or panic symbol, stack at most 2,048 B, flash at most 20,480 B; frame off: the base, text, ecc and session figures do not change | AZ-3204 AC-1, AC-2 | intake |
| S12 | existing stream sessions (std `PackSession`, `nostd::Session`) and the ring | confirmed | 0 changed stream bytes; all existing session tests pass | AZ-3203 AC-7 | intake |

## Fit decisions

| card | collision | chosen option | constraint recorded |
|------|-----------|---------------|---------------------|
| 1 | The project says authentication is out of scope (acceptance criteria, architecture "Authentication: none inside the library", rule R-08: no tag on the wire) | A — owner decision of 2026-10-19 (route A): frame mode authenticates, stream mode does not; R-08 gets one exception (the body ends with its tag); ADR 008 records it and states that it amends ADR 001's "the size is the sum of the fields" for frame mode only | yes: PB-01 also edits the architecture line, `_docs/00_problem/` and the Out of scope line |
| 2 | The pad, hash and key derivation are one shared piece of code for the std `PackSession` and `nostd::Session`; frame mode needs a different nonce layout, precomputed MAC pad states and a test-only compression counter | A — add the frame pieces beside the existing functions and leave the stream functions untouched (one shared SHA-256 and ChaCha20 block, no change to the stream path); B (refactor the shared HMAC and pad into generic ones) was rejected: it touches the stream bytes' code for no frame requirement | yes: the stream path is unchanged, AC-F4.9 checks it |
| 3 | The embedded stage lists feature sets with limits; a `frame` set is new, and the `std` build includes every feature | A — add one `frame` set with a limit at the measured figure plus 5% (never above 20,480 B / 2,048 B); the other four sets keep their figures; `std` includes `frame` as it includes `session` | yes: AC-F4.7, AC-F4.8 |

## Not walked

- Several senders sharing one replay window (the caller owns one window per sender; the contract says so).
- A frame-mode session loaded from the std `PackSession` type (the spec names `nostd::Session`; the std type is not changed in this loop).

## Assessment round 1 (loop 69)

D1 (open with `ad` of 256 bytes), D2 (load by value costs stack) and D3 (`frame` not implied by `std`): covered, see `_docs/loops/loop69/assessment69.md`. Verdict COMPLETE.
