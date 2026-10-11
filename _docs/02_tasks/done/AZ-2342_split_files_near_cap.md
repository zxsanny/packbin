---
loop: 19
branch: dev
---

# Split Rust `walk/unpack

**Task**: AZ-2342_split_files_near_cap
**Name**: Split files near the line cap
**Description**: Split Rust `walk/unpack.rs` and `field/mod.rs`, Java `Walker.java` and C# `Packbin.cs` and `Walker.cs` by responsibility so each stays well under 500 lines with room for loop 19 additions.
**Complexity**: 2 points
**Dependencies**: None
**Component**: rust, java, csharp
**Tracker**: AZ-2342
**Epic**: AZ-2069

## Problem

Owner decision clear gap (maintainability) of loop 19 (2026-10-11, option A, accepted as recommended). Those files sit at 420 to 479 lines; the loop 19 specs add code to them.

## Outcome

- No file of those three packages exceeds 400 lines after the split; behavior unchanged.

## Scope

### Included
- Move code only; public API unchanged.

### Excluded
- Any behavior change; other files.

## Acceptance Criteria

**AC-1: files under 400 lines**
Given the six files
When split
Then each below 400 lines

**AC-2: behavior unchanged**
Given each package suite
When run
Then same pass count as before the split

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-2 | package suites | unchanged counts |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | none | golden vectors | unchanged | — |

## Constraints

- A split commit does not mix behavior changes (done first in each worker).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none | coordinator | resolved | Low |

## Loop 19 result (2026-10-11)

Done in loop 19: Rust `walk/unpack.rs` 471 to 352 and `field/mod.rs` 479 to 332; Java `Walker.java` 464 to 387; C# `Packbin.cs` 417 to 210 and `Walker.cs` 418 to 299; suites unchanged.
