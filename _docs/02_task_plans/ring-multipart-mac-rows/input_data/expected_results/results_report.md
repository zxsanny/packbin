# Expected results: frame ring, MAC rows over a message in several parts

Reference: `scripts/frame/framefmt.py` `mac_tag(key, epoch, label, n, parts)` = HMAC over the concatenation of the pieces, truncated to `n`. Values read on HEAD 98d2202 with the reference (key `22` x 32, label `net`):

| driver line (`mac <key> <epoch> <label> <n> <message>`) | expected output of every driver |
|---|---|
| `mac 22..22 7 6e6574 4 e8030000c0c1c2c3c4c5c6c7c8c9cacbcccdcecfd0d1d2d3` (single piece, row `E4`) | `56db9bec` |
| `mac 22..22 7 6e6574 4 e8030000\|c0c1c2c3c4c5c6c7c8c9cacbcccdcecfd0d1d2d3` (4\|20) | `56db9bec` (same tag) |
| `mac 22..22 8 6e6574 4 636865636b` (row `E5`) | `3cf8e8c5` |
| `mac 22..22 8 6e6574 4 6368\|-\|65636b` (`ch`, empty, `eck`) | `3cf8e8c5` (an empty piece changes nothing) |
| `mac 22..22 7 6e6574 4 c0c1c2c3c4c5c6c7c8c9cacbcccdcecfd0d1d2d3\|e8030000` (pieces swapped) | `0fa837eb` (not `56db9bec`) |
| `verify 22..22 7 6e6574 4 c0c1…d3\|e8030000 56db9bec` | `invalid` |
| `mac 22..22 7 6e6574 4 ab\|zz` | malformed line: non-zero exit naming `frame line N` |
| `mac 22..22 7 6e6574 5 ab\|cd` (`R.mac.p.nbad5`) | `BadValue` |
| every other new `P.*` row | the reference tag, equal in 8 of 8 drivers |
