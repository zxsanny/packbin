# ADR-007: A scheme may add parity bytes that detect and repair a corrupted message

- **Status**: Accepted
- **Date**: 2026-10-18
- **Deciders**: project owner
- **Supersedes**: —
- **Superseded by**: —

## Context

Nothing detects a flipped bit today. `compact_text_decoder_review_loop36.md` says a flipped bit can turn one valid text into another valid text, and `problem.md` says a checksum helps only when the schema declares one. The links this library serves (LoRa and similar) carry a few hundred bits per second and flip bits. The owner asked (2026-10-18) for a CRC for the whole message, then for self-correction with a configurable number of bytes.

- Acceptance criteria addressed: EC-1 to EC-17 (`_docs/02_task_plans/message-error-correction/acceptance_criteria.md`)
- Owner decisions (2026-10-18): one mechanism, no separate CRC; a per-scheme setting; at most one message per code word; session parity over the padded bytes; correction behind `PACKBIN_NO_ECC` and off on Cortex-M4F; full correction in loop 38, not detection first.

ADR-001 says the wire size is the sum of the present fields. This ADR makes one opt-in exception: a scheme that declares parity bytes sends them after the fields.

## Decision

A scheme declares `n` parity bytes (0 to 32, default 0). The format, the error kinds and the rules for sessions and dispatch are in `_docs/02_document/contracts/library/message-ecc.md`, version 1.0.0. The code is a Reed-Solomon code over GF(256) that also covers the clear length. The caller chooses at unpack how many wrong bytes it will repair (default 0, detect only).

## Alternatives Considered

| Alternative | Rejected because |
|-------------|------------------|
| A CRC of 1, 2 or 4 bytes | Detects only; the same bytes of Reed-Solomon parity detect as well (any `n` wrong bytes, then 1 in 256^n for random bytes) and also repair |
| A CRC and a separate error-correcting code | Two mechanisms, two byte counts, no gain in detection |
| Parity always on, one fixed `n` | Breaks every existing packet; costs bytes where the link is clean |
| Detect first, repair in a later loop | Same wire bytes, but every package is touched twice (about 7 more points) |
| Splitting a long message into blocks | Not needed for messages of at most 254 bytes; it can be added later without changing the bytes of the short ones |
| A plain systematic code without the length byte | Accepts a message with one trailing `00` more or less (about 1 in 256 for a lost last byte) |

## Consequences

### Positive

- A message with up to `n` wrong bytes is detected, and up to `n / 2` repaired, in all eight packages
- Schemes with `n` = 0 are unchanged: same bytes, same errors
- The repair is local to the message, so a flipped bit cannot reach the next message

### Negative

- Repairing `t` bytes gives up detection: garbage may be repaired to a different message (the table in the contract); the default is detect only
- A protected session payload is longer than clear pack by `n` bytes
- A message is at most 254 bytes; C++ unpack of a protected scheme needs a writable buffer
- Every package gains an encoder and a decoder (Berlekamp-Massey), and the Cortex-M4F build leaves the feature off

### Neutral / Open

- Real-message retraining of the text tables (D5), the first tags and F44 are not changed by this ADR
- Erasure decoding (known bad positions) is not in v1
