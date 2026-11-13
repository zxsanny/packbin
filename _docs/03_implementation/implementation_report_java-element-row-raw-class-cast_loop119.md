# Implementation report — Java row class refused at build, loop 119

task: AZ-4253 (3 points), one batch, by the parent.

Delivered: `java/src/main/java/packbin/RowClassCheck.java` (new, package-private), called from `Packbin.group(get, set, create, fields)`: the factory makes one child and each member's getter and setter run once on it; a `ClassCastException` becomes `IllegalArgumentException("<kind> <id>: declared for another row class; this row is <Class>")`. `RowClassTest` (AC-1 to AC-5), two factory counts in `TypedNestedRowTest` measured from after the build, a README bullet.

Result: the Java element-row probe lines `other-row` and `nested-other-row` read `refused: IllegalArgumentException: utf8 0: declared for another row class; this row is Comment`; the other 20 Java lines are byte-identical. Java suite green (`bash java/test.sh`, 15 s). CI-parity: `bash java/test.sh` (the CI `suites (java)` command).

## Discovered during implementation

| spec ref | finding | proposed handling | clear/unclear |
|----------|---------|-------------------|---------------|
| AC-1 | the build now calls the factory once; two existing tests counted factory calls from the start | count from after the build (their intent is unpack's calls); README bullet says the build calls it | clear |
| AC-1 | a factory that returns `null` must keep building (an existing test pins unpack's refusal) | the check skips a `null` child | clear |
| — | a top-level typed row has no factory, so a member of another class there still throws at pack | hygiene entry `java-top-level-row-class` (Medium) | clear |

Review: `reviews/batch_01_loop119_review.md` (PASS_WITH_WARNINGS, 1 queued, 1 fixed).
