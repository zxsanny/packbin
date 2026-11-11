# Security lite — loop 103 (AZ-4169, C# and Java colliding dictionary keys)

**Date**: 2026-11-11
**Diff**: `git diff d4e6275..HEAD -- . ':!_docs'` (3 source files: C# +8 lines, Java about 65 changed lines; 2 new and 3 edited test files)
**Verdict**: CLEAN

## Triggers

| # | Trigger | Hit |
|---|---------|-----|
| T1 | sensitive path | no (`csharp/Walker.Collections.cs`, `java/src/main/java/packbin/`, tests, README) |
| T2 | sensitive content | no (grep of the changed source lines for token, secret, password, jwt, session, innerHTML, exec, http, File, Process: 0 hits) |
| T3 | size or complexity | no by size (3 source files, under 300 changed non-test lines); the task is 5 points, which the table counts as a trigger, so the checks below are the scoped full pass |
| T4 | dependencies | no (`*.csproj`, `pom`/manifests, lock files unchanged) |
| T5 | carried finding touched | no (F70 to F78 name release, CI and Dart files; none changed) |
| T6 | stale audit | no (full report of loop 99 and the loop 100 and 101 passes are from today) |

## Checks on the changed lines

| Check | Result |
|-------|--------|
| Input limits | C#: one neighbour comparison per key after the sort that already ran: O(n); Java: each key is encoded once (before, twice per comparison), one scan per string for a lone half, a `StringBuilder` only when one is present; both on a dictionary the caller holds, capped at 65,535 keys; unpack is unchanged |
| Exceptions out of pack | a refusal throws before anything is written to the output buffer (C#: before `buffer.AddU16`; Java: before `sink.writeCount`), so no partial packet leaves `pack`; the message names the dictionary and quotes no key text |
| Silent data change | Removed in both: the old code wrote one key twice (a packet its reader refuses); Java no longer turns a lone half into a real `?` (the byte `3F` became `EF BF BD`, the owner's decision) |
| Fuzz | 20,000 seeded dictionaries in each package's tests and 5,000 in the four-package differential: 0 unreadable packets, 0 disagreements with TypeScript |
| Blast radius | `Encoding.UTF8.GetBytes` in `Walker.Counted.cs` (the text) is untouched; in Java `getBytes(StandardCharsets.UTF_8)` appears once, inside `utf8Bytes`, which both the key and the text use |

No finding. Step 14 is done.
