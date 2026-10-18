# Expected results — compact strings

Each pair gives the upper bound on the whole encoded field, header included, from the research run (`research_report.md`).

| # | Input string | UTF-8 field today (2-byte count + bytes) | Compact field, upper bound (measured with the B scheme) | Round trip |
|---|--------------|------------------------------------------|---------------------------------------------------------|-----------|
| 1 | `привіт` | 14 B | ≤ 6 B (6) | same string |
| 2 | `привіт! координати: 48.46, 35.04 ok?` | 54 B | ≤ 36 B (35) | same string |
| 3 | `hello, world` | 14 B | ≤ 9 B (9) | same string |
| 4 | `Привіт` (capital) | 14 B | ≤ 6 B (6) | same string |
| 5 | `привіт 😀` (emoji) | 19 B | ≤ 12 B (11 to 12) | same string |
| 6 | `` (empty) | 2 B | ≤ 2 B (2) | same string |
| 7 | `ПРИВІТ, СВІТЕ!` (capital run) | 27 B | ≤ 13 B (13) | same string |
| 8 | `zażółć gęślą jaźń` (Polish, not in the table) | 28 B | ≤ 30 B (raw UTF-8 fallback; 42 without it) | same string |
| 9 | 300 × `x` | 302 B | ≤ 304 B (raw fallback; 378 without it) | same string |

Rows 5 and 8 take the escape or the raw fallback. Exact bytes are fixed when the format is frozen (goldens in `fixtures/`).
