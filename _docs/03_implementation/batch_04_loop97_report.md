# Batch 04 report — loop 97

Task: AZ-3508 (ECC ring rows and the eight drivers, 5 points). The harness, generator and self-test by the parent; the eight drivers by four workers (two languages each), re-run together by the parent.

| Check | Result |
|-------|--------|
| `.github/workflows/ring-ecc.test.sh` (stand-in drivers) | passed, including 3 new cases: a writer that writes a wrong 25 % message, a reader that rounds the count down, a reader that never lowers the limit |
| Real ring, all 8 languages, fresh work dir | `ring-ecc: 64 pairs, 52800 rows, mismatched rows: 0` (16 protect rows and 809 repair rows for each of 8 writers; 377 rows in `ring-cases.txt`, 115 of them under a percentage) |
| Mutation proof (AC-3) | Go package `percentCount` rounding down (`+99` removed): the real ring for Go turned red, 17 mismatched rows naming `ring.p10.enc`, `ring.p25.enc`, `ring.p50.enc`, `ring.p10.fix.*`; reverted, `go/ecc_percent.go` has no diff |
| Old rows | `ring-cases.txt` old rows byte-identical (0 removed lines in the diff); `vectors.txt` untouched |

Review: code-review (low) 0 findings. CI-parity: PASS (`ring-ecc.test.sh` and the real full ring; both run by CI's ring jobs / the publish gate layout).

Behavior notes for the record:
- TypeScript driver: a count word that is not an integer (for example `25p`) is now a malformed line; before it was read as NaN. Stricter, no valid line changes.
- Malformed `p<N>` words exit non-zero in all eight drivers and name the word; Python, C# and Java use their own number-parse exception for `p` and `25p`.
- Rust driver checks the percentage against 100 before `with_parity_percent`, which panics above 100.

## Discovered during implementation

| Spec ref | Discovery | Proposed handling | clear/unclear |
|----------|-----------|-------------------|---------------|
| AC-1 (largest message rows) | The ring drives the 13-byte position message, so the largest-clear-length rows cannot be built through a driver | covered by `limp` vectors and the package tests; AC-1 wording of the task kept, this line is the waiver | clear |
| AC-3 | The mutation proof was done on the Go package (the driver passes through to it), not on the driver text | accepted | clear |
