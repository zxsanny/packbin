# Expected results — frame ring refusals

Input line (driver) → output line. `dirs` and `out_len` are the new trailing fields; hex has no separators, `-` is empty.

| # | Input | Output | Why |
|---|---|---|---|
| 1 | `seal <key> 1 1 4 <id> 4 <ad> - <256 plain bytes> 123 300` | `TooLong` | body of 256 (vectors `refuse.seal.body256`) |
| 2 | `seal <key> 1 1 4 <id> 16 <ad> - <plain> 123 300` | `BadValue` | kind 16 (`refuse.seal.kind16`) |
| 3 | `seal <key> 1 0 4 <id> 4 <ad> - <plain> 123 300` | `BadValue`, exit 0, next line answered | direction 0, no abort (`refuse.seal.dir0`) |
| 4 | `seal <key> 1 3 4 <id> 4 <ad> - <plain> 12 300` | `BadValue` | direction 3 not loaded (`refuse.seal.unloaded`) |
| 5 | `seal <key> 1 1 4 <id> 4 <ad> - <plain 12 bytes> 123 15` | `BufferFull` | needs 16, has 15 (`refuse.seal.outshort`) |
| 6 | `seal <key> 1 1 4 <id> 4 <ad> - <plain 12 bytes> 123 16` | body hex (16 bytes) | exact fit |
| 7 | `open <key> 1 1 4 <id> 4 <ad> 0 <body 15 bytes> 123 300` | `ShortPacket` or `TagMismatch` as `framefmt.py` says | row checked at load |
| 8 | `mac <key> 7 <label 33 bytes> 4 <msg>` | `BadValue` | label 33 (`mac.label33`) |
| 9 | `open-skip` | `skip` | all 8 drivers |
| 10 | `seal zz 1 1 4 ...` (bad hex) | no stdout line; exit non-zero; stderr names line 1 | L-1, L-3 |
| 11 | writer prints `TooLong` for `E1`, ring `check` | `java: E1 seal gave TooLong, wanted 53e9dc75fb459d77...`, exit 1, no `frame-batch (open) failed` | L-2 |

Ring totals on HEAD after the change (to be read from the run, not from this table): `refusals <lang>: 38 rows, 0 mismatched` for each of the 8 languages; `ring-frame: 64 pairs, mismatched: 0`.
