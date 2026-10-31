# ADR-010: A scheme may declare a parity percentage; the count follows the message length

- **Status**: Accepted
- **Date**: 2026-11-01
- **Deciders**: project owner
- **Supersedes**: —
- **Superseded by**: —

## Context

ADR 007 lets a scheme declare `n` parity bytes, 0 to 32. Every message of the scheme carries exactly `n` bytes, whatever its length, so a developer who wants "about a quarter of the message as protection" must pick `n` by hand for the typical length, and a short message gets the same bytes as a long one. The owner asked (2026-10-31): can the system choose the number of parity bytes from the packet length, with the user choosing only how strong the protection is, 0 % being little and 100 % the most.

- Acceptance criteria addressed: `_docs/02_task_plans/parity-percent/acceptance_criteria.md` AC-1 to AC-16
- Owner decisions (2026-10-31): option B (build it); the percentage is **overhead** (parity bytes = the percentage of the clear length), not the share of wrong bytes that can be survived; the fixed `with_parity(n)` stays.

ADR 007 notes that `n` is not on the wire. A percentage keeps that: the receiver must get `n` from the received length alone.

## Decision

A scheme declares an integer percentage `p`, 0 to 100, instead of a count. The count for a clear message of `L` bytes is `n(p, L) = min(32, (p × L + 99) div 100)`, rounded up, capped at 32, in integer arithmetic. The receiver finds the one `L` with `L + n(p, L) = N`, where `N` is the received length (it is unique because the left side is strictly increasing in `L`), and reads `n = N - L`. The code, the bytes and the 254-byte limit are those of ADR 007: a message under `p` is exactly the message of a fixed-count scheme with `n(p, L)`. The format is contract `message-ecc.md` 1.1.0; the vectors are `fixtures/ecc/percent-vectors.txt`.

## Alternatives Considered

| Alternative | Rejected because |
|-------------|------------------|
| Percentage means the share of wrong bytes survived | Needs twice the bytes (`n = 2t`), reaches the 32-byte cap at 16 % of a 100-byte message, and 100 % (every byte wrong) cannot be met; the owner chose overhead |
| 0 to 100 maps linearly to 0 to 32 bytes for every message | Not length-based: the same bytes for 5 bytes and 200 bytes, which is what a fixed `n` already does |
| Put `n` (or `p`) on the wire | Breaks "both sides share the scheme", adds a byte every message, and the byte is itself unprotected |
| Round to nearest or down | Down gives 0 bytes for a short message at a small percentage and silently no protection; nearest needs a tie rule in eight languages. Up gives at least 1 byte for any `p` above 0 and `L` above 0 |
| A float percentage | A float `ceil` can differ by one at an exact multiple between languages; an integer 0 to 100 and integer arithmetic cannot |

## Consequences

### Positive

- One setting that follows the message: short messages carry few bytes, long ones more, up to the cap
- No byte on the wire, no new code, no new refusal kind; the percentage is one function and one search
- Fixed-count schemes are unchanged: same bytes, same errors

### Negative

- Some sent lengths no message has (for `p` 100, every odd length below 64): those are refused as `uncorrectable`, which a truncation that lands on a valid length is not
- The repair limit is checked after the length is known: a limit above `n / 2` of the message is lowered, not refused
- A percentage and a count cannot both be declared; dispatch needs one setting on all handlers
- Eight packages, the ring and the README change; the Cortex-M33F size pins may move

### Neutral / Open

- A percentage chosen per message at pack time, and a strength chosen from link quality, are not in this decision
- The cap of 32 bytes means a percentage above 32 % of a 100-byte message gives no extra protection

> Affects ADR 007_message-error-correction: the parity count may be derived from the clear length. ADR 007 itself is unchanged.
