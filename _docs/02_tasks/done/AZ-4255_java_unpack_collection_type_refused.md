---
loop: 120
branch: dev
---

# Java: a list or dict field whose setter rejects the unpack collection is refused with the package's error

**Task**: AZ-4255_java_unpack_collection_type_refused
**Name**: Java: a list or dict field whose setter rejects the unpack collection is refused with the package's error
**Description**: Unpack throws `IllegalArgumentException` when the setter of a list or dict field rejects the `ArrayList` / `LinkedHashMap` it was given, instead of a raw `ClassCastException`.
**Complexity**: 2 points
**Dependencies**: AZ-4242 (done)
**Component**: `java/src/main/java/packbin/` (`Containers.java`, `Walker.java`), `java/src/test/`, `README.md` Java section
**Tracker**: AZ-4255
**Epic**: AZ-4133

Queue item `java-unpack-declared-collection-type` (loop 116 probe note 9), owner decision D12 B. Problem: `_docs/02_task_plans/java-unpack-declared-collection-type/problem.md`.

## Acceptance Criteria

**AC-1: A list field that rejects an ArrayList**
Given a `LinkedList` list field of plain values and its packed bytes
When unpack runs
Then it throws `IllegalArgumentException` `list: the setter rejected an ArrayList that unpack creates; a list field must accept an ArrayList`, and pack still writes the same bytes.

**AC-2: A dict field that rejects a LinkedHashMap**
Given a `TreeMap` dict field
When unpack runs
Then `dict: the setter rejected a LinkedHashMap that unpack creates; a dict field must accept a LinkedHashMap`.

**AC-3: Another cast failure is not hidden**
Given a setter that fails a cast of an object other than the unpack collection
When unpack runs
Then the caller's own `ClassCastException` reaches the caller.

**AC-4: Accepted types unchanged**
Given `List`, `Map` fields
When unpack runs
Then the values are read back as today (`ArrayList`, `LinkedHashMap`).

**AC-5: Probe, suite, README**
`bash scripts/probes/element-row/run.sh java`: only `coll-linkedlist` and `coll-treemap` change (unpack column `threw:` to `refused:`, pack unchanged); the Java suite passes, no byte differs; the README Java section states the rule.

## Tests
`java/src/test/java/packbin/CollectionTypeTest.java` (AC-1 to AC-4); AC-5: step 11 `java` stage, ring, the probe at close.

## Constraints
No API change; no package other than Java.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The test of "rejected the unpack collection" reads the `ClassCastException` message (HotSpot and OpenJ9 print `class X cannot be cast to class Y`); another JVM message shape is rethrown unchanged, as before this change | agent | accepted-risk | Low |
