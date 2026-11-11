---
loop: 103
branch: dev
---

# Loop 103 — C# and Java refuse colliding dictionary keys; Java writes U+FFFD

Loop 103 (on `dev`; no worktree). Intake: the owner's answer "A: both refuse, Java uses U+FFFD" (2026-11-11) to the question "What should loop 103 change in C# and Java?", from the findings of loop 102 (`_docs/02_task_plans/lone-surrogate-key-probe/findings.md`, `_docs/loops/loop102/record102.md`).

## What and why

Loop 102 ran each package and found that C# and Java write a packet their own unpack refuses when two dictionary keys differ only in unpaired UTF-16 surrogates. C# writes U+FFFD (`EF BF BD`) for each lone half, so the keys become one on the wire (`0102000410efbfbd010410efbfbd02`). Java writes a question mark (`3F`) for each lone half (`01020002103f0102103f02`), which also merges a lone half with a real "?" and turns a lone half into "?" silently. TypeScript (loop 101) and Dart (loop 100) refuse such a dictionary at pack and write U+FFFD for a lone half. The owner chose option A:

1. C# refuses two keys that become one at pack, as TypeScript and Dart (an `ArgumentException` naming the dictionary field; no bytes returned).
2. Java refuses them the same way (an `IllegalArgumentException`).
3. Java writes U+FFFD (not "?") for an unpaired surrogate in a key and in a text, as TypeScript, Dart and C#.

Every C# dictionary without a collision packs the same bytes as before. In Java only a key or text that holds a lone surrogate changes (`3F` becomes `EF BF BD`); everything else is unchanged. Python and Go already refuse a lone surrogate, Rust and Swift cannot hold one: no change there.

## Code sections / UI locations for this loop

Owner (2026-11-11): the dictionary key pack of C# and Java, named in the question. Found by `git grep`: C# `csharp/Walker.Collections.cs` (`PackDict`, line 102 encodes the key, line 108 sorts) and `csharp/Walker.Counted.cs:297` (`PackUtf8`, a text; already writes U+FFFD, unchanged); Java `java/src/main/java/packbin/Containers.java` (`packDict`, lines 60 to 84: the sort comparator at 75 and the written key at 79 call `getBytes`) and `java/src/main/java/packbin/VarFields.java:268` (`packUtf8`, a text). Tests: `csharp/tests/` (xUnit) and `java/src/test/java/packbin/` (JUnit), beside the existing dictionary tests. Docs: the README Dart/TypeScript notes that mention the open C# and Java item, `_docs/02_task_plans/lone-surrogate-key-probe/findings.md`, the C# and Java component docs.

## Flagged concerns

| concern | policy / owner | status | severity |
|---------|----------------|--------|----------|
| a C# or Java dictionary that packed before (two colliding keys) now throws; the old packet was refused by every unpack, so it carried no data | owner chose it (2026-11-11) | accepted-risk | Low |
| Java text and keys with a lone surrogate now carry U+FFFD instead of "?": a changed byte for a caller that relied on "?" | owner chose it (2026-11-11, option A) | accepted-risk | Low |
| both packages are published (NuGet and Maven Central at 0.4.0) without the change; the next tag carries it | no release in this loop | accepted-risk | Low |
