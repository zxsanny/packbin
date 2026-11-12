# Implementation report — element-row sibling probe, loop 116

task: AZ-4242 (3 points), one batch, four parallel workers (Java + Python, Go + Swift, Rust, C++); the TypeScript reference probe, the runner and the README by the parent.

Delivered: `scripts/probes/element-row/` (`run.sh`, README, probes for TypeScript, Java, Go, Swift, Rust map + `nostd`, Python, C++ bound + unbound); findings `_docs/06_metrics/element-row-probe_2026-11-12.md`.

Result in one line: Java (raw `ClassCastException` for another row class and for `LinkedList` / `TreeMap` members) and Python (raw `TypeError` for a `None` item) have the C# class; Go and Swift do not; Rust and C++ have no element-row form. Every byte any package wrote equals TypeScript's.

Follow-ups: queue items `python-null-item-in-element-row`, `missing-member-message-by-name-java-python` (ready), `java-element-row-raw-class-cast` (blocked on D10); decision D11 (element-row form in Rust and C++).

Review: `reviews/batch_01_loop116_review.md` (PASS_WITH_WARNINGS, 3 fixed, 1 kept).
