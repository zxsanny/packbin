# Batch Report

**Batch**: 1 (python, typescript, rust, csharp and java run as one wave of parallel workers; fixes applied after review)
**Tasks**: AZ-2071_python_hostile_unpack, AZ-2072_typescript_hostile_unpack, AZ-2073_csharp_hostile_unpack, AZ-2074_java_hostile_unpack, AZ-2075_rust_hostile_unpack, AZ-2076_csharp_unpack_state_per_call, AZ-2077_java_unpack_state_per_call
**Date**: 2026-10-05

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2071_python_hostile_unpack | Done | 4 files (1 src, 3 tests) | 71/71 pass | None |
| AZ-2072_typescript_hostile_unpack | Done | 5 files (2 src, 3 tests) | 68/68 pass | None |
| AZ-2073_csharp_hostile_unpack | Done | 6 files | 115/115 pass (with 2076) | None |
| AZ-2074_java_hostile_unpack | Done | 7 files | java/test.sh green (37 methods + 10 vectors) | None |
| AZ-2075_rust_hostile_unpack | Done | 7 files | 70/70 pass (all targets) | None |
| AZ-2076_csharp_unpack_state_per_call | Done | 5 files | 0 wrong in 2x200 000 race, both flag forms | None |
| AZ-2077_java_unpack_state_per_call | Done | 5 files | 0 wrong, 0 errors in 2x200 000 race | None |

## Code Review Verdict: PASS_WITH_WARNINGS

Four fresh-reviewer reports (python+typescript, csharp, java, rust). No Critical or High. Medium findings and their outcome:

- Zero-width `times` body with a huge count hangs or runs out of memory (python, typescript, csharp, java; rust's early stop shortened the list): owner chose A, a `times` round that reads 0 bytes returns the interim error in all five. Fixed with failing-first tests.
- Rust `packed` count of 2^63 or more wrapped to a small valid count; 32-bit `usize` arithmetic could overflow: fixed with `try_from` / `checked_add` / `checked_mul`.
- TypeScript `bits` with a u64 (bigint) count regressed on a packet that unpacked before: restored for counts up to MAX_SAFE_INTEGER.
- Java `list(list(bool))` zero-width elements can amplify memory (pre-existing, code moved unchanged): recorded as a follow-up, not fixed.
- Low findings fixed: test strength (python, java, rust), `(int)` narrowing guards (csharp, java), dead field, comment accuracy, `Scope` into its own file, `BadValue` helper renamed `InterimBadValue`, mod order.

## Test Suite

CI-parity (Docker, `docker-compose.test.yml`, all six languages): PASS. Plus `fixtures/hostile/cases.test.sh` and `.github/workflows/report-row.test.sh`: PASS.
CI-parity: PASS — `docker compose -f docker-compose.test.yml run --rm {csharp,typescript,python,rust,cpp,java}`, `bash fixtures/hostile/cases.test.sh`, `bash .github/workflows/report-row.test.sh`.

- Python 71 passed, 0 failed
- TypeScript 68 passed, 0 failed
- C# 115 passed, 0 failed
- Rust 70 passed (51 lib, 6, 10, 4), 0 failed
- Java: all 4 runners pass
- C++: all tests passed (untouched)

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | `left` and label on the interim error are each package's own choice (utf8: bytes left at the length prefix; counts: at the counted field; `times` label differs by package: python anchor id, typescript first body name, csharp/java/rust "times") | AZ-2071..2075 interim mapping | One definition when C15 lands; each package keeps one helper to change (python `error_kind`, csharp `InterimBadValue`) | unclear |
| 2 | Zero-width `times` round is an error even for small counts, e.g. count 3 of a never-matching `when` | owner decision, loop 11 | Done; AZ-2073/2074 accepted-risk rows marked resolved | clear |
| 3 | `list(list(bool))` / zero-width list or dict elements: up to 65535 x 65535 empty rounds | AZ-2074 | Follow-up task (pre-existing in moved Java code; same shape likely in the other packages) | unclear |
| 4 | Rust pack side `borrowed_count` still does unchecked `raw as i64 + bias` | AZ-2075 | Follow-up (pack, caller-supplied input) | unclear |
| 5 | AZ-2075 spec AC-4 said `Trailing { left: 2 }` for `01 05 09`; correct is `left: 1` | AZ-2075 AC-4 | Spec corrected | clear |
| 6 | AZ-2076/2077 say to take split-form bytes from TypeScript/Python tests; none exist. Bytes came from the Rust vector and AZ-2100's quoted TypeScript output | AZ-2076 AC-5, AZ-2077 AC-4 | Add split-form tests to TS/Python (AZ-2100 area) | unclear |
| 7 | C# boxes every scalar as Double (u64/i64 above 2^53 lose precision); counts are clamped around it | AZ-2073 | Separate ticket | unclear |
| 8 | Name-based (non-numeric) references are not scope-checked in Rust; the runtime zero-progress guard covers the hang | AZ-2075 | Track names per scope if wanted | unclear |
| 9 | Orphan flag bit (flag byte never read in scope) now reads as clear in C# and Java instead of a stale value | AZ-2076, AZ-2077 | Construction-time rejection belongs to task 20 / 13 | clear |
| 10 | TypeScript `src/walker.ts` is 492 lines, Rust `field/mod.rs` 494 | quality cap 500 | Split on the next change that touches them | clear |

## Commit

`[AZ-2071] [AZ-2072] [AZ-2073] [AZ-2074] [AZ-2075] [AZ-2076] [AZ-2077] Unpack hostile packets as errors, keep flag state per call`

## Next Batch: All tasks complete
