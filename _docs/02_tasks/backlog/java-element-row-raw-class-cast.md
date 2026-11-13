---
kind: queue-item
order: 500
source: found in loop116 (AZ-4242 probe, `_docs/06_metrics/element-row-probe_2026-11-12.md` note 5); OPERATOR_TODO D10 decided 2026-11-13: A (refuse at build)
depends_on: []
status: ready
blocked_on:
created: 2026-11-12
---
# Java: a field of another row class in an element row or nested row is refused at build

## Problem
A member declared for another row class inside an element row (list or dict) or a nested row builds; pack then throws a raw `ClassCastException` (`Comment cannot be cast to Other`) from the unchecked cast of `Access.get`. C# (AZ-4205), Go and Swift refuse it when the scheme is built. Owner decision D10 (2026-11-13): A, refuse at build, as they do.

## Outcome
Building such a scheme fails with the package's own error that names the member and the row class; `Pack` and `Unpack` are never reached. Members declared for the row class (or a base class of it) build and round-trip as today.

## Code sections
`java/src/main/java/packbin/Packbin.java` (the typed `group(Getter, Setter, Supplier, Field...)` and `list` / `dict` builders), `Field.java`, `Access.java`, `VarFields.java`; Java tests; README Java section. Java sees members only as erased lambdas: the row instance from the group's `Supplier` (`Comment::new`) is one way to check members at build; the task names the mechanism it uses in its spec (and any API addition it needs, which D10 A allows).

## Acceptance checks
- The probe lines `java other-row` and `java nested-other-row` (`bash scripts/probes/element-row/run.sh java`) read `refused: <the package's error naming the member and the row class>`, not `threw:`.
- A member declared for a base class of the row class builds and round-trips.
- Every other Java probe line, the Java suite, the fixtures and the golden vectors are unchanged (0 bytes differ).
- The README Java section says a member of another row class is refused when the scheme is built.

## Needs
none
