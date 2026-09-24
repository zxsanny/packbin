# Feature assessment — loop 4 round 1

verdict: COMPLETE
round: 1

scenarios.md absent (pre-4.7 spec). Intent is AZ-1945 and AZ-1946.

## Coverage

| Row | Status | Cite |
|-----|--------|------|
| Constant type byte 32 + sid 23 is `2017` | covered | AC-1; `csharp/tests/TypeNumTests.cs`; `Walker` type-number pack |
| Unpack drops the type member | covered | AC-2; TypeNum tests in each language; unpack does not insert a name |
| Wrong byte 33 yields expected 32, actual 33, no value | covered | AC-3; TypeNum tests; `TypeMismatch` / `UnpackError::Type` |
| No type number keeps the golden fixture | covered | AC-4; golden tests |
| Illegal placement fails at construction | covered | AC-5; scheme-rejected tests |
| Scheme argument required | covered | AZ-1946 AC-3; compile-fail fixtures; Python `TypeError` |
| Row is data (`sid` only) | covered | AZ-1946 AC-6; `MarkerRow` in each test |
| Untyped pack unchanged | covered | AZ-1946 AC-5; existing golden tests |
| Registry / generator | out-of-scope | AZ-1946 Excluded |
| Short read of the type byte | covered | Existing short-packet path; empty field name because the node has none |

## Discovered

Python and Java pass the row class into `Scheme.of` so unpack can construct `T`. Rust uses get/set closures. C++ uses `&MarkerRow::sid`. Those match the spec's "accessors at the scheme site" line. Not a gap.

## Not walked

AZ-1947 and AZ-1948 are still in `todo/` and were not part of this loop's plan.
