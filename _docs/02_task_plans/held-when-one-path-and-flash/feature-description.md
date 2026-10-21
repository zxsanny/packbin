# Feature — held-`when` single path, flash saving, derived corpus counts

Total 8 points, three tasks. Epic AZ-2645. Source: `problem.md` and `acceptance_criteria.md` in this folder.

1. **A, C++ flash saving (3 points).** `reads_flag_byte` rescans a `when`'s entries on every unpack call. Replace it with an answer set when the scheme resolves (a bit in `Field::flags`; 128 is free; `Field` must stay 16 bytes before `eq`). Flash image at most 8040 B. Packets unchanged.
2. **B, one path for held whens (3 points, after A).** Fold the `When` and `FlagBit` handling of `unpack_children` and `unpack_one` into one function; flash at most 8120 B, stack not above 504 B / 500 B; measure the chain through a `times` round (at most 512 B) and record it. If the flash does not allow the fold, do not make it and record the figures.
3. **C, derived counts (2 points, independent).** Go, Swift and Rust loaders of `fixtures/hostile/cases.txt` derive the case count from the file and report a missing or unused handler by case id; shown with a broken copy.

## Scenarios

See `scenarios.md` (all rows confirmed, X1 out of scope).

## Fit decisions

None: no wire or public API change.
