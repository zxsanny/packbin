# Expected results — Dart package (loop 99)

Dart reuses the shared fixtures; it adds no new input data. Comparison is `exact` unless stated.

| # | Input | Expected result | Comparison | Reference file |
|---|-------|-----------------|------------|----------------|
| 1 | Position fixture rows 1 to 3 | as in the project table | exact | `_docs/00_problem/input_data/expected_results/results_report.md` |
| 2 | Flags rows 1 to 4, Groups rows 1 to 3 | as in the project table | exact | same |
| 3 | `fixtures/golden.hex` | Dart pack equals the line; Dart unpack gives the AC-1 fields | exact | `fixtures/golden.hex` |
| 4 | The hostile cases (75 today) | the listed outcome term (any term of the `|` list) | exact (term set) | `fixtures/hostile/cases.txt`, `fixtures/hostile/README.md` |
| 5 | The ring payloads of every kind | the hex in `language-pair.sh`; the other eight unpack Dart's bytes | exact | `.github/workflows/language-pair.sh` |
| 6 | README data-type examples | the README hex | exact | `README.md` § Data types |
| 7 | TypeScript parity rows | TypeScript's hex or refusal | exact | `typescript/tests/` parity tables |
| 8 | 100,000 AC-1 round trips, compiled build | ≤ 1 second | threshold_max | AC-10 |
| 9 | Text rows `enc`, `alt`, `bad`, `ref`, `flip` | the bytes, text or refusal of each row | exact | `fixtures/text/vectors.txt` |
| 10 | ECC rows `enc`, `fix`, `bad`, `lim`, `par`, `lmt` and the percentage rows | the bytes, repaired count or refusal of each row | exact | `fixtures/ecc/vectors.txt`, `fixtures/ecc/percent-vectors.txt` |
| 11 | Crypto rows (27) | the digest, key or keystream of each row | exact | `fixtures/crypto/vectors.txt` |
| 12 | Frame rows (157) | the keys, sealed bytes, opened text, tag or refusal of each row | exact | `fixtures/frame/vectors.txt` |
| 13 | ECC and frame ring cases | the same answer from all nine drivers | exact | `fixtures/ecc/ring-cases.txt`, `fixtures/frame/ring-cases.txt` |
| 14 | `u64` wire bytes `ffffffffffffffff` | Dart `int` -1; packs back to the same 8 bytes | exact | DT-16 |
