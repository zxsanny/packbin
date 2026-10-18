---
loop: 38
branch: dev
---

# Message error correction (CRC request, widened)

## What

An optional protection layer over the whole packed message, in all eight packages. A scheme declares a number of parity bytes `n` (0 means off, which is today's behaviour and today's bytes). With `n` parity bytes the receiver detects corruption of the message and corrects up to a chosen number of wrong bytes, at most half of `n`. A wrong byte counts once whether one bit or eight of it flipped. Beyond that capacity unpack returns a typed error and never a wrong row.

## Why

Nothing detects a flipped bit today: `_docs/05_security/compact_text_decoder_review_loop36.md:21` ("a flipped bit can turn one valid text into another valid text") and `_docs/00_problem/problem.md:39` ("a checksum detects that only when the schema declares one"). ADR-006 line 50 lists "CRC for a whole message" as a separate later task. The links this library serves carry a few hundred bits per second and flip bits, so the owner asked (2026-10-18) for detection and, where the byte budget allows, correction, with a configurable number of bytes.

## Owner requests (2026-10-18)

1. CRC for the whole message (option A of the loop 38 intake).
2. "Try to make self-corrected code, and even if it is possible, a configurable amount of bytes intended for the self-correction."

## Decisions accepted at intake (all five recommended)

1. One mechanism, a Reed-Solomon code over bytes, no separate CRC. It gives CRC-style detection with the same byte count. The decoder takes a correction limit `t` from 0 to `n/2`; `t = 0` is detect-only.
2. The parity count is a per-scheme setting beside `Limits`. Both sides share the scheme, so no byte on the wire says it.
3. One block holds at most 255 bytes including parity. A longer message gets a typed error at pack. Splitting into blocks is out of v1.
4. Sessions: parity covers the encrypted bytes. A protected session payload is `n` bytes longer than clear pack, which amends `pack-session.md` ("the same length as clear pack") for protected schemes only.
5. Embedded: encode is available on every target that has the flash; correction sits behind a build flag (`PACKBIN_NO_ECC`) and is off on the Cortex-M4F build.

## Code sections / UI locations for this loop

Owner choice, 2026-10-18: "Package entry points + contracts": the scheme and the pack/unpack entry points in all eight packages (`csharp/`, `typescript/src/`, `python/src/packbin/`, `rust/src/`, `cpp/include/packbin/`, `java/src/main/java/packbin/`, `go/`, `swift/Sources/Packbin/`), the contracts `_docs/02_document/contracts/library/compact-text.md` and `pack-session.md`, and `fixtures/`.

## Out of scope

- Splitting a long message into blocks, interleaving.
- Real-message retraining of the text tables (D5), which waits for the owner's 100 to 200 messages.
- The first `v*` / `go/v*` tags and F44 (owner only).
- Correction on the Cortex-M4F build.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Correcting `t` bytes lowers the guaranteed detection to `n - t` bytes; garbage beyond capacity can decode to a wrong row | the contract states it; the caller picks `t` (`t = 0` gives full detection) | open | High |
| Cortex-M4F flash margin is 60 B; even encode may not fit | encode and correction behind flags on that target; AC checks the size | open | Medium |
| Session payload length changes for protected schemes | amend `pack-session.md`; unprotected schemes unchanged | resolved | Medium |
| 255-byte block limit | typed error at pack; owner accepted | accepted-risk | Low |
