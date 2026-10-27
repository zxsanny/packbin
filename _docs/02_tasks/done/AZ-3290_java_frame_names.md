---
loop: 74
branch: dev
---

# Java frame types with the D1 names and a direction enum

**Task**: AZ-3290_java_frame_names
**Name**: Java frame mode with `FrameSlot`, `FrameOpened`, `FrameSealed` as top-level types and a `FrameDirection` enum
**Description**: A Java frame user writes the same type names as a C#, Rust or Swift user.
**Complexity**: 3 points
**Dependencies**: AZ-3282_java_stream_removal
**Component**: 06_java_package
**Tracker**: AZ-3290
**Epic**: AZ-3199

## Problem

Java nests `Slot`, `Opened` and `Sealed` inside `FrameSession` and takes a direction as an `int` (`FrameSession.UP = 1`, `DOWN`, `GROUP`); D1 names `FrameSlot`, `FrameOpened`, `FrameDirection` (and `FrameSealed` for Java's seal result).

## Outcome

- Java's public frame types: `FrameSession`, `FrameDirection`, `FrameSlot`, `FrameOpened`, `FrameSealed`, `MsgContext`, `ReplayWindow`, `Freshness`, `MacKey`; seal, open and load take `FrameDirection`; the frame bytes are unchanged.

## Scope

### Included
- `java/src/main/java/packbin/FrameSession.java` and the new top-level types; the Java frame tests and the vector test; `api-check.sh` (the expected public list).
- The Java README frame example and its example test change together; the README hunk is applied by the parent of the batch.

### Excluded
- The Java direction byte on the wire (still 1, 2, 3, from the enum); the other packages; docs other than the README frame example (AZ-3291).

## Acceptance Criteria

**AC-1: The D1 names**
Given `api-check.sh`
When the public API is listed
Then it shows the types above and 0 of `FrameSession.Slot`, `FrameSession.Opened`, `FrameSession.Sealed`, `FrameSession.UP`, `DOWN`, `GROUP`

**AC-2: Bytes unchanged**
Given `fixtures/frame/vectors.txt`
When the Java vector test runs
Then 157 of 157 rows pass

**AC-3: Directions out of range cannot be expressed**
Given a caller that passes a direction
When it compiles
Then only the 3 enum values exist, and a direction the session did not load is still refused as `BadValue` (1 test)

**AC-4: README example**
Given `scripts/frame/readme-examples.sh`
When it runs
Then 0 differences between the Java README frame example and its test

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `api-check.sh` | listed types; 0 old names |
| AC-2 | vector test | 157/157 |
| AC-3 | not-loaded direction test | `BadValue` |
| AC-4 | `readme-examples.sh` | 0 differences |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Android callers of the Java frame API change their code | owner D1 | accepted-risk | Low |
