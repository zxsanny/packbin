# Code Review Report
**Batch**: AZ-1950 | **Date**: 2026-09-24 | **Verdict**: PASS_WITH_WARNINGS

## Findings
| # | Severity | Category | File:Line | Title |
|---|----------|----------|-----------|-------|
| 1 | Low | Style | csharp/Field.cs:1 | C# field helpers need an explicit row type argument |
| 2 | Medium | Spec-Gap | rust/src/scheme/bound.rs:1 | Typed Rust binders omit u2 and dict |

### Finding Details
**F1: C# call sites name the row type** (Low / Style)
- Location: `csharp/tests/FieldIdBindingTests.cs` `Field.U16<MarkerRow>`
- Description: `params Field[]` does not infer `T` from the lambda. The spec sample omits the type argument.
- Suggestion: leave the type argument. The binding and the bytes are the same.
- Task: AZ-1950

**F2: Rust typed fields skip u2 and dict** (Medium / Spec-Gap)
- Location: `rust/src/scheme/bound.rs`
- Description: Value maps still build `u2` and `dict` by name. `BoundField` has no u2 or dict constructor, so a typed row cannot bind those kinds by order id.
- Suggestion: add those binders before calling the task complete if a typed u2 or dict row is required. The marker AC-1 bytes do not use them.
- Task: AZ-1950

AC-1 hex `2001000065cd1d00a3e111010000000000` is asserted in C#, TypeScript, Python, Rust, C++, and Java.
