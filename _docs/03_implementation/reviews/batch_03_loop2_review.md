# Code Review Report
**Batch**: AZ-1940_dictionary | **Date**: 2026-09-23 | **Verdict**: PASS_WITH_WARNINGS

## Findings
| # | Severity | Category | File:Line | Title |
|---|----------|----------|-----------|-------|
| 1 | Medium | Maintainability | python/src/packbin/__init__.py:1 | Python packer stays over the 500-line cap |
| 2 | Medium | Maintainability | typescript/src/index.ts:1 | TypeScript packer stays over the 500-line cap |
| 3 | Medium | Maintainability | rust/src/walk.rs:1 | Rust walker stays over the 500-line cap |
| 4 | Medium | Maintainability | cpp/src/packbin.cpp:1 | C++ packer crossed the 500-line cap |
| 5 | Medium | Maintainability | rust/tests/packbin_tests.rs:1 | Rust tests stay over the 500-line cap |
| 6 | Medium | Maintainability | csharp/tests/PackbinTests.cs:1 | C# tests stay over the 500-line cap |
| 7 | Medium | Maintainability | java/src/test/java/packbin/PackbinTest.java:1 | Java tests stay over the 500-line cap |
| 8 | Medium | Maintainability | cpp/tests/packbin_tests.cpp:1 | C++ tests crossed the 500-line cap |

### Finding Details
**F1: Python packer stays over the 500-line cap** (Medium / Maintainability)
- Location: `python/src/packbin/__init__.py`
- Description: The dictionary branch landed in the same module. `dict` is the field helper, so builtin `dict` checks go through `_builtin_dict`.
- Suggestion: Split pack and unpack in a later pass.
- Task: AZ-1940

**F2: TypeScript packer stays over the 500-line cap** (Medium / Maintainability)
- Location: `typescript/src/index.ts`
- Description: The dict switch stays with the other field kinds.
- Suggestion: Leave the switch with the other field kinds until a later split.
- Task: AZ-1940

**F3: Rust walker stays over the 500-line cap** (Medium / Maintainability)
- Location: `rust/src/walk.rs`
- Description: Pack and unpack of `FieldKind::Dict` sit in the same walker as the list arms.
- Suggestion: Split pack and unpack in a later pass.
- Task: AZ-1940

**F4: C++ packer crossed the 500-line cap** (Medium / Maintainability)
- Location: `cpp/src/packbin.cpp`
- Description: The dictionary pack and unpack arms added enough lines to pass 500.
- Suggestion: Move the dictionary arms next to the other counted fields in a later pass.
- Task: AZ-1940

**F5: Rust tests stay over the 500-line cap** (Medium / Maintainability)
- Location: `rust/tests/packbin_tests.rs`
- Description: `dictionary_field` was added to the existing suite file.
- Suggestion: Split the suite by field kind in a later pass.
- Task: AZ-1940

**F6: C# tests stay over the 500-line cap** (Medium / Maintainability)
- Location: `csharp/tests/PackbinTests.cs`
- Description: `CountedDict` was added to the existing suite file.
- Suggestion: Split the suite by field kind in a later pass.
- Task: AZ-1940

**F7: Java tests stay over the 500-line cap** (Medium / Maintainability)
- Location: `java/src/test/java/packbin/PackbinTest.java`
- Description: `dictionary` was added to the existing suite file.
- Suggestion: Split the suite by field kind in a later pass.
- Task: AZ-1940

**F8: C++ tests crossed the 500-line cap** (Medium / Maintainability)
- Location: `cpp/tests/packbin_tests.cpp`
- Description: `dictionary` was added to the existing suite file.
- Suggestion: Split the suite by field kind in a later pass.
- Task: AZ-1940

## Spec
AC-1 is the 103-byte user hex. AC-2 inserts `store`, `channel`, `map` and matches AC-1. AC-3 unpacks that hex to the username, both roles, and the three access lists with no bytes left. AC-4 is `000000000000`. AC-5 unpacks a repeated key as an error and 0 values. A 65536-pair pack fails before a buffer is returned. `repeat` is rejected as an element. Two packs, including two callers at once, mismatch on 0 bytes.
