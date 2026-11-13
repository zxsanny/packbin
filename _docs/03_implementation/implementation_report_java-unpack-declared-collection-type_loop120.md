# Implementation report — Java unpack collection type, loop 120

task: AZ-4255 (2 points), one batch, by the parent.

Delivered: `Walker.storeContainer` (called by `Containers.unpackList` and `unpackDict`): a `ClassCastException` from the setter whose message starts `class java.util.ArrayList cannot be cast` or `class java.util.LinkedHashMap cannot be cast` becomes `IllegalArgumentException("list: the setter rejected an ArrayList that unpack creates; a list field must accept an ArrayList")` (dict likewise); any other cast failure is rethrown. `CollectionTypeTest` (AC-1 to AC-4), a README bullet.

Result: probe lines `java coll-linkedlist` and `coll-treemap` unpack column `refused: IllegalArgumentException`, pack hex unchanged; the other 20 Java lines byte-identical; Java suite green (`bash java/test.sh`). CI-parity: `bash java/test.sh`.

## Discovered during implementation

| spec ref | finding | proposed handling | clear/unclear |
|----------|---------|-------------------|---------------|
| AC-1 | a Java field has no name, so "naming the field" is not possible: the error names the kind | state it in the spec, README and code comment | clear |
| AC-1 | a list of plain values in a `LinkedList` field behaves exactly as the element-row case (measured by `CollectionTypeTest` AC-1) | none | clear |

Review: `reviews/batch_01_loop120_review.md` (PASS_WITH_WARNINGS, 3 Low).
