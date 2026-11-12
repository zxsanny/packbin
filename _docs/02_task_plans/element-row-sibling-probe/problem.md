---
loop: 116
branch: dev
tracker: AZ-4242
---
# Probe the element-row class of AZ-4199 and AZ-4205 in the six packages that were not checked

Seeded from the queue item `queue_item.md` beside this file (source: loop 111 record leftovers; LESSONS 2026-11-11 "probe every sibling").

## Problem
Loops 109 and 111 found and fixed, in C# only, a class of defects in a list or dict whose element is a row (a "element row": the element is a group of required members, written with no flag byte):

1. the row form took only some of the collection member types the package accepts for a list or dict field (C#: `List<E>` yes, `E[]` and `IList<E>` no);
2. a member declared for another row type inside an element row (or a nested row) built, then `Pack` and `Unpack` threw a raw `InvalidCastException`;
3. `when` and `times` inside an element row had no test.

TypeScript is the reference (it wrote the bytes C# was held to). Java, Go, Swift, Rust, Python and C++ were never probed for the same class. Dart was checked in loop 109 (it pins the AZ-4199 bytes) and C# was fixed, so both are out of scope.

## Outcome
One committed probe per package prints one line per shape; one findings table compares each line with TypeScript's bytes and outcome. A defect becomes one owner decision for the class (loop 112 practice); no package source changes in this loop.

## Code sections
- New: `scripts/probes/element-row/` (`run.sh`, `README.md`, one folder per package: typescript, java, go, swift, rust, python, cpp), modelled on `scripts/probes/repeat-followed-by-field/`.
- Read only: the list / dict / group paths of `java/`, `go/`, `swift/`, `rust/` (std and `nostd` APIs), `python/`, `cpp/`; the reference tests `typescript/tests/list-of-nested-rows.test.ts`, `csharp/tests/ElementRowTests.cs`, `csharp/tests/ElementRowLowsTests.cs`.
- New: `_docs/06_metrics/element-row-probe_2026-11-12.md` (findings).

## Acceptance checks
See the task spec `_docs/02_tasks/todo/AZ-4242_element_row_sibling_probe.md` (AC-1 to AC-5).

## Needs
none (every toolchain was used by the loop 112 probes on this Mac; Go runs in `golang:1.27`).

## Constraints
Probe only. No file under `java/`, `go/`, `swift/`, `rust/`, `python/`, `cpp/`, `typescript/` changes. Builds go to temporary directories outside the checkout.
