# Feature assessment — loop 97

loop: 97
feature: parity-percent
rounds: 2
verdict: COMPLETE
report_of_round: 2

## Round 1

**Date**: 2026-11-01
**Implement pass**: batches 01..05 and the C++ split, implementation report `_docs/03_implementation/implementation_report_parity-percent_loop97.md`
**Verdict**: CLARIFY — 11 covered / 1 out-of-scope / 2 gap-clear / 1 gap-unclear

### Coverage matrix

Test locations: each package has a percentage test file and a vector test (`python/tests/test_ecc_percent*.py`, `typescript/tests/ecc-percent.test.ts`, `csharp/tests/EccPercent*Tests.cs`, `java/.../Percent*Test.java`, `go/ecc_percent*_test.go`, `swift/Tests/PackbinTests/EccPercent*.swift`, `rust/tests/ecc_percent_tests.rs` + `nostd_ecc_percent_tests.rs`, `cpp/tests/core/ecc_percent*_host_tests.cpp`); the ring (`fixtures/ecc/ring-cases.txt`, 115 percentage rows) covers the wire between languages. Production code: the `parity_count` / `clear_length` / `protect_percent` family of each package (the file list is in `module-layout.md`, section Loop 97).

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | 25 % on a 40-byte message sends 10 parity bytes | covered | AC-1, AC-3; the `pct`/`encp` rows and the bytes-equal-fixed-count tests in every package; ring `ring.p25.enc` | intake |
| S2 | one scheme, messages of 10, 40, 100 bytes, the count follows each | covered | AC-1; the 22,752-pair round trip in every package | intake |
| S3 | two threads use one scheme | covered | AC-1 (pure function of L; schemes immutable); no shared state added in any package | intake |
| S4 | packet loses its last byte and the length is one no message has | covered | AC-5, AC-6; `inv`/`badp` nolen rows; ring `ring.p*.hostile.nolen*` | intake |
| S5 | packet loses bytes and the shorter length is valid again | covered | AC-5, AC-7; `badp` trunc/extend rows; ring `ring.p*.hostile.trunc*` | intake |
| S6 | permission denied | out-of-scope | scenarios.md S6: "Not applicable: no actor, no secret" | intake |
| S7 | 101 %, -1 %, percentage plus count in one constructor | covered | AC-9; `parp` rows and setter tests in every package; ring `par` rows | intake |
| S8 | limit above 16 or below 0; limit above n/2 lowered | covered | AC-8; `lmtp`, `fixp` t16 rows; ring `lmt` and `fix.t16` rows | intake |
| S9 | 0.4.0 sender with `with_parity(4)` and a new receiver | covered | AC-11; `vectors.txt` byte-identical; all old suites unchanged and green | intake |
| S10 | fleet moves from 25 % back to 0 % or a count | covered | AC-9, AC-14; contract 1.1.0 and README state both ends share the setting | intake |
| S11 | boundaries: L 0, largest L, largest + 1, N 254, N 255 | covered | AC-4, AC-6; `limp`, `inv` rows; codec-level L 0 (a scheme message always has a type byte, batch reports 02 and 03) | intake |
| S12a | dispatch needs one setting on all handlers, repair before dispatch | covered | AC-10; dispatch-mix tests in every package | intake |
| S12b | optional fields only change L and so n | gap-clear | quote: scenarios.md S12 "optional fields only change `L` and so `n`" → Given a scheme with an optional field under 25 %, When a message with the field and one without are packed and unpacked, Then the two carry their own counts (4 and 3 parity bytes for 13 and 10 clear bytes) and both round trip. No package tests a scheme whose message length varies by a field under a percentage (grep of the percentage tests) | assess-round-1 |
| S12c | compact text is read after the repair | gap-clear | quote: contract message-ecc "Compact text: A string in a protected message is read after the repair" and scenarios.md S12 "text is read after the repair" → Given a scheme with a string field under 25 % and one wrong byte in the string, When it is unpacked with a limit that repairs it, Then the string is the original. No percentage test uses a string field | assess-round-1 |
| D1 | `parp` pairs (percentage and count) cannot be declared in one constructor in Java, C#, Go, Swift, Rust, C++ | covered | AC-9 as written by the contract: last setter wins; tests in each package for both orders; Python and TypeScript refuse a pair in one call | batch_02, batch_03 |
| D2 | clear length 0 cannot be built through a scheme | covered | codec-level rows and tests; documented in the batch reports | batch_02, batch_03 |
| D3 | Swift DocC page and Go `doc.go` still describe only the count | out-of-scope | AZ-3509 `### Excluded`: "Any source change" (both files are in package source trees); recorded as a leftover | batch_05 |
| D4 | the dispatch-mix error cannot tell a percentage from a count with the same number | gap-unclear | question below | batch_03 |

### Gaps that need a decision (gap-unclear)

#### D4: how a refused dispatch mix names the two settings

**What is not decided**
When one unpack call is given handlers with different parity settings it is refused, and the error names the two settings. For a count the number shown is the count. For a percentage, Rust shows the percentage in the same two number fields and C++ shows 256 plus the percentage. So a handler with 25 percent and a handler with a count of 25 produce an error that reads "25 and 25" in Rust. The refusal itself is certain; only the wording of the error is in question, and the contract says only "refused as a mix of counts is".

**Options**
- **A — Keep, and say so in the README**: the error carries the number of whichever setting the handler has; the message text of the other packages already says "percent". Trade-off: one ambiguous case in Rust (percentage and count with the same number), no change to any public error type.
- **B — Make the Rust error unambiguous**: add a field or a variant for the kind of setting. Trade-off: a new field or variant breaks every exhaustive `match` on `UnpackError` in user code and in this repo's tests (`AGENT_GOTCHAS.md`, loop 69), for a case that is a programming mistake caught at once.

**Recommendation**: A — the mix is refused either way, and a public error type should not change for a wording case.

### Gaps that are clear (gap-clear)

| id | new AC (Given / When / Then) | quoted basis | proposed owner task |
|----|------------------------------|--------------|---------------------|
| S12b | Given a scheme with an optional field under 25 %, When a message with the field and one without are packed and unpacked in each package, Then each carries its own parity count and both round trip | scenarios.md S12 | new task, one test per package |
| S12c | Given a scheme with a string field under 25 %, When one byte of the string is wrong and the limit repairs it, Then the string is the original; in a build without compact text the same holds for a bytes field | contract message-ecc "Compact text" | same task |

### Not walked

- Percentage together with `max_bytes`/`max_rounds` limits (the setters keep the percentage: covered by the setter tests, not walked further).
- A hostile received length at the 16-bit boundary on AVR (the Uno build leaves ECC out).

### Harness gaps

- none: all five batch reports have the discoveries table.

## Round 2

**Date**: 2026-11-01
**Implement pass**: batch 06 (AZ-3511, AZ-3512, AZ-3513), report `_docs/03_implementation/batch_06_loop97_report.md`
**Verdict**: COMPLETE — 14 covered / 2 out-of-scope / 0 gap-clear / 0 gap-unclear

### Coverage matrix (rows changed since round 1)

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S12b | optional field: each message carries its own count | covered | AC-17; tests `python/tests/test_ecc_percent_fields.py`, `typescript/tests/ecc-percent-fields.test.ts`, `csharp/tests/EccPercentFieldsTests.cs`, `java/.../PercentFieldsTest.java`, `go/ecc_percent_fields_test.go`, `swift/.../EccPercentFieldTests.swift`, `cpp/tests/core/ecc_percent_fields_host_tests.cpp`, `rust/tests/ecc_percent_tests.rs` + `nostd_ecc_percent_tests.rs` (17 and 13 sent bytes); production code is the per-message count in each package's pack | assess-round-1 |
| S12c | string read after the repair | covered | AC-18; the same files (every byte position corrupted in turn in Python, Go, Swift, C++; one byte in the others); the `PACKBIN_NO_TEXT` bytes branch of C++ is syntax-checked only (batch 06) | assess-round-1 |
| D4 | the dispatch-mix error tells a percentage from a count | covered | AC-19; Rust `UnpackError::MixedParity { first, other, first_percent, other_percent }` (`rust/src/value.rs`, `ecc.rs`, test `ecc_percent_tests.rs`); texts: Python "25 percent and 25", TypeScript "25 percent … 25 parity bytes", C# "25 percent and 25 parity bytes", Java "25 percent parity and 25 parity bytes", Go "25 parity bytes at 0 percent", Swift "25 percent and 25 parity bytes", C++ offset 281 and needed 25 | assess-round-1 |

All other rows are as in round 1. Not walked: unchanged.
