# Implementation report — hygiene loop 121

tasks: AZ-4257 Java (3), AZ-4258 Python (2), AZ-4259 C# and Go (3), AZ-4260 Dart (1), AZ-4261 C++ (5): 14 points, one batch, four workers in parallel on disjoint directories (Java; Python; C# and Go; C++) and the Dart task by the parent.

Delivered (the eight entries of the hygiene queue item):
- Java, C# and Go: the repeat-last walk is linear (a memo of the first writer per container); chain of nested `when`s at depth 16,000: C# 3.17 s to 5.4 ms, Go 1.80 s to 1.9 ms, Java at 4,000 0.12 s to 3 ms.
- Java and Python: a missing required member is named (`missing text` for Map rows and Python; `missing utf8 1` for a typed Java row).
- Python: a `None` item of a list or dict of rows is refused (`items: an item has no value`).
- Java: a top-level typed row member of another class is refused at build (D14).
- Dart: every wall-clock bound uses the load-aware helper (`LoadBound`, `expectWithin`, `overLoadBound`); suite 2,088 passed, also at host load up to 56.
- C++: the s390x row compares its percentage packets with the Cortex-M3 file; a sanitizer test target (`make -C cpp CXX=clang++ sanitizer-test`) passes 5 runs in a row and prints its timing checks without asserting (D15); the Arduino-ESP32 core is pinned to 3.3.12 in `.github/workflows/tool-pins.txt`, printed and checked by the stage, with `_docs/gotchas/arduino-esp32-core-pin.md`.
No packet byte changes. CI-parity: the package suites as `run-suite.sh` runs them (the workers ran Java, Python, C# on both targets, Go in the CI container, Dart with format and analyzer, C++ plain and in `gcc:16`); step 11 runs all of them again.

## Discovered during implementation

| spec ref | finding | proposed handling | clear/unclear |
|----------|---------|-------------------|---------------|
| AZ-4257 entry 2 | a typed Java row cannot name a missing member (lambdas); the entry's check `contains missing text` holds for Map rows only | `missing utf8 1` for typed rows, documented | clear |
| AZ-4257 entry 3 | the loop 119 row-class check refused any `ClassCastException` of a setter, not only the row's | narrowed to the row's own cast (message) | clear |
| AZ-4258 entry 1 | a scalar or bytes member missing from a top-level Python row still says `missing field <id>` (pinned by tests) | not changed; Low | clear |
| AZ-4257 entry 2 | Java int, float and bytes members still say `missing field N` (pinned by `HostileRefusals`) | not changed; Low | clear |
| AZ-4261 entry 2 | GCC 16 cannot build the suite under UBSan; no hang limit in the hostile guard under a sanitizer | clang-only target; CI job timeout when added | clear |
| AZ-4260 | the per-unpack 1 s bounds of the hostile cases and the fuzz loop were also fixed bounds | covered by `overLoadBound` (no load measurement on the fast path) | clear |

Review: `reviews/batch_01_loop121_review.md` (PASS_WITH_WARNINGS, 7 Low).
