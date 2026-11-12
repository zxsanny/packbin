# Feature assessment — loop 116 (AZ-4242, element-row sibling probe)

round: 1
verdict: COMPLETE

Intent (queue item `element-row-sibling-probe`, loop 111 leftovers): probe the C# element-row defect class (AZ-4199, AZ-4205) in the six packages never checked, compare with TypeScript, turn any defect into one decision for the class; no package source changes.

| angle | spec | evidence | status |
|-------|------|----------|--------|
| A probe per package, one line per shape | AC-1 | `scripts/probes/element-row/run.sh`: 168 lines, 7 packages (Rust twice: map and `nostd`), exit 0 | covered |
| Every shape answered (n/a with a reason, refused vs threw) | AC-2 | every package prints all 11 shapes; `threw:` only where the package's own error is not raised (Java 4, Python 1) | covered |
| Collection member types (C# defect 1) | AC-1 shape `coll-*` | Java, Go, Swift, Python list their accepted and refused types; Rust and C++ say why there is none | covered |
| A member of another row type (C# defect 2) | `other-row`, `nested-other-row` | Go, Swift refuse at build; Java throws (D10); Python refuses the nearest shape; Rust, C++ n/a or compile error | covered |
| `when` / `times` in an element row (C# defect 3) | `when`, `times` | Java, Go, Swift, Python equal TypeScript's bytes and read back; Rust, C++ cannot write (D11) | covered |
| Findings compared with TypeScript, one decision for the class | AC-3 | `_docs/06_metrics/element-row-probe_2026-11-12.md`; D10, D11; queue items `java-element-row-raw-class-cast` (blocked on D10), `python-null-item-in-element-row`, `missing-member-message-by-name-java-python` | covered |
| Repeatable, no files written | AC-4 | two runs byte-identical; `git status` shows only the new probe folder | covered |
| No package source changed | AC-5 | diff touches `scripts/probes/element-row/`, `_docs/` only | covered |
| Found while implementing: Rust and C++ cannot read other packages' list-of-rows packets (interop, not a defect of the class) | — | findings notes 1 to 4 | out of scope → D11 |
| Found while implementing: Java's unpack collection type is likely the same for lists of plain values | — | findings note 9 ("not probed") | carried in the Java queue item |
