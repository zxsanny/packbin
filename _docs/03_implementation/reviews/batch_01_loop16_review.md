# Code Review Report

**Batch**: 1 (loop 16): AZ-2112, AZ-2102, AZ-2185 (TypeScript); AZ-2118, AZ-2105, AZ-2117 with AZ-2121 AC-3, AZ-2189 (Rust); AZ-2127, AZ-2187, AZ-2190 (Java); AZ-2113, AZ-2104, AZ-2186, AZ-2192 (Python) | **Date**: 2026-10-06 | **Mode**: Full, one read-only reviewer per package, each with mutation checks on scratch copies | **Verdict**: PASS_WITH_WARNINGS (after fixes; the first Python verdict was FAIL)

Verdicts as first reported: TypeScript PASS_WITH_WARNINGS, Rust PASS_WITH_WARNINGS, Java PASS_WITH_WARNINGS, Python FAIL (one High). All High and the owner-decided Medium were fixed in the batch; the remaining Mediums are pre-existing and owned by a later spec.

## Findings and disposition

| # | Pkg | Severity | Category | Title | Disposition |
|---|-----|----------|----------|-------|-------------|
| PY-F1 | Python | High | Spec-Gap (changed existing test) | `test_never_matching_when_element_is_error` lost its unpack assertions | FIXED, owner approved (A): construction-refusal test kept, ported unpack test `test_never_matching_when_in_a_group_element_is_error` added with the original bytes |
| JA-F1 | Java | Medium | Bug | An inner `repeat` written under more than one outer round packs bytes that unpack reads back differently | FIXED, owner decided option A: pack throws when the same inner `repeat` is written a second time in one call; gap left (see Open) |
| TS-F1 | TypeScript | Medium | Bug / Spec-Gap (risk 2) | Dict-of-group entry members overwrite same-named row members on pack (key-order dependent) | Pre-existing (identical bytes at HEAD, not widened); owned by AZ-2184 in batch 2, whose tests must cover both key orders |
| RU-F1 | Rust | Low | Bug | `check_aligned` refused an empty list that loses nothing | FIXED (empty list packs as at HEAD; non-empty still refused); same-name outer-field limit recorded |
| RU-F4 | Rust | Low | Maintainability | Three duplicated count arms in `check_one` | FIXED (one arm; the refusal owner text now reads `the count of "<name>"`) |
| JA-F3 | Java | Low | Bug | f32 and f64 wrote infinity for a finite oversize `BigInteger` / `BigDecimal` | FIXED (only a `Float` / `Double` that is itself infinite is an explicit infinity) |
| JA-F4 | Java | Low | Bug | A `Number` with null `toString()` threw NPE | FIXED (`IllegalArgumentException` naming the field) |
| JA-F5 | Java | Low | Maintainability | Times-too-long message named `-1` for a member without a field id | FIXED (named by its kind) |
| TS-F2 | TypeScript | Low | Bug | Member-name collision check does not enter list / dict element scopes | Carried to AZ-2188 (batch 2) |
| TS-F4 | TypeScript | Low | Test gap | No test for a negative or i64-min count | Carried to batch 2 TypeScript worker |
| JA-F2 | Java | Low | Bug (pre-existing) | `flags(.., repeat/times)` drops the group silently | Pre-existing at HEAD; belongs to the AZ-2128 open concern (owner) |
| JA-F6 | Java | Low | Spec-Gap | `ac3BytesMatchCpp` only re-asserts AC-1's bytes | Accepted: the cross-language proof is the ring (AZ-2193) |
| PY-F3 | Python | Low | Security (pre-existing) | `PackSession.load(32)` returns a session keyed by 32 zero bytes | Open for the owner (spec says `load` is unchanged) |
| PY-F4 | Python | Low | Spec ambiguity | Over-long list under a `when` that never matches is refused | Accepted: parity with TypeScript `refuseLongLists` |
| RU-F2 | Rust | Low | Scope (C15) | Label text of `PackError::Type` changed for counts of 2^63 or more | Accepted: kind unchanged; noted in the batch report |
| PY-F2, RU-F3, TS-F3 | docs | Low | Maintainability | README and `04_rust_package/description.md` stale for Python references, Java nested rounds, AZ-2105, AZ-2189, `times` longer list; three README snippets break under `import *` | Step 13 docs pass |

## Existing tests changed by the workers: kept intent or weakened

- Python `hostile_support.zero_progress_when`, `times_zero_width`: kept (same bytes and results, zero-width `bytes` field plus in-round `when`).
- Python `test_never_matching_when_element_is_error`: weakened, then restored by the added ported test (PY-F1).
- Rust `packbin_tests::split_flag_byte_and_be`: kept (undeclared `"type"` renamed to the declared `"motion"`, same bytes `01015a00`); session tests `ac4_bad_lengths_create_nothing` and `times_shapes_tests` session assertion: kept and stronger (`Err(..)` instead of `is_none()`).
- Java `RepeatRoundTest.nestedRoundsAreRefused` (deleted) and `HostileUnpackTest` "times body of a repeat is refused": spec-sanctioned reversal (AZ-2127); the hostile test now builds the scheme and checks two real unpacks.
- TypeScript: two stale comment lines only.

## Mutation checks

Done by the reviewers on scratch copies (each undo failed its AC tests): TypeScript six (u64 counts, longer list, element packing, flags element, non-object item), Rust five (name scope, checked count, aligned `times`, session counter, element scope), Java six (nested rounds, fold into outer round, nested-row target, longer list, BigInteger width, f32 overflow), Python ten (reference scope variants, longer-list pre-pass, float strictness, seed check, `__all__`).

## Evidence beyond tests

Differential checks against HEAD: TypeScript 160k count cases and 48k pack cases (only the intended refusals differ); Java 11,774 scalar pairs and about 30,000 random schemes (identical bytes; 955 intended refusals); Python 18,000 `times` rows and 6,000 float values (zero byte changes); Rust about 38 map and typed schemes (two schemes that could not round-trip are now refused). Hostile unpack: TypeScript about 1.4M inputs, Java 300,000, no throw, no hang; loop 15 round and slot limits still trip on inner rounds.

## Not checked

Cross-language rings and the Docker suites by the reviewers (the parent ran them: see the batch report); `csharp/**` and the owner's uncommitted work.
