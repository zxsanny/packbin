---
loop: 97
branch: dev
---

# Parity as a percentage of the message

Owner decision (2026-10-31, loop 97 intake, hopper empty): option B of the owner's question "what about adaptive FEC?". Today a scheme declares a fixed count `n` of 0 to 32 parity bytes (`with_parity(n)`, ADR 007, contract `message-ecc.md` 1.0.1) and every message of that scheme carries exactly `n` bytes whatever its length. The owner wants the system to derive the count from the message length, with the user choosing only how strong the protection is.

## What and why

A scheme may declare a **percentage** instead of a count. At pack the system computes the parity count from the clear length of that message; at unpack it computes the same count from the received length alone (`n` is not on the wire). 0 % is the least protection (no or almost no extra bytes), 100 % the most (as many parity bytes as data, capped at 32). The user never picks a byte count.

Owner answers (2026-10-31):

- Meaning of the percentage: **overhead**. Parity bytes = the percentage of the clear message length (25 % of 40 bytes = 10 parity bytes). Not "share of wrong bytes survivable".
- The existing fixed `with_parity(n)` stays as it is.

## Change location

Owner confirmed (2026-10-31): "the scheme's parity setting (`with_parity` / `withLimits(parity)` / `parity(...)`) in all 8 packages, plus the `message-ecc` contract". No UI. Library only.

## Flagged concerns

| concern | policy / owner | status | severity |
|---|---|---|---|
| The count must be recoverable from the received length alone, so the length formula must be exact and identical in 8 languages (rounding) | AC pins one integer formula and vectors for it | open | Medium |
| A wire change for schemes that opt in; a contract bump | contract `message-ecc` 1.1.0, existing `n` schemes byte-identical | open | Medium |
| C++ flash and stack pins (`m33f_*`) and `PACKBIN_NO_ECC` builds | any added core code is held by the M33F pins; a raise of a pin needs a line in `AGENT_GOTCHAS.md` | open | Medium |
