# Code Review Report
**Batch**: AZ-1946 | **Date**: 2026-09-24 | **Verdict**: PASS_WITH_WARNINGS

## Findings
| # | Severity | Category | File:Line | Title |
|---|----------|----------|-----------|-------|
| 1 | Low | Scope | python/src/packbin/__init__.py:1 | Scheme.of takes the row type |
| 2 | Low | Scope | java/src/main/java/packbin/Scheme.java:1 | Scheme.of takes Class |

### Finding Details
**F1: Python Scheme.of takes the row type** (Low / Scope)
- Location: `python/src/packbin/__init__.py`
- Description: `Scheme.of(MarkerRow, TypeNum.set(32), u8("sid"))` passes the class so unpack can construct `T`. The C# example uses only the type parameter.
- Suggestion: Keep it. Python has no reified `T`.
- Task: AZ-1946

**F2: Java Scheme.of takes Class** (Low / Scope)
- Location: `java/src/main/java/packbin/Scheme.java`
- Description: `Scheme.of(MarkerRow.class, ...)` is required under erasure.
- Suggestion: Keep it.
- Task: AZ-1946

## Spec
Pack and unpack take the scheme. Marker rows declare only `sid`. Missing scheme fails the compiler (Python: TypeError). Wrong type byte returns no row. Untyped pack remains. Rust and C++ bind the member at the scheme site. No registry.
