# Message error correction — expected results

The input is the 13-byte position fixture `4001000065cd1d00a3e1110100` as the clear message. The parity bytes are the remainder of the code word divided by the generator whose roots are α⁰ to α^(n−1) in GF(256) with the field polynomial 0x11D (α = 2). The code word is one byte longer than what is sent: its first byte is the clear length, which is covered and not sent, then the clear message, shifted by `n` bytes. The contract (`_docs/02_document/contracts/library/message-ecc.md`, written by the first task) fixes this choice; the rows below are the cross-language golden bytes. They were computed with a reference script and each protected message was checked to have all-zero syndromes.

## Comparison methods

| Method | Description |
|--------|-------------|
| `exact` | bytes or row equal |
| `threshold_max` | actual ≤ the value |

## Protected bytes

| # | Input | Expected Result | Comparison | Reference |
|---|-------|-----------------|------------|-----------|
| 1 | fixture, n = 0 | `4001000065cd1d00a3e1110100` (13 bytes) | exact | EC-1 |
| 2 | fixture, n = 1 | `4001000065cd1d00a3e1110100ab` (14 bytes) | exact | EC-2 |
| 3 | fixture, n = 2 | `4001000065cd1d00a3e111010016bd` (15 bytes) | exact | EC-2 |
| 4 | fixture, n = 4 | `4001000065cd1d00a3e1110100ca856682` (17 bytes) | exact | EC-2 |
| 5 | fixture, n = 8 | `4001000065cd1d00a3e11101006d4f38479f3f2472` (21 bytes) | exact | EC-2 |
| 6 | fixture, n = 16 | `4001000065cd1d00a3e11101004ace66ecd5e4a28ffa28098279f5f19d` (29 bytes) | exact | EC-2 |

## Corruption cases

| # | Input | Expected Result | Comparison | Reference |
|---|-------|-----------------|------------|-----------|
| 7 | row 3 with byte 5 changed `cd` → `cc` (one bit), n = 2, t = 1 (`4001000065cc1d00a3e111010016bd`) | the position row, 1 byte repaired | exact | EC-5 |
| 8 | row 4 with byte 2 `00` → `5a` and byte 9 `e1` → `22` (`40015a0065cd1d00a322110100ca856682`), n = 4, t = 2 | the position row, 2 bytes repaired | exact | EC-5 |
| 9 | the input of row 8, n = 4, t = 1 | error kind uncorrectable, 0 values | exact | EC-6 |
| 10 | the input of row 8, n = 4, t = 0 | error kind uncorrectable, 0 values | exact | EC-6 |
| 11 | row 4 unchanged, n = 4, t = 2 | the position row, 0 bytes repaired | exact | EC-8 |
| 12 | 3 bytes `400100`, n = 4 | error naming the parity, 4 needed, 3 present, 0 values | exact | EC-8 |
| 13 | clear message of 251 bytes, n = 4 | error naming 251 and the limit 250, 0 bytes written | exact | EC-4 |
| 14 | `n` = 33 in a scheme | error naming `n` and 32 at scheme build | exact | EC-3 |

## Thresholds

| # | Input | Expected Result | Comparison | Reference |
|---|-------|-----------------|------------|-----------|
| 15 | 200,000 seeded random 15-byte buffers, n = 2, t = 0 | accepted ≤ 12 | threshold_max | EC-7 |
| 16 | 1,000 corrections of a 254-byte message, 16 parity bytes, 8 wrong bytes | ≤ 1 s (Python ≤ 5 s) | threshold_max | EC-13 |
| 17 | 20,000 seeded corruptions of 1 to 4 bytes of row 4, t = 0 | refused: 20,000; accepted: 0 (reference script result) | exact | EC-6 |
