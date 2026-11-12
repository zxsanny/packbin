---
kind: queue-item
order: 500
source: found in loop116 (AZ-4242 probe, `_docs/06_metrics/element-row-probe_2026-11-12.md` notes 5 and 9)
depends_on: []
status: blocked
blocked_on: OPERATOR_TODO D10 (how Java removes the raw ClassCastException)
created: 2026-11-12
---
# Java: no raw `ClassCastException` out of pack or unpack for element rows

## Problem
Two raw `ClassCastException`s, the class C# fixed in AZ-4205: (1) a member declared for another row class inside an element row or a nested row builds, then pack throws (`Access.get`, unchecked cast); (2) a typed list / dict member declared `LinkedList` / `TreeMap` packs, then unpack throws (unpack always gives an `ArrayList` / `LinkedHashMap`, `Containers.java`). Arrays and `Set` members build and are refused only at pack.

## Outcome
Per decision D10: the scheme author gets the package's own error (at build where the decision says so), never a `ClassCastException`.

## Code sections
`java/src/main/java/packbin/Access.java`, `Containers.java`, `VarFields.java`, the typed group / list / dict builders; Java tests; README Java section.

## Acceptance checks
Written from D10 when it is decided. The probe lines `java other-row`, `nested-other-row`, `coll-linkedlist`, `coll-treemap` must no longer read `threw:`.

## Needs
none
