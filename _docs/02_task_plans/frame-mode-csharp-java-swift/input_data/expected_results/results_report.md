# Expected results — loop 71 (frame mode, C#, Java, Swift)

No new data. The expected outputs are the rows of the shared fixtures, produced by the Python reference `scripts/frame/framefmt.py` and the published vectors of `scripts/crypto/`, and re-derived by `fixtures/frame/check-vectors.sh` and `fixtures/crypto/check-vectors.sh`.

| input | expected output | where |
| --- | --- | --- |
| `op=keys` rows | `k_enc`, `k_mac` or `k_label` | `fixtures/frame/vectors.txt` |
| `op=seal` rows (E1 to E3, lengths, refusals) | `body` or `result` | `fixtures/frame/vectors.txt` |
| `op=open` rows (tamper, previous slot, window) | `result`, `slot`, `plain`, `window_after` | `fixtures/frame/vectors.txt` |
| `op=mac` rows (E4, E5, parts, verify) | `tag`, `result` or `valid` | `fixtures/frame/vectors.txt` |
| `op=replay` rows (17-step table) | `results`, `states` | `fixtures/frame/vectors.txt` |
| `sha256`, `hmac256`, `hkdf256`, `chacha-block`, `chacha-xor` rows | digest, tag, okm, block, cipher | `fixtures/crypto/vectors.txt` |

Mapping onto the existing project file: `_docs/00_problem/input_data/expected_results/` (AC-3 golden fixtures) is the same kind of oracle.
