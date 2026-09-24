# Code Review Report
**Batch**: AZ-1949 | **Date**: 2026-09-24 | **Verdict**: PASS_WITH_WARNINGS

## Findings
| # | Severity | Category | File:Line | Title |
|---|----------|----------|-----------|-------|
| 1 | Low | Style | rust/src/lib.rs:11 | Rust dispatch is unpack_with, values path is MapScheme |

### Finding Details
**F1: Rust names differ from the C# call shape** (Low / Style)
- Location: `rust/src/scheme.rs` `unpack_with`; `rust/src/field.rs` `MapScheme`
- Description: Rust has no variadic functions and no overloads. Dispatch is `unpack_with`. Named-field layouts are `MapScheme` plus `pack_map` / `unpack_map`. `Scheme<T>` remains the typed layout. Packet, BinaryPacker, and type_num are gone.
- Suggestion: leave the names. A macro would only add a second spelling.
- Task: AZ-1949

AC-1 through AC-6 are tested in each language. AC-2 and AC-4 hex match across all six: `4001000065cd1d00a3e1110100` and `02070000000800000009000000`. No file in the six packages exceeds 500 lines. Packages do not import each other.
