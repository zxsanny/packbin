---
loop: 96
branch: dev
---

# Frame ring: MAC rows over a message in several parts

Ticket AZ-3495. Owner decision (2026-10-31, loop 96 intake, hopper empty): picked "multi-part MAC rows in the ring" from the loop 95 leftovers. This is the owner opt-in that G8m of loop 77 (`_docs/02_task_plans/frame-ring/scenarios.md`) asked for; it was out of scope then because the driver line format carries one message.

## What and why

All eight packages take the MAC-only message in parts (Go `Tag(tag, parts...)`, Java `tag(out, parts...)`, C# `Tag(ReadOnlySpan<ReadOnlyMemory<byte>>, tag)`, Swift `tag([[UInt8]], length:)`, Python and TypeScript a list, Rust `tag(&[&[u8]], out)`, C++ `tag(parts, count, out)`), and the README sells it ("a 4-byte network check over a message in parts"). The ring (`.github/workflows/ring-frame.sh`) cannot check that path: every `mac`, `verify` and `refuse-mac` row, and every driver line, carries one hex message, and all eight drivers hand the package a list of one piece. A package that tags only the first piece, stops at an empty piece, or restarts the hash per piece passes the ring today. `fixtures/frame/vectors.txt` has `parts` rows (pieces joined by `|`) read by each package's own tests, but nothing compares the languages with each other on them.

Probe on HEAD 98d2202 (Linux, Ubuntu; after the root-owned `csharp/obj` cache file was removed, see Flagged concerns), `bash .github/workflows/ring-frame.sh`, 30 s, exit 0:

```
ring-frame: 26 seal rows and 27 refusal rows
ring-frame: 26 open rows for each of 8 writers, and 31 refusal rows
ring-frame: 19 mac rows and 9 refusal rows
ring-frame: 19 verify rows for each of 8 writers, and 5 refusal rows
pair <writer> -> <reader>: 45 rows, 0 mismatched      (64 pairs)
refusals <lang>: 72 rows, 0 mismatched                (8 languages)
ring-frame: 64 pairs, mismatched: 0
```

`fixtures/frame/ring-cases.txt` holds 19 `mac`, 9 `refuse-mac`, 5 `verify`. The reference (`scripts/frame/framefmt.py` `mac_tag(key, epoch, label, n, parts)`) already takes parts and hashes their concatenation, so it needs no change.

## Decision: one field, pieces joined by `|`

The `message` field of a `mac`, `refuse-mac` and `verify` row, and of a driver `mac` / `verify` line, becomes the pieces in order, each hex or `-` (empty), joined by `|`, as `parts` in `vectors.txt`. A single piece is unchanged, so the 19 + 9 + 5 existing rows and the 8 drivers' behavior on them do not change. Not taken: a new line word or a count column (more driver code, no gain); a `parts=` key (the rows are positional).

## Code sections / UI locations for this loop

No UI. The frame ring harness only; no package source and no wire format changes.

- `scripts/frame/ring_frame.py`: the row loader (`mac`, `refuse-mac`, `verify` branches) splits the field into pieces and calls the reference with them; `cmd_mac_in` and `cmd_verify_in` write the field as `|`-joined pieces (`hx()` writes `-` for an empty piece).
- `fixtures/frame/ring-cases.txt`: the new rows and the header comment.
- The eight drivers' `mac` and `verify` functions: `.github/workflows/drivers/handoff_frame.py`, `handoff-frame.ts`, `HandoffFrame.java`, `csharp/HandoffFrame.cs`, `handoff-go/frame.go`, `handoff-rust/src/frame.rs`, `handoff_frame.cpp`, `handoff-swift/Sources/handoff-swift/Frame.swift`.
- `fixtures/frame/README.md`: the row and line format.
- `.github/workflows/ring-frame.test.sh` and `.github/workflows/ring-frame-drivers.test.sh`: new cases.

## Flagged concerns

| concern | policy / owner | status | severity |
|---|---|---|---|
| Spelling of an empty piece: a driver's hex reader may take `""` as zero bytes (`ab\|\|cd`), another may refuse it | AC-4 pins: only `-` is an empty piece, any other empty piece is a malformed line in all 8 drivers | open | Low |
| Root-owned build output (`csharp/bin`, `cpp/build`, dirs under `rust/target`, `csharp/obj/Debug/netstandard2.0`) left by earlier container runs; the first ring run failed on a root-owned `csharp/obj/project.nuget.cache`; the owner chose "replace the folders" (2026-10-31), the agent removed what it could (no sudo); the ring then passed | owner: `sudo chown -R` or remove the rest; not needed for this loop unless a build fails on them | accepted-risk | Low |

Out of scope: zero pieces (an empty list; one empty piece is `-` and already a row, `msg0`); a MAC part count above what a row needs (rows use 2 to 5 pieces); `refuse-seal` / `open` rows (no parts there); the packages' own tests; any wire or API change.
