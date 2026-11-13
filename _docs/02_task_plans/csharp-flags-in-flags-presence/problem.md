---
loop: 118
branch: dev
source: _docs/02_task_plans/csharp-flags-in-flags-presence/queue_item.md
---
# Problem: C# drops the value of a `flags` that is a direct member of a `flags`

## Problem
`Flags(0, Flags(0, X), Bool)` with `X = 9` and the bool true packs `0102` in C# (typed and dictionary form): the inner `flags` writes nothing and its value is dropped with no error. TypeScript and Java pack `01030109` for the same scheme. `csharp/Walker.Presence.cs` `BitOn` has no `Flags` arm, so the presence bit of a `flags` that is a member of another `flags` is never set.

## Outcome
C# packs `01030109` (the TypeScript and Java bytes) for that scheme and reads it back; a probe says what every package does for the same scheme, and a defect found in another package becomes one decision for the class (LESSONS 2026-11-11: probe every sibling).

## Code sections
`csharp/Walker.Presence.cs` (`BitOn`), its tests under `csharp/tests/`; a probe under `scripts/probes/flags-in-flags/` for all nine packages.

## Acceptance checks
- A committed probe prints the packet and the read-back for the scheme in all nine packages.
- C# packs the same bytes as TypeScript and Java and reads the value back (typed form; the dictionary form has no public reader).
- A test pins it; the whole C# suite passes on `net10.0` and `netstandard2.0` (`env MSBUILDDISABLENODEREUSE=1`).

## Needs
none

## Constraints
A packet that C# wrote before this change (the dropped value) was already lossy; say so in the README upgrade notes only if a package other than C# changes bytes.
