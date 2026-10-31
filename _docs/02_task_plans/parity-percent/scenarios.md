# Scenarios — parity as a percentage of the message

Source: loop 97 intake (`new-task` Step 4.7). Status `confirmed` = proposed behavior taken (silent proceed); no row is `unknown`.

| # | Axis | Actor / trigger / state | Behavior | Status | AC | Owning task AC |
|---|------|--------------------------|----------|--------|----|---|
| S1 | first use | A developer sets 25 % on a scheme and packs a 40-byte message | 10 parity bytes follow, 50 bytes sent | confirmed | AC-1, AC-3 | AZ-3499 AC-1, AC-3 |
| S2 | repeat | The same scheme packs messages of 10, 40 and 100 bytes | 3, 10 and 25 parity bytes: the count follows each message | confirmed | AC-1 | AZ-3499 AC-1 |
| S3 | concurrent | Two threads pack and unpack with one scheme | Schemes are immutable data and `n` is a pure function of `L`; nothing shared changes | confirmed | AC-1 | AZ-3499 AC-1 (pure function) |
| S4 | partial failure | A packet loses its last byte, the shorter length is one no `L` gives | `uncorrectable`, no values | confirmed | AC-6 | AZ-3499 AC-2 |
| S5 | partial failure | A packet loses bytes and the shorter length is again a valid length | The code check fails (the length byte is covered); `uncorrectable`, or a repair to another message only within the limits of the table in the contract | confirmed | AC-5, AC-7 | AZ-3499 AC-3 |
| S6 | permission denied | — | Not applicable: no actor, no secret | confirmed | out of scope (library) | n/a |
| S7 | invalid input | 101 %, -1 %, or a percentage together with a fixed count in a constructor | Refused when the scheme is built, `bad_parity` | confirmed | AC-9 | AZ-3499 AC-3; each package AC-1 |
| S8 | invalid input | Repair limit above 16, or below 0 | `bad_limit` before any byte is read; a limit 0 to 16 above this message's `n / 2` is lowered to it | confirmed | AC-8 | AZ-3499 AC-3; each package AC-6 |
| S9 | existing data | An 0.4.0 sender with `with_parity(4)` and a new receiver with the same scheme | Same bytes, same errors | confirmed | AC-11 | AZ-3499 AC-4 |
| S10 | undo | A fleet moves from 25 % back to 0 % or to a fixed count | A wire change for both ends, as changing `n` is today; the contract says both ends share the setting | confirmed | AC-9, AC-14 | AZ-3499 AC-5 |
| S11 | boundaries | L 0, the largest L, the largest L + 1, N 254, N 255 | L 0 sends 0 bytes and unpacks as empty; the largest L fits in 254; one more is `too_long`; N 255 is `too_long` | confirmed | AC-4, AC-6 | AZ-3499 AC-2; each package AC-3, AC-4 |
| S12 | existing-feature overlap | Dispatch by type byte, optional fields and compact text under a percentage | Dispatch needs one setting on all handlers, repair comes first then dispatch; optional fields only change `L` and so `n`; text is read after the repair | confirmed | AC-10 | AZ-3506 AC-7 (owner of record); the other seven package tasks repeat it as their AC-7 |

Rows added by `feature-assess` round 1 (2026-11-01):

| # | Axis | Actor / trigger / state | Behavior | Status | AC | Owning task AC |
|---|------|--------------------------|----------|--------|----|---|
| S12b | existing-feature overlap | A scheme with an optional field under a percentage | Each message carries the count of its own length | confirmed (assess-round-1) | AC-17 | AZ-3511, AZ-3512, AZ-3513 AC-1 |
| S12c | existing-feature overlap | A string field in a protected message under a percentage | The string is read after the repair | confirmed (assess-round-1) | AC-18 | AZ-3511, AZ-3512, AZ-3513 AC-2 |
| D4 | invalid input | Handlers with a percentage and a count of the same number are mixed in one unpack call | Refused; the error says which setting is a percentage (owner, 2026-11-01: make Rust unambiguous) | confirmed (assess-round-1) | AC-19 | AZ-3511 AC-3 (Rust); AZ-3512, AZ-3513 AC-3 (the others) |
