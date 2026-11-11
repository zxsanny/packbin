# Batch Report

**Batch**: 1 (loop 103)
**Tasks**: AZ-4169_csharp_java_lone_surrogate_keys
**Date**: 2026-11-11

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-4169_csharp_java_lone_surrogate_keys | Done | 3 source files (`csharp/Walker.Collections.cs` +8 lines, `java/.../Containers.java`, `java/.../VarFields.java`), 2 new test files, 3 test files edited, 5 doc files, the differential sources | C#: 4 new tests pass; Java suite exit 0 | None |

## Code Review Verdict: PASS

One total review for the loop: a four-package differential run. TypeScript wrote the expected result of 5,000 seeded dictionaries (keys of 0 to 3 units over a, b, `?`, the four surrogate halves, U+FFFD, U+FFFF, U+10000, an emoji, `~` and the empty text; 1 to 5 keys); C#, Java and Dart each packed the same dictionaries: 5,000 same, 0 different, 225 refused with the dictionary named. The new tests fail against the old sources (C#: 2 of 4, Java: 13,577 failing checks) and pass against the new ones. Android: the Java change uses only `Character.isSurrogate`/`isHighSurrogate`/`isLowSurrogate` and `StringBuilder` (API 1), and keeps the unsigned comparison helper that avoids `Arrays.compareUnsigned`.

## Test Suite

- C#: `DictCollidingKeysTests` 4 of 4 (collisions refused, unchanged packets, one lone half, 20,000 seeded dictionaries); the full C# suite runs in step 11.
- Java: `bash java/test.sh` exit 0, 0 `FAIL` lines; new class `DictCollidingKeysTest` (collisions, unchanged bytes, a lone half, 12 TypeScript text packets, 20,000 seeded dictionaries); one existing check (`TextPositionsTest`, "a lone surrogate packs as the '?'") is rewritten to expect U+FFFD.
- CI-parity: the commands of the C# and Java jobs run in step 11 with the loop 99 environment.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | `[InlineData]` and a serialized xUnit theory row cannot carry an unpaired surrogate (it comes back as U+FFFD), so a theory over lone halves tests the wrong strings | AC-1, AC-2 | done: the C# cases are built in the test body (a comment says why) | clear |
| 2 | The loop 102 smoke script asserts the old C# and Java behaviour and fails on a later HEAD | loop 102 record | noted in `probes/README.md`; the loop 102 record is dated history | clear |
| 3 | Java's sort comparator encoded both keys on every comparison; each key is now encoded once | NFR performance | done (`EncodedKey`) | clear |

## Commit

`[AZ-4169] C# and Java: refuse dictionary keys that collide after U+FFFD` with body and `Loop: 103`.

## Next Batch: All tasks complete
