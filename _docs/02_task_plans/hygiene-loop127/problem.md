---
loop: 127
branch: dev
---

# Loop 127 — Hygiene: the review findings of loop 126

Intake: the owner's "Run hygiene loop" (2026-11-14), the queue item `hygiene` (`queue_item.md` beside this file, nine entries written in loop 126).

## What and why

The loop 126 review and the worker reports left nine small items. This loop does seven of them in three tasks; two are split out (they are not small):
- Entry 1 (smaller debug frames of the Swift `bindAll` and the Rust `pack_one` / `unpack_one` walks) and entry 5 (contract question: how a typed element row counts, decision D20) go back into a new `hygiene.md`.

Tasks: AZ-4306 (a Field shared by two parents is measured once, six packages: entry 4, **measured this loop**: a diamond scheme makes the depth check, which runs before the field-id check, cost about 2^depth: TypeScript 17 ms at 20 levels, doubling per level), AZ-4307 (entries 2, 6, 8, 9: C# test split, Dart flag-byte bit test, TypeScript and Python tidy, whole-build timing guards), AZ-4308 (entries 3, 7: Rust). After the loop no depth check is exponential on a shared Field, and the files named are tidy.

Not in this loop: the wire format, the limit, any change of what builds at 256 levels.

## Code sections

`typescript/src/fields.ts`, `python/src/packbin/_validate.py` and `_nodes.py`, `dart/lib/src/checks.dart`, `swift/Sources/Packbin/Checks.swift`, `csharp/SchemeOrder.cs` and `csharp/tests/HostilePackVectorTests.cs`, `go/checks.go`, the walk-timing tests (`go/repeat_last_walk_test.go`, `java/src/test/java/packbin/RepeatLastWalkTest.java`, `csharp/tests/RepeatLastWalkTests.cs`), Rust `field/depth.rs`, `scheme/depth.rs`, `nostd/check.rs`, `nostd/table.rs`, `field/mod.rs` (`round_width`).

## Flagged concerns

| concern | policy / owner | status | severity |
|---------|----------------|--------|----------|
| The shared-field check must not change what builds: a scheme with no shared Field measures the same depth | each task proves 256 and 257 boundaries unchanged | open | Low |
