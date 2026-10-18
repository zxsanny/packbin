# Compact text fixtures

Shared by all eight packages (AZ-2646, AZ-2647; contract `_docs/02_document/contracts/library/compact-text.md`).

| File | What it is |
|------|------------|
| `tables.json` | The frozen code-length tables, alphabets, capitals and character lists. Part of the wire format: any change is a wire break (new ADR). sha256 in the contract. |
| `tables.report.md` | Sizes on held-out sentences and synthetic number messages against the bounds CS-1, CS-2 and CS-14. |
| `vectors.txt` | The rows every package loads: text, expected bytes, refusals, ring packets and bit-flip targets. Row syntax is at the top of the file. |
| `check-vectors.sh` | Re-derives every row with the reference codec (`scripts/text/textfmt.py`) and checks the coverage. |
| `check-vectors.test.sh` | Proves the check fails on corrupted copies of the file and of the tables. |

Tools (all in `scripts/text/`, Python 3.9 or newer, standard library only):

- `textfmt.py`: the reference encoder and decoder.
- `train_tables.py --corpus DIR`: trains and freezes `tables.json` (`--check` retrains and compares byte for byte).
- `gen_vectors.py --corpus DIR`: writes `vectors.txt`.
- `emit_tables.py <lang>`: emits the constants of `tables.json` as source for a package; `--check FILE` proves a committed copy is current.

The corpus: the Tatoeba sentence exports `ukr`, `rus`, `eng` from https://downloads.tatoeba.org/exports/per_language/ (CC BY 2.0 FR, https://tatoeba.org; sha256 in `train_tables.py`). It is not committed. The "corpus" rows of `vectors.txt` are held-out Tatoeba sentences; their authors are credited on tatoeba.org.
