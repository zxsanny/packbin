# Expected results — parity as a percentage of the message

Computed with integer arithmetic `n(p, L) = min(32, (p × L + 99) div 100)` and `N = L + n`. Figures below were computed on HEAD fe7aeaf with a 12-line Python function, not copied from an earlier table; the reference `scripts/ecc/eccfmt.py` gets the same function in the implement task and `gen_vectors.py` writes the rows.

## Parity count n(p, L)

| p \ L | 0 | 1 | 3 | 10 | 40 | 100 | 222 | 254 |
|---|---|---|---|---|---|---|---|---|
| 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| 1 | 0 | 1 | 1 | 1 | 1 | 1 | 3 | 3 |
| 10 | 0 | 1 | 1 | 1 | 4 | 10 | 23 | 26 |
| 25 | 0 | 1 | 1 | 3 | 10 | 25 | 32 | 32 |
| 50 | 0 | 1 | 2 | 5 | 20 | 32 | 32 | 32 |
| 100 | 0 | 1 | 3 | 10 | 32 | 32 | 32 | 32 |

(For p 1 and above, L 254 is above the largest clear length, so the n shown is the formula only and the pack is refused: see the next table. p 0 is an unprotected scheme.)

## Largest clear length and impossible sent lengths (N in 0 to 254)

| p | largest L | sent lengths that some L gives | impossible N |
|---|---|---|---|
| 0 | no limit (the old test range is 0 to 254) | all (N = L) | 0 |
| 1 | 251 | 252 | 3 |
| 10 | 230 | 231 | 24 |
| 25 | 222 | 223 | 32 |
| 50 | 222 | 223 | 32 |
| 100 | 222 | 223 | 32 |

All 101 percentages: `L + n(p, L)` is strictly increasing in `L`, so each `N` has at most one `L`. Pairs `(p, L)` with `L` from 0 to the largest (0 to 254 for p 0): 22,752.

## Bytes (clear = `4001000065cd1d00a3e1110100`, 13 bytes, from `enc.pos.*` in `fixtures/ecc/vectors.txt`)

| p | n(p, 13) | sent bytes | same as |
|---|---|---|---|
| 0 | 0 | `4001000065cd1d00a3e1110100` | `enc.pos.n0` |
| 8 | 2 | `4001000065cd1d00a3e111010016bd` | `enc.pos.n2` |
| 30 | 4 | `4001000065cd1d00a3e1110100ca856682` | `enc.pos.n4` |
| 60 | 8 | `4001000065cd1d00a3e11101006d4f38479f3f2472` | `enc.pos.n8` |

Unpack of these with p 30 / 60 from the sent length alone (17 / 21 bytes) finds L 13.

## Unpack outcomes

| setting | input | t | result |
|---|---|---|---|
| p 100 | 7 bytes | 0 | `uncorrectable` (no L gives 7) |
| p 100 | 8 bytes, intact | 0 | L 4, row returned |
| p 50, L 40 (n 20) | 10 wrong bytes | 10 | repaired, count 10 |
| p 50, L 40 | 11 wrong bytes | 10 | `uncorrectable` |
| p 50, L 40 | 20 wrong bytes | 0 | `uncorrectable` |
| p 25, L 40 (n 10) | 5 wrong bytes | 5 | repaired, count 5 |
| p 25, L 40 | any bytes | 16 | limit lowered to 5, as the row above |
| p 25 | any bytes | 17 | `bad_limit` before any byte is read |
| p 100 | 255 bytes | 0 | `too_long` |
| p 101 | (scheme build) | — | `bad_parity` |
| p 20 and fixed n 4 | (scheme build) | — | `bad_parity` |

## Row words of `fixtures/ecc/percent-vectors.txt` (written by `gen_percent_vectors.py`; `vectors.txt` is unchanged so the eight loaders of it stay as they are)

```
pct <id> <p> <L> <n>              n(p, L) is n
encp <id> <p> <clear> <protected> pack under p writes <protected>
inv <id> <p> <N> <L|none>         the L found from the sent length N, or none
fixp <id> <p> <t> <received> <clear> <count>   repair under p
badp <id> <p> <t> <received> <kind>            refusal under p
limp <id> <p> <clear_len> <ok|too_long>        largest clear length
parp <id> <p> <n>                              bad_parity
lmtp <id> <t>                                  bad_limit
```
