# Feature assessment — loop 103

loop: 103
feature: csharp-java-lone-surrogate-keys
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-11-11
**Implement pass**: batch 01 (`_docs/03_implementation/batch_01_loop103_report.md`), commit 1951b8c
**Verdict**: COMPLETE — 10 covered / 1 out-of-scope / 0 gap-clear / 0 gap-unclear

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | A caller packs a dictionary whose keys differ only in unpaired surrogates (C# or Java) | covered | AC-1, AC-3 (CJ-1, CJ-3); `csharp/tests/DictCollidingKeysTests.cs`, `java/src/test/java/packbin/DictCollidingKeysTest.java`; `csharp/Walker.Collections.cs` `PackDict`, `java/.../Containers.java` `packDict` | intake |
| S2 | A Java caller packs a text or key with a lone surrogate | covered | AC-4 (CJ-4); `DictCollidingKeysTest` (12 TypeScript text packets, a lone key, no `3f`); `VarFields.utf8Bytes` | intake |
| S3 | A Java caller packs "?" and a lone half as two keys | covered | AC-4; `DictCollidingKeysTest` `keysWithoutACollisionKeepTheirBytes` (`01020002103f010410efbfbd02`) | intake |
| S4 | A caller packs a dictionary with no lone surrogate | covered | AC-2 (CJ-2); the C# and Java suites; step 11 | intake |
| S5 | The same dictionary is a list element or a dict value | covered | AC-1, AC-3; one code path in each package (`PackDict`, `packDict` are the only dictionary writers; `grep` of `getBytes` in `java/src/main` leaves one call, inside `utf8Bytes`) | intake |
| S6 | Python, Go, Rust or Swift | out-of-scope | spec `### Excluded` line: "Python, Go, Rust, Swift, TypeScript, Dart." | intake |
| D1 | `[InlineData]` cannot carry a lone surrogate | covered | AC-1; the C# cases are built in the test body; the unchanged-bytes and collision tests fail against the old source | batch_01 discoveries |
| D2 | The loop 102 smoke script asserts the old behaviour | covered | noted in `probes/README.md`; the loop 102 record is dated history | batch_01 discoveries |
| D3 | Java encoded each key once per comparison | covered | NFR performance; `Containers.packDict` (`EncodedKey`) | batch_01 discoveries |
| D4 | Four packages agree on 5,000 seeded dictionaries | covered | AC-6 (CJ-6); `differential/` (C#, Java, Dart each 5,000 same, 0 different, 225 refused) | assess-round-1 |
| D5 | Never unreadable in either package | covered | AC-5 (CJ-5); 20,000 seeded dictionaries in each new test class; the tests fail against the old sources (C# 2 of 4; Java 13,577 failing checks) | assess-round-1 |

### Gaps that need a decision (gap-unclear)

None.

### Gaps that are clear (gap-clear)

None.

### Not walked

- none

### Harness gaps

- The four-package differential is run by hand from the committed sources (`differential/README.md`), not by `loop-tests.sh`; the new unit tests commit the same packets and the same message in each package.
