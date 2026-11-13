# Batch review — loop 120, batch 01 (AZ-4255)

verdict: PASS_WITH_WARNINGS
scope: `java/src/main/java/packbin/Walker.java` (`storeContainer`), `Containers.java` (two call sites), `java/src/test/java/packbin/CollectionTypeTest.java` (new), `PackbinTest.java` (registration), `README.md` (one bullet)
reviewer: the parent

| # | severity | category | finding | outcome |
|---|----------|----------|---------|---------|
| 1 | Low | Spec-Gap | the item says the error names the field; a Java field has no name (erased lambdas; `Access.KeySetter` exists only for Map rows, whose setter accepts any collection), so the error names the kind | accepted: stated in the spec, the Jira text, the README bullet and the code comment; the first version had a KeySetter naming branch that could never run, removed |
| 2 | Low | Style | process: the code was written before the intake files (claim, ticket, spec, plan); the ticket key was guessed as AZ-4254 in two comments and the create call returned AZ-4255 | fixed (references corrected before the commit); lesson already in the loop 113 retro (name files from the key the create call returns) |
| 3 | Low | Maint | the rejection test reads the `ClassCastException` message; another JVM's message shape is rethrown unchanged, as before the change | accepted-risk in the spec |

Checks: `storeContainer` covers only list and dict fields (`Containers.unpackList` and `unpackDict`), including a field in a repeat or times round (the setter then gets the outer `ArrayList`: same rule, same message); scalar setters keep `store`. The caller's own cast failure of another object is not hidden (test AC-3). Proving runs: the two refusal tests fail on the old unpack path, with the raw `ClassCastException`; the Java element-row probe changes exactly two lines (`coll-linkedlist`, `coll-treemap`: unpack `threw: ClassCastException` to `refused: IllegalArgumentException`, pack hex identical), the other 20 lines are byte-identical.
