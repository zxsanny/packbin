# Feature assessment — loop 120 (AZ-4255)

round: 1
verdict: COMPLETE — 6 covered / 0 out-of-scope / 0 gap-clear / 0 gap-unclear

| angle | spec | evidence (test; code path) | status |
|-------|------|----------------------------|--------|
| a `LinkedList` list field of plain values (measured first, as the item asked) | AC-1 | `CollectionTypeTest.ac1LinkedListOfValuesIsRefusedAtUnpack`; `Containers.unpackList` → `Walker.storeContainer` | covered |
| a `TreeMap` dict field | AC-2 | `ac2TreeMapOfValuesIsRefusedAtUnpack`; `unpackDict` | covered |
| a list or dict of element rows (the probe's `coll-linkedlist`, `coll-treemap`) | AC-5 | probe diff: exactly those two lines move, pack hex identical | covered |
| another cast failure inside the caller's setter is not hidden | AC-3 | `ac3AnotherCastFailureIsNotHidden` | covered |
| `List` / `Map` fields unchanged, still `ArrayList` / `LinkedHashMap` | AC-4 | `ac4AcceptedTypesAreUnchanged`; suite and golden vectors green | covered |
| a list field inside a repeat or times round (the setter gets the outer `ArrayList`) | AC-1 rule | same `storeContainer`, same message check; not separately tested | covered by reading (Low) |
| the error names the field | item text | a Java field has no name; the error names the kind (spec, README, Jira text say so) | covered (deviation stated) |

Discoveries read: `implementation_report_java-unpack-declared-collection-type_loop120.md` (two rows, handled), `reviews/batch_01_loop120_review.md` (3 Low).
