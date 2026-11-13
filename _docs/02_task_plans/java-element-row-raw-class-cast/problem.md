---
loop: 119
branch: dev
source: _docs/02_task_plans/java-element-row-raw-class-cast/queue_item.md
---
# Problem: Java builds an element row or nested row whose members are declared for another row class

## Problem
A member declared for another row class inside an element row (list or dict) or a nested row builds; pack then throws a raw `ClassCastException` (`Comment cannot be cast to Other`) from the unchecked cast in `Access`. C# (AZ-4205), Go and Swift refuse it when the scheme is built. Owner decision D10 (2026-11-13): A, refuse at build.

## Outcome
Building such a scheme fails with the package's own error (`IllegalArgumentException`) that names the member and the row class; `pack` and `unpack` are never reached. Members declared for the row class or a base class of it build and round-trip as today.

## Code sections
`java/src/main/java/packbin/Packbin.java` (the typed `group(Getter, Setter, Supplier, Field...)`; list and dict elements are such groups), `Field.java`; a new package-private check class; Java tests; README Java section; probe `scripts/probes/element-row/` (re-run, not edited).

## Mechanism (decision row D13, default applied)
Java accessors are erased lambdas, so the row class of a member cannot be read. The nested-row group already has a child factory (`Comment::new`): at construction the check makes one child with it and calls each member's getter and setter (`set(child, null)`) once on it, through the containers that share the row (flags, flag bits, when, anchored groups, u2 slots, repeat and times rounds) and for the accessors of nested rows, lists and dicts (not their insides: those have their own factory). A lambda declared for another class casts its argument before its body runs and throws `ClassCastException`: refused, naming the member and the child's class. Any other exception from an accessor on a fresh, empty child is not a class mismatch and is left to pack and unpack, as before.

## Acceptance checks
- The probe lines `java other-row` and `java nested-other-row` (`bash scripts/probes/element-row/run.sh java`) read `refused: <the package's error naming the member and the row class>`, not `threw:`.
- A member declared for a base class of the row class builds and round-trips.
- Every other Java probe line, the Java suite, the fixtures and the golden vectors are unchanged (0 bytes differ).
- The README Java section says a member of another row class is refused when the scheme is built.

## Needs
none

## Constraints
No API change; no package other than Java.
