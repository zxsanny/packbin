# Expected results: percentage docs and device run

Inherits `fixtures/ecc/percent-vectors.txt` (the reference rows; loop 97) and the README table of the percentage.

| Input | Expected output |
|-------|-----------------|
| p = 25, clear length 40 | n = 10 parity bytes |
| p = 50, clear length 40 | n = 20 |
| p = 100, clear length 40 | n = 32 (cap) |
| p = 1, clear length 40 | n = 1 (rounded up from 0.4) |
| p = 0 | no parity: the bytes of a scheme without parity |
| repair limit 16 on a message with n = 4 | lowered to 2 |
| one run, M3 vs M33F, same rows | identical bytes |
| rounding changed to floor | a QEMU run fails |

The exact device figures (case count, bytes) are written by the task spec after the first run on HEAD.
