---
kind: queue-item
order: 500
source: found in loop116 (AZ-4242 probe, `_docs/06_metrics/element-row-probe_2026-11-12.md` note 9); split from OPERATOR_TODO D10 on 2026-11-13
depends_on: []
status: blocked
blocked_on: OPERATOR_TODO D12 (a collection factory, or a refusal at unpack)
created: 2026-11-13
---
# Java: a `LinkedList` / `TreeMap` field does not throw a raw `ClassCastException` on unpack

## Problem
A typed list or dict field declared `LinkedList` / `TreeMap` packs, then unpack throws `ClassCastException`: unpack always hands the setter a new `ArrayList` (`Containers.java`, list unpack) or `LinkedHashMap` (dict unpack). The unpack path is shared by every list and dict, so a list of plain values is likely the same (not probed). Java cannot see a field's declared type at build (erased lambdas), so this cannot be refused at build.

## Outcome
Per decision D12: the field round-trips (A) or unpack refuses with the package's error naming the field (B); never a raw `ClassCastException`.

## Code sections
`java/src/main/java/packbin/Containers.java`, `Walker.java` (`store`), `Packbin.java` (`list`, `dict`); Java tests; README Java section.

## Acceptance checks
Written from D12 when it is decided. The probe lines `java coll-linkedlist` and `java coll-treemap` must no longer read `threw:`; a list of plain values in a `LinkedList` field is measured first.

## Needs
none
