# Message ECC fixtures

Shared by all eight packages (AZ-2678, AZ-2679; contract `_docs/02_document/contracts/library/message-ecc.md`).

| File | What it is |
|------|------------|
| `vectors.txt` | The rows every package loads: protected bytes, repairs, refusals, limit cases. Row syntax is at the top of the file. |
| `check-vectors.sh` | Re-derives every row with the reference codec (`scripts/ecc/eccfmt.py`) and checks the coverage. |
| `check-vectors.test.sh` | Proves the check fails on corrupted copies of the file. |

Tools (all in `scripts/ecc/`, Python 3.9 or newer, standard library only):

- `eccfmt.py`: the reference encoder, syndrome check and decoder.
- `gen_vectors.py [out]`: writes `vectors.txt` (seeded, so a rerun gives the same file).
- `check_vectors.py [file]`: what `check-vectors.sh` runs.
- `accept_table.py [--check FILE]`: prints the table of the chance that random bytes are accepted, which is also in the contract.

A package tests the codec level (`protect`, `repair`) against `vectors.txt`, and the scheme level against the position fixture rows in `_docs/02_task_plans/message-error-correction/input_data/expected_results/results_report.md`.
