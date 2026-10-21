# Expected results — loop 56

| Input | Expected output |
|-------|-----------------|
| Cortex-M4F flash image after the saving | at most 8040 B |
| Cortex-M4F flash image after the fold | at most 8120 B |
| Stack, 3-deep `when` chain / flag-byte chain | at most 504 B / 500 B |
| Stack, 3-deep chain through a `times` round | measured, at most 512 B |
| `cases.txt` with one extra valid line | Go, Swift and Rust loaders report the missing handler by case id, not a count mismatch |
| `cases.txt` with one line removed | the loaders report the unused handler by case id |
| Every packet of the hostile and differential corpora | byte-identical to HEAD |
