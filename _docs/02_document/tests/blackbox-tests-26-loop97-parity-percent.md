# Blackbox Tests 26: parity as a percentage (loop 97, FT-X-169 to FT-X-172, FT-E-16)

Source: tasks AZ-3499 to AZ-3509 and the assessment round AZ-3511 to AZ-3513, acceptance criteria AC-1 to AC-19 (`_docs/02_task_plans/parity-percent/acceptance_criteria.md`), contract `message-ecc.md` 1.1.0, ADR-010.

## FT-X-169: the count, the bytes and the largest message

| Item | Value |
|------|-------|
| Input | `fixtures/ecc/percent-vectors.txt` (1,032 rows: `pct`, `encp`, `inv`, `limp`, `fixp`, `badp`, `parp`, `lmtp`); every percentage 0 to 100 against every clear length 0 to its largest (22,752 pairs, 0 to 254 for percentage 0) |
| Expected | `n = min(32, (p × L + 99) div 100)`; the sent bytes are the clear bytes then the parity of a fixed count with that `n` (p 8, 30, 60 on the 13-byte fixture equal `enc.pos.n2`, `n4`, `n8`); the largest clear message is 251, 230, 222, 222, 222 for p 1, 10, 25, 50, 100 and the next length is refused naming the length and the limit; the sent length gives back one clear length; 3, 24, 32, 32 and 32 of the lengths 0 to 254 are impossible for p 1, 10, 25, 50, 100 and are `uncorrectable` |
| Run by | the reference check (`fixtures/ecc/check-vectors.sh`, with the sweep of 22,752 pairs; self-test `check-vectors.test.sh`, 11 cases); each package's percentage test and vector test: Python `test_ecc_percent.py`, `test_ecc_percent_vectors.py`; TypeScript `ecc-percent.test.ts`; C# `EccPercentTests.cs`, `EccPercentVectorTests.cs`; Java `PercentSchemeTest.java`, `PercentVectorsTest.java`; Go `ecc_percent_test.go`, `ecc_percent_vectors_test.go`; Swift `EccPercentTests.swift`, `EccPercentVectorTests.swift`; Rust `ecc_percent_tests.rs` (module and `tests/`), `nostd_ecc_percent_tests.rs`; C++ `ecc_percent_host_tests.cpp`, `ecc_percent_vectors_host_tests.cpp` |
| Not run by | a scheme message of clear length 0 (a scheme message always has a type byte: covered at the codec level) |

## FT-X-170: setting, percentage 0, last setter wins and dispatch

| Item | Value |
|------|-------|
| Input | a percentage of 101 or -1; a percentage and a count in one constructor or call; setters in both orders; percentage 0; handlers of one percentage, of two percentages, of a percentage and a count of the same number (25 and 25) |
| Expected | outside 0 to 100, or both above 0 in one constructor, refused when the scheme is built as the package refuses a bad `parity`; elsewhere the last setter wins and the other limit setters keep the setting; percentage 0 is a scheme without parity (the dispatch setting and the limit rule of count 0); a mix is refused before any byte is read; the refusal tells which setting is the percentage (Rust `MixedParity { first: 25, other: 25, first_percent, other_percent }`, C++ `offset` 281 and `needed` 25, the other packages by text: "25 percent … 25 parity bytes") |
| Run by | the package files of FT-X-169 and, for the mix error, Python `test_ecc_percent_fields.py`, TypeScript `ecc-percent-fields.test.ts`, C# `EccPercentFieldsTests.cs`, Java `PercentFieldsTest.java`, Go `ecc_percent_fields_test.go`, Swift `EccPercentFieldTests.swift`, C++ `ecc_percent_fields_host_tests.cpp`, Rust `ecc_percent_tests.rs` |

## FT-X-171: repair under a percentage and the correction limit

| Item | Value |
|------|-------|
| Input | 50 % of a 40-byte message (20 parity bytes) with 10 wrong bytes at limit 10, the seeded 11-byte and 20-byte corruptions at limits 10 and 0; 25 % of 40 bytes with 5 wrong bytes at limit 5 and at limit 16; limits -1, 17 and 100 |
| Expected | repaired with the real count (10 and 5); the seeded corruptions are `uncorrectable`; limit 16 on the 40-byte message at 25 % behaves as limit 5; a limit outside 0 to 16 is `bad_limit` before any byte is read; the repaired count is the real one |
| Run by | the `fixp`, `badp` and `lmtp` rows in every package (FT-X-169 files) |

## FT-X-172: variable-length messages, strings, and the eight languages together

| Item | Value |
|------|-------|
| Input | a scheme with an optional field at 25 % (13 clear bytes with it, 10 without); a string field at 25 % with one wrong byte (and every byte position in Python, Go, Swift, C++); the ECC ring with 377 rows, 115 of them under p10, p25, p50, p100 |
| Expected | the two messages are 17 and 13 bytes (4 and 3 parity bytes) and both round trip; the string is the original after the repair; every writer is read by every reader: 64 pairs, 52,800 rows, 0 mismatched; a Go package that rounds the count down turns the ring red naming `ring.p10.enc`, `ring.p25.enc`, `ring.p50.enc` and the `ring.p10.fix.*` rows |
| Run by | the files of FT-X-170 (fields); `.github/workflows/ring-ecc.sh` with `fixtures/ecc/ring-cases.txt`, self-test `.github/workflows/ring-ecc.test.sh` (stand-in drivers that lie about the writer, round down, or never lower the limit) |
| Not run by | the `PACKBIN_NO_TEXT` bytes branch of the C++ string test (syntax-checked, not run); a device (the embedded images prove size, stack and link, not the percentage behavior) |

## FT-E-16: Cortex-M33F pins after the percentage

| Item | Value |
|------|-------|
| Input | the `cpp-m33f` and `rust-m33f` rows (`cpp/embedded/run.sh`, `docker compose … rust-embedded`) |
| Expected | C++ all-kinds image 25,948 B flash and 740 B stack (was 25,760 B and 724 B: +188 B, +16 B); Rust `ecc` set 19,140 B and 752 B (was 18,764 B and 744 B: +376 B, +8 B); the Rust base, text and frame sets, the C++ frame image (8,416 B, 912 B), the string-free ECC-free image (21,688 B) and the Uno example (15,402 B) unchanged; the same figures after the split of `codec.hpp` and after the Rust error flags |
| Run by | the workers of AZ-3506, AZ-3507, AZ-3511 (batch reports 03 and 06); not re-run by the parent |
