# Expected results — Go package (loop 24)

Go reuses the shared fixtures; it adds no new input data. Comparison is `exact` unless stated.

| # | Input | Expected result | Comparison | Reference file |
|---|-------|-----------------|------------|----------------|
| 1 | Position fixture rows 1 to 3 | as in the project table | exact | `_docs/00_problem/input_data/expected_results/results_report.md` |
| 2 | Flags rows 1 to 4, Groups rows 1 to 3 | as in the project table | exact | same |
| 3 | `fixtures/golden.hex` | Go pack equals the line; Go unpack gives the AC-1 fields | exact | `fixtures/golden.hex` |
| 4 | 65 hostile cases | the listed outcome term (any term of the `|` list) | exact (term set) | `fixtures/hostile/cases.txt`, `fixtures/hostile/README.md` |
| 5 | 15 ring payloads (`user` … `listflags_short`) | the hex in `language-pair.sh`; the other six unpack Go's bytes | exact | `.github/workflows/language-pair.sh` |
| 6 | Session seed, 16-byte value, position row | C#'s ciphertext | exact | `_docs/02_task_plans/pack-session/input_data/expected_results/results_report.md` |
| 7 | README data-type examples | the README hex | exact | `README.md` § Data types |
| 8 | TypeScript parity rows (U1 to U26) | TypeScript's hex or refusal | exact | `typescript/tests/` parity tables |
| 9 | 100 000 AC-1 round trips | ≤ 1 second | threshold_max | AC-10 |
