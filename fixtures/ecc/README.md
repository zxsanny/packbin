# Message ECC fixtures

Shared by all nine packages (AZ-2678, AZ-2679; contract `_docs/02_document/contracts/library/message-ecc.md`).

| File | What it is |
|------|------------|
| `vectors.txt` | The rows every package loads: protected bytes, repairs, refusals, limit cases. Row syntax is at the top of the file. |
| `percent-vectors.txt` | The rows of a scheme that declares a parity percentage instead of a count (loop 97, contract 1.1.0): counts, protected bytes, sent length to clear length, repairs and refusals. Row syntax is at the top of the file. A package's percentage test reads this file; `vectors.txt` stays the fixed-count file. |
| `check-vectors.sh` | Re-derives every row of both files with the reference codec (`scripts/ecc/eccfmt.py`) and checks the coverage, and for the percentage file also every percentage against every clear length (22,752 pairs, about 15 s). |
| `check-vectors.test.sh` | Proves the check fails on corrupted copies of the file. |
| `check-contract.sh` | Fails unless the accept-chance table in the contract is the one the reference computes. |
| `ring-cases.txt` | The rows the cross-language ring adds (AZ-2689): seeded repairs and refusals of the position message, and the hostile refusals (cut short, extended, unprotected, garbage, past 254 bytes, read by a scheme with no parity). `fix` and `bad` rows of `vectors.txt` syntax; kind `trailing` is a protected message read with n = 0. |

Tools (all in `scripts/ecc/`, Python 3.9 or newer, standard library only):

- `eccfmt.py`: the reference encoder, syndrome check and decoder.
- `gen_vectors.py [out]`: writes `vectors.txt` (seeded, so a rerun gives the same file).
- `gen_percent_vectors.py [out]`: writes `percent-vectors.txt` (own seed; the rows come from `percent_vectors.py`).
- `check_vectors.py [--percent] [file]`: what `check-vectors.sh` runs, once for each file (`PACKBIN_ECC_QUICK=1` skips the sweep of every percentage against every length, as the self-test does on its corrupted copies).
- `accept_table.py [--check FILE]`: prints the table of the chance that random bytes are accepted, which is also in the contract.
- `gen_ring_cases.py [out]`: writes `ring-cases.txt` (seeded; `ring-ecc.test.sh` fails when the file is not its output).
- `ring_ecc.py`: the rows and the comparison of the ring; `.github/workflows/ring-ecc.sh` runs it.
- `fuzz_reference.py`: the seeded counts of EC-5, EC-6, EC-7 and EC-14 on the reference codec.

A package tests the codec level (`protect`, `repair`) against `vectors.txt`, and the scheme level against the position fixture rows in `_docs/02_task_plans/message-error-correction/input_data/expected_results/results_report.md`.

## Ring line form under a percentage (for the ring task AZ-3508)

A driver line that names a count (`n`) names a percentage instead with the word `p<N>` in the place of the count: `fix ring.p25 p25 5 <received> <clear> <count>` reads `<received>` under 25 % with limit 5. A driver that gets `p<N>` with `N` above 100, or a count word that is not a number or `p<N>`, answers a malformed line (non-zero exit naming the line). Rows with a plain number are unchanged.

## The cross-language ring (AZ-2689, EC-9)

`.github/workflows/ring-ecc.sh` has each of the nine languages write the protected position message (n = 0, 1, 2, 4, 8, 16, 32) and then read what each of the nine wrote, intact and corrupted: 9 writers x 9 readers = 81 pairs (Dart joined in loop 99, AZ-4146; its driver is `.github/workflows/drivers/handoff-dart/`). The rows are the position rows of `vectors.txt` (the `.pos.` rows, the results report rows 7 to 12, truncation, extension, the unprotected message, the oversize buffer, `par` and `lmt`) and `ring-cases.txt`. A reader gets each corruption applied to the bytes the writer made, so a writer that wrote other bytes shows as a mismatched row. Every result is compared with the reference codec. The drivers (`.github/workflows/drivers`) answer `ecc-protect <n> <clear hex>`, `ecc-repair <n> <t> <hex>` and `ecc-batch <file>` (one result line for each `protect <n> <hex>` or `repair <n> <t> <hex>` line); a result is the hex of the position message and the repaired count, or the kind of the refusal.

The hostile-case file `fixtures/hostile/cases.txt` does not take the ECC refusals: its rows are packets of type 1 that each package replays through a loader keyed on the row id, with a README section for every id. The position message has type 0x40 and the packages' loaders would fail on an id they do not know. The refusals of EC-14 and EC-4 are the `ring.hostile.*` rows of `ring-cases.txt`, run in the ring against all nine packages.
