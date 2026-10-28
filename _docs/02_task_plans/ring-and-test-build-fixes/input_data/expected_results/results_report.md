# Expected results — ring driver number ranges and Rust test-build fixes

Input line (driver, after the op word) → output. `<key>` is 32 bytes of `11`, `<id>` is `00301005e8030000`, `<ad>` is `000100301005e803000004`, `<plain>` is `0102030405060708090a0b0c` (row E1 of `ring-cases.txt`).

| # | Input | Output (all 8 drivers) | Why |
|---|---|---|---|
| 1 | `seal <key> 1 256 4 <id> 4 <ad> - <plain> 123 300` | no result line; exit non-zero; stderr holds `frame line 1` | direction above 255 (C#, C++, Go seal it today) |
| 2 | `seal <key> 1 -1 4 <id> 4 <ad> - <plain> 123 300` | same as 1 | a sign is not a digit (Python passes it on today) |
| 3 | `seal <key> 1 1 256 <id> 4 <ad> - <plain> 123 300` | same as 1 | tag length above 255 (C++ wraps it to 0 today) |
| 4 | `open <key> 1 1 4 <id> 256 <ad> 0 53e9dc75fb459d775e6205661cdf37ff 123 300` | same as 1 | kind above 255 (C++ wraps it today) |
| 5 | `open <key> 1 1 4 <id> 4 <ad> 65536 53e9dc75fb459d775e6205661cdf37ff 123 300` | same as 1 | `clear_len` above 65,535 |
| 6 | `seal <key> 1 1 4 <id> 4 <ad> - <plain> 123 65536` | same as 1 | `out_len` above 65,535 (C#, Java, Python, Swift run out of memory on huge values today) |
| 7 | `mac <key> 4294967296 6e6574 4 e803` | same as 1 | epoch above 2^32 - 1 (Go wraps it today) |
| 8 | `verify <key> 7 6e6574 256 e803 56db9bec` | same as 1 | `n` above 255 |
| 9 | `seal <key> 1 255 4 <id> 4 <ad> - <plain> 123 300` | `BadValue`, exit 0 | top of the direction range goes to the package unchanged |
| 10 | `mac <key> 4294967295 6e6574 4 e803` | `BadValue`, exit 0 | top of the epoch range; the reference refuses an epoch above 0xFFFFFF |
| 11 | `seal <key> 1 1 4 <id> 4 <ad> - <plain> 123 65535` | `53e9dc75fb459d775e6205661cdf37ff`, exit 0 | top of the `out_len` range |
| 12 | ring row `refuse-seal ... 256 ...` in `ring-cases.txt` | `ring_frame.py` exit 1, message names the row | the loader keeps rows inside the rule |
| 13 | a reader with 7 mismatched refusal rows | 5 lines, then `    ... and 2 more` | no hidden mismatch |
| 14 | `cargo test --no-default-features --features frame --no-run` (Rust 1.98) | 0 `warning:` lines | the 4 helpers carry their callers' cfg |
| 15 | `run-suite.sh rust` with a stand-in `cargo` that prints `warning: unused` on a `--no-run` build | suite exit 1, message names the set | warnings fail the suite |

Ring totals after the change (read from the run): `refusals <lang>: 43 rows, 0 mismatched` x 8; `ring-frame: 64 pairs, mismatched: 0`.
