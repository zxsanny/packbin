# Structure — 2026-10-19 loop 41 (covers loops 35 to 40)

| Metric | Value | Versus 2026-10-13 loop 24 |
|--------|-------|---------------------------|
| Components | 8 language packages (Swift added in loop 26), peers | +1 |
| Cross-component imports | 0 (each package imports only its standard library and its crypto dependency; ring drivers are test drivers) | 0 |
| Cycles | 0 | 0 |
| Contracts | 3 library contracts: `compact-text.md` (new, loop 35), `message-ecc.md` (new, loop 38), `pack-session.md` (changed: ECC over the padded bytes) | +2 |
| `shared/` | none; the shared wire rules live in `scripts/text/textfmt.py` and `scripts/ecc/eccfmt.py` (reference codecs, vectors) | 0 |

Loops 35 to 40 (`c365ae9..3e60df9`, 485 files, +39,941 / -1,073 lines) added two features to every package: compact text (loop 35) and message ECC (loop 38). Non-test source added per package: Python 12 files +912, TypeScript 6 +865, C# 11 +1,312, Java 13 +1,180, Rust 15 +1,407, Go 15 +1,205, Swift 14 +1,211, C++ include 7 +878 and src 8 +935. No changed non-docs file is over 500 lines except `README.md` (1,972, exempt as documentation) and `fixtures/hostile/README.md` (593, a case catalog). New reference tools: `scripts/text/` (format, tables, vectors, fuzz reference) and `scripts/ecc/` (codec, vectors, ring cases, fuzz reference).
