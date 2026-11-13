---
kind: queue-item
order: 500
source: found in loop113 (code review of AZ-4212, outside the diff)
origin: agent
severity: high
depends_on: []
status: ready
loop: 118
branch: dev
blocked_on:
created: 2026-11-12
---
# C#: the bit of a `flags` that is a direct member of a `flags` is never set

## Problem
`Flags(0, Flags(0, X), Bool)` with `X = 9` and the bool true packs `0102` in C# (typed and dictionary form): the inner `flags` writes nothing and its value is dropped with no error. TypeScript and Java pack `01030109` for the same scheme. `csharp/Walker.Presence.cs:21` has no `Flags` arm, so presence of a `flags` that is a member of another `flags` is never seen.

## Outcome
C# packs `01030109` (the TypeScript and Java bytes) for that scheme and reads it back; the sibling probe says what Go, Swift, Python, Dart, Rust and C++ do for the same scheme, and a defect found there becomes one decision for the class (LESSONS 2026-11-11: probe every sibling).

## Code sections
`csharp/Walker.Presence.cs` (around line 21), its tests; a probe under `scripts/probes/` for the other packages.

## Acceptance checks
- A committed probe prints the packet and the read-back for the scheme in all nine packages.
- C# packs the same bytes as TypeScript and Java and reads the value back (typed form; the dictionary form has no public reader).
- A test pins it; the whole C# suite passes on `net10.0` and `netstandard2.0` (`env MSBUILDDISABLENODEREUSE=1`).

## Needs
none

## Constraints
A packet that C# wrote before this change (the dropped value) was already lossy; say so in the README upgrade notes only if a package other than C# changes bytes.
