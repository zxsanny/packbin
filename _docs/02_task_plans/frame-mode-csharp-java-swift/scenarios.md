# Scenarios — frame-mode-csharp-java-swift (loop 71)

Source of rows: `intake` (new-task Step 4.7). Status: confirmed / out-of-scope / deferred. The rows of loop 69 (S1 to S12, Rust) hold for each package; this loop adds the managed-runtime rows.

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | the meshbell C# server opens a frame a node sealed (up, tag 4) | confirmed | the C# seal of E1 equals the Rust body byte for byte; open returns `Ok`, slot `Current`, the plaintext | AC-G1.1, AC-G3.2 | intake |
| S2 | a station hears one frame twice | confirmed | second open is `Duplicate` with 0 MAC computations, window unchanged | AC-G2.2 | intake |
| S3 | frames arrive out of order inside 64 counters, one 64 behind | confirmed | unseen counter is fresh and opens; seen is `Duplicate`; 64 or more behind is `TooOld` | AC-G1.1, AC-G2.2 | intake |
| S4 | someone flips a bit anywhere in ad, clear, ciphertext, tag, or changes msg_id, kind, direction, epoch, key | confirmed | `TagMismatch`, output keeps its sentinel, window unchanged | AC-G2.1 | intake |
| S5 | the key rotates; a frame sealed under the old (key, epoch) arrives | confirmed | `Ok` with slot `Previous`; no previous slot gives `TagMismatch` | AC-G2.3 | intake |
| S6 | lengths and buffers: body 256, ad 256, body shorter than clear_len + tag_len, output one byte short | confirmed | `TooLong`, `TooLong`, `ShortPacket`, `BufferFull`; seal leaves 0 partial bytes | AC-G2.5 | intake |
| S7 | epoch 0xFFFFFF and 0x1000000, direction 0 and 4, kind 16, tag_len 0, 5, 32 | confirmed | largest values work; others `BadValue` | AC-G1.1 | intake |
| S8 | a relay computes and checks the 4-byte network MIC over a message in 1, 2, 3 parts | confirmed | same tag for every split; flipped tag bit gives false; label 0/33, n 0/2/5 give `BadValue` | AC-G2.4 | intake |
| S9 | the same session object used from two threads (C# server, Java Android) | confirmed | seal is stateless and safe from many threads; the replay window belongs to the caller, one window per sender, not shared across threads (documented, not locked) | AC-G2.2, AC-G3.4 | intake |
| S10 | a session is disposed or released while a caller still holds it | confirmed | keys and pad states are overwritten at dispose / close / deinit; a call after dispose gives `BadValue`; best effort noted in docs | AC-G2.7 | intake |
| S11 | a caller reuses a msg_id for two messages | out-of-scope | the library cannot check it; bold rule in README and contract | — | intake |
| S12 | existing stream sessions in the three packages | confirmed | 0 changed stream bytes; all existing tests pass; Swift's case list test gets the 3 new kinds | AC-G3.1 | intake |
| S13 | C# on netstandard2.0 (no `CryptographicOperations`) | confirmed | same results through the hand-folded compare and the existing `Compat` helpers | AC-G3.3 | intake |

## Fit decisions

| card | collision | chosen option | constraint recorded |
|------|-----------|---------------|---------------------|
| 1 | Where the frame API lives: a `mode` on `PackSession` touches the stream class and ties two lifetimes to one type | A — a new `FrameSession` type beside `PackSession` in each package; B (mode on `PackSession`) rejected | yes: stream code untouched, AC-G3.1 |
| 2 | Error kinds: C# and Java return error objects, Swift has a pinned `Kind` enum and no buffer-full kind | A — three new kinds (`TagMismatch`, `Duplicate`, `TooOld`): classes beside `Uncorrectable` in C# and Java, enum cases in Swift with the pinned list updated; B (reuse `BadValue`) rejected: hides tamper from replay | yes: AC-G2.5, AC-G3.1 |
| 3 | The Rust AC counts SHA-256 compressions; managed runtimes give no such count | A — count MAC computations with an internal test-only counter; B (drop the check) rejected: the replay-before-crypto promise would be untested | yes: AC-G2.2 |

## Not walked

- Several senders sharing one replay window (caller owns one window per sender; contract says so).
- A frame session built from a `PackSession` instance (not in this loop).
