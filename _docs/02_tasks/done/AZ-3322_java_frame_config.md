---
loop: 74
branch: dev
---

# Java frame sessions load with `FrameConfig` and `FrameDirections`

**Task**: AZ-3322_java_frame_config
**Name**: Java `FrameConfig` and `FrameDirections`, the same load shape as Rust, C# and Swift
**Description**: A Java caller loads a frame session with one `FrameConfig` (tag length and a set of directions), as in the other three frame packages.
**Complexity**: 2 points
**Dependencies**: AZ-3290_java_frame_names
**Component**: 06_java_package
**Tracker**: AZ-3322
**Epic**: AZ-3199

Feature assessment loop 74 round 1, row D6 (CLARIFY). Owner, 2026-10-27: "Add them (Recommended)".

## Problem

After AZ-3290 Java loads with `FrameSession.load(key, epoch, tagLen, FrameDirection...)`. Rust, C# and Swift load with a `FrameConfig` that holds the tag length and a `FrameDirections` set (D1 lists both names). The frame ports of loop 75 copy one shape; the owner chose the shared one.

## Outcome

- Java has `FrameConfig` (tag length, `FrameDirections`) and `FrameDirections` (an immutable set of `FrameDirection`, with every direction available as one value, as `ALL` in C#, `.all` in Swift, `FrameDirections::ALL` in Rust); `FrameSession.load(key, epoch, FrameConfig)` is the one load; the varargs load is gone (0.x).
- A null config or a null set loads nothing (null), as a bad tag length does; an empty set loads a session that refuses every call, as in Rust, C# and Swift; frame bytes are unchanged.

## Scope

### Included
- `java/src/main/java/packbin/` (the two new types, `FrameSession.load`), the Java frame tests, the README Java frame example (the parent applies the README hunk) and its example test.

### Excluded
- Other packages; the wire; the error kinds.

## Acceptance Criteria

**AC-1: The shared load shape**
Given the Java public API (`javap -public`)
When it is listed
Then `FrameConfig` and `FrameDirections` are present, `FrameSession.load` takes `(byte[], int, FrameConfig)` and 0 varargs `load` overloads remain

**AC-2: Bytes unchanged**
Given `fixtures/frame/vectors.txt`
When the Java vector test runs
Then 157 of 157 rows pass

**AC-3: Refusals**
Given a null `FrameConfig`, a null `FrameDirections`, and a tag length of 5
When each is loaded
Then each loads nothing (null); an empty set loads a session whose every seal and open is `BadValue` (as in Rust, C# and Swift); and a call in a direction outside the loaded set is `BadValue` (3 load refusals, 1 empty-set case, 1 call case)

Spec corrected 2026-10-27 after implementation: the first text refused an empty set at load, which no other frame package does.

**AC-4: README example**
Given `scripts/frame/readme-examples.sh`
When it runs
Then PASS for Java (and C#, Swift, Rust)

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `javap -public` listing | the two types, one `load` |
| AC-2 | vector test | 157/157 |
| AC-3 | load refusal tests | null, null, null; empty set loads, every call `BadValue`; outside-the-set call `BadValue` |
| AC-4 | `readme-examples.sh` | PASS |

## Constraints

- Android API 26 (`java/api-check.sh`): no `Set.of` (API 30); an `EnumSet` inside an immutable wrapper or a bit mask is fine.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Android callers change their `load` call a second time this loop | owner, 2026-10-27 (D6 option A) | accepted-risk | Low |
