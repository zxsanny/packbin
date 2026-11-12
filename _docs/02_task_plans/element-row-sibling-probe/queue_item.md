---
kind: queue-item
order: 500
source: loop111 record (leftovers: "the sibling probe of the AZ-4199 element row in Java, Go, Swift, Rust, Python and C++"); LESSONS 2026-11-11 [process] "probe every sibling"
depends_on: []
status: ready
blocked_on:
created: 2026-11-12
---
# Probe the element-row class of AZ-4199 and AZ-4205 in the six packages that were not checked

## Problem
Loops 109 and 111 found and fixed, in C# only, a class of defects in a list or dict whose element is a row: array and `IList` members were not accepted, a member of another row type gave a raw cast exception out of pack and unpack, and `when` / `times` inside an element row had no test. TypeScript is the reference. Java, Go, Swift, Rust, Python and C++ were never probed for the same class.

## Outcome
One table says, per package, what an element row accepts, what it refuses and with which error, and whether the bytes equal TypeScript's. A defect that shows up becomes one decision for the class and its tasks.

## Code sections
The element-row paths of `java/`, `go/`, `swift/`, `rust/`, `python/`, `cpp/` (list and dict of rows); new committed probes under `scripts/probes/`; findings under `_docs/06_metrics/`.

## Acceptance checks
- A committed probe per package runs the shapes of AZ-4199 and AZ-4205 (collection-typed members of an element row, a member of another row type, `when` and `times` inside an element row) and prints one line per shape.
- The findings table compares each line with TypeScript's bytes and outcome.
- A package that cannot write a shape says why in its line.
- No package source changes in the probe loop.

## Needs
none

## Constraints
Probe only; a fix follows the owner's decision for the class (loop 112 practice).
