---
loop: 20
branch: dev
---

# csharp/tests/LayoutTests.cs and rust/src/scheme/bound.rs are split by responsibility under 500 lines

**Task**: AZ-2365_split_files_near_cap_l20
**Name**: Split files above the cap
**Description**: csharp/tests/LayoutTests.cs and rust/src/scheme/bound.rs are split by responsibility under 500 lines.
**Complexity**: 1 points
**Dependencies**: AZ-2342 (done)
**Component**: csharp, rust
**Tracker**: AZ-2365
**Epic**: AZ-2069

## Problem

Loop 20 clear gap G5. `csharp/tests/LayoutTests.cs` is 517 lines and `rust/src/scheme/bound.rs` 514, above the 500-line soft cap (`quality-thresholds`). Any file that a loop 20 change pushes above 500 lines is split in the same task.

## Outcome

- Each file under 500 lines, split by responsibility; the same test count.

## Acceptance Criteria

**AC-1: under the cap**
Given the two files (and any loop 20 file above 500)
When split
Then every resulting file is under 500 lines and the package suites keep their pass counts

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | line counts and suite counts | under 500, same counts |

## Constraints

- Wire bytes of every accepted row are unchanged.
