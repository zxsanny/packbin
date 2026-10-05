# Code Review Report
**Batch**: AZ-2061 | **Date**: 2026-10-04 | **Verdict**: PASS_WITH_WARNINGS

## Findings
| # | Severity | Category | File:Line | Title |
|---|----------|----------|-----------|-------|
| 1 | Low | Maintainability | cpp/src/core/walk.cpp | Kinds not built yet return `SchemeInvalid` from the walker |

### Finding Details
**F1: Kinds not built yet return `SchemeInvalid`** (Low / Maintainability)
- Location: `pack_one` / `unpack_one` default branch.
- Description: no builder creates those kinds yet, so the branch cannot be reached from a scheme. AZ-2062 and AZ-2063 add them.
- Suggestion: keep the default branch as the guard for a corrupt runtime table once every kind exists.
- Task: AZ-2061

## Notes

- Spec compliance: AC-1 (`ac1_unknown_type_number`), AC-2 (`ac2_matching_type_number`), AC-3 (four compile-fail cases; GCC 16 and Clang 21 both print the id), AC-4 (`ac4_runtime_order_errors`, pack writes 0 bytes) all have tests.
- No `std::function`: rows are bound by template accessor function pointers in a `constexpr` table; handlers are template parameters.
- Core profile kept: new headers include only `<array>`, `<cstddef>`, `<cstdint>`, `<cstring>`, `<type_traits>`; sources build with `-fno-exceptions -fno-rtti`.
- One walker serves constant and runtime-built tables (D-1 A).
