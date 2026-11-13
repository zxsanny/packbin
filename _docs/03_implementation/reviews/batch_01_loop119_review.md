# Batch review — loop 119, batch 01 (AZ-4253)

verdict: PASS_WITH_WARNINGS
scope: `java/src/main/java/packbin/RowClassCheck.java` (new), `Packbin.java` (`group(get, set, create, fields)`), `java/src/test/java/packbin/RowClassTest.java` (new), `TypedNestedRowTest.java` (two factory counts), `PackbinTest.java` (registration), `README.md` (one bullet)
reviewer: the parent

| # | severity | category | finding | outcome |
|---|----------|----------|---------|---------|
| 1 | Medium | Spec-Gap (outside the item) | a top-level `Scheme<Row>` member declared for another class still builds and throws at pack: the top level has no factory to make a row | queued: `backlog/hygiene.md` entry `java-top-level-row-class` |
| 2 | Low | Bug (checked, none) | the two existing factory-count tests of `TypedNestedRowTest` counted the build's call; their intent (unpack calls the factory once / not at all) is kept by counting from after the build | fixed in the tests; the README bullet states the build call |

Checks: the walk follows exactly the containers `MemberNames` treats as sharing the row (flags, flag bits, when, anchored groups, repeat and times rounds, u2 slots) and stops at nested rows, lists and dicts; a factory that returns `null` builds as before (`nullFactory` test unchanged); `catch (RuntimeException)` is the documented outcome for a non-cast failure on an empty child (AC-5 test). Proving runs: the new tests fail 10 times on the old code; the Java element-row probe changes exactly two lines (`other-row`, `nested-other-row`: `threw: ClassCastException` to `refused:`), the other 20 lines are byte-identical.
