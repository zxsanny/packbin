---
kind: queue-item
order: 500
source: found in loop116 (AZ-4242 probe, `_docs/06_metrics/element-row-probe_2026-11-12.md` note 9); split from OPERATOR_TODO D10 on 2026-11-13; D12 decided 2026-11-13: B (refuse at unpack)
origin: operator
depends_on: []
status: ready
blocked_on:
scanned: 2026-11-13
created: 2026-11-13
---
# Java: a `LinkedList` / `TreeMap` field does not throw a raw `ClassCastException` on unpack

## Problem
A typed list or dict field declared `LinkedList` / `TreeMap` packs, then unpack throws `ClassCastException`: unpack always hands the setter a new `ArrayList` (`Containers.java`, list unpack) or `LinkedHashMap` (dict unpack). The unpack path is shared by every list and dict, so a list of plain values is likely the same (not probed). Java cannot see a field's declared type at build (erased lambdas), so this cannot be refused at build.

## Outcome
Decision D12 B: no API change. When a list or dict field's setter rejects the `ArrayList` / `LinkedHashMap` unpack creates, unpack returns the package's own error naming the field, never a raw `ClassCastException`. The README Java section says a list field must accept an `ArrayList` and a dict field a `LinkedHashMap`.

## Code sections
`java/src/main/java/packbin/Containers.java`, `Walker.java` (`store`), `Packbin.java` (`list`, `dict`); Java tests; README Java section.

## Acceptance checks
- First, measure a list of plain values in a `LinkedList` field (the probe covers only element rows) and note the outcome in the spec.
- The probe lines `java coll-linkedlist` and `java coll-treemap` (`bash scripts/probes/element-row/run.sh java`) read `refused: <the package's error naming the field>` in the unpack column; their pack bytes are unchanged.
- A cast failure from inside the caller's own setter for another reason is not hidden: only the setter's rejection of the collection unpack created becomes the package's error (the spec names how this is told apart).
- `ArrayList` / `HashMap` / `LinkedHashMap` fields, the Java suite, the fixtures and the golden vectors are unchanged (0 bytes differ).
- The README Java section states the `ArrayList` / `LinkedHashMap` rule.

## Needs
none
