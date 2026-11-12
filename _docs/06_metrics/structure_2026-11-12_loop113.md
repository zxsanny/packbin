# Structure snapshot — 2026-11-12, loop 113

Source: `_docs/02_document/module-layout.md`, the committed loop 113 diffs (`2c285d7~1..HEAD`). Previous snapshot: `structure_2026-11-11_loop108.md`.

| Metric | Loop 108 | Loop 113 |
|--------|---------:|---------:|
| Components | 9 | 9 (no package added) |
| Cross-component import edges | 0 | 0 (every check lives in its package's scheme-build code) |
| Cycles | 0 | 0 |
| New modules since loop 108 | | none in the library: 10 new test files in the packages, 11 C++ compile-fail files, 1 Dart test helper (`dart/test/support/timing.dart`); no new library source file |
| Source files that grew past 500 lines | 0 | 0 (`typescript/src/rounds.ts` is exactly 500, the soft cap) |
| Architecture findings (new / resolved) | 0 / 0 | 0 / 0 |
| Contracts | 3 | 4 (`contracts/library/repeat-last.md`, version 1.0.2: a rule, no wire change) |

Library files per component (non-test, `git ls-files`): TypeScript 25, C# 45, Python 22, Java 36, Go 41, Swift 33, Dart 45, Rust 61, C++ 24 (13 headers, 11 sources).

Diffstat of loop 113 outside `_docs/`: 121 files, +7,763 -329 lines: library source 27 files, 1,012 lines (the check in each package: TypeScript `rounds.ts` +122, Dart `checks.dart` +152, Java `SchemeOrder.java` +116 and `Rounds.java` 44 changed, Go `counted.go` +108, Swift `Counted.swift` +95, C# `RoundScopes.cs` +81, Python `_validate.py` +65, Rust `round_body.rs` +56 and `nostd/check.rs` +28, C++ `order.hpp` +46); tests, hostile loaders and compile-fail files 86 files, 6,858 lines; fixtures 3 files +145; scripts and probes 4 files +31 -11; `README.md` +27 -8.
