---
loop: 120
branch: dev
source: _docs/02_task_plans/java-unpack-declared-collection-type/queue_item.md
---
# Problem: Java unpack throws a raw ClassCastException for a LinkedList / TreeMap field

## Problem
A typed list or dict field declared `LinkedList` / `TreeMap` packs, then unpack throws `ClassCastException`: unpack always hands the setter an `ArrayList` (list) or `LinkedHashMap` (dict), and the caller's setter casts it. Java cannot see a field's declared type at build (erased lambdas), so it cannot be refused at build. Owner decision D12 B: no API change, refuse at unpack.

## Outcome
When a list or dict setter rejects the collection unpack created, unpack throws the package's own `IllegalArgumentException`, never a raw `ClassCastException`. A cast failure of anything else inside the caller's setter is not hidden. The README Java section states the rule.

## Code sections
`java/src/main/java/packbin/Containers.java` (`unpackList`, `unpackDict`), `Walker.java` (`store`), Java tests, README Java section; probe `scripts/probes/element-row/` (re-run).

## Measured first (acceptance check 1)
A list of plain values in a `LinkedList` field behaves as the element-row case: pack writes the bytes, unpack's setter cast throws. The new tests use plain `u8` elements and show it.

## How the setter's rejection is told apart
The `ClassCastException` message names the source class of the failed cast (`class java.util.ArrayList cannot be cast to class java.util.LinkedList`). It is the setter's rejection of the unpack collection when the message starts with `class java.util.ArrayList cannot be cast` or `class java.util.LinkedHashMap cannot be cast`; any other message (or none) is rethrown unchanged. Java fields have no name, so the error names the kind (`list` or `dict`), not the field.

## Acceptance checks
- Probe lines `java coll-linkedlist` and `java coll-treemap` read `refused:` in the unpack column; pack bytes unchanged.
- A cast failure of another object inside the caller's setter is still a raw `ClassCastException`.
- `List` / `Map` / `ArrayList` / `LinkedHashMap` fields, the Java suite, the fixtures and the golden vectors are unchanged (0 bytes differ).
- README Java section states the `ArrayList` / `LinkedHashMap` rule.

## Needs
none

## Constraints
No API change; no package other than Java.
