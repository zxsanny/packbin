---
loop: 74
branch: dev
---

# Rust frame types with the D1 names

**Task**: AZ-3289_rust_frame_names
**Name**: Rename the Rust heap-free frame types to the C# set (`FrameSession` and the rest)
**Description**: A Rust frame user writes the same type names as a C#, Java or Swift user.
**Complexity**: 3 points
**Dependencies**: AZ-3284_rust_stream_removal
**Component**: 04_rust_package
**Tracker**: AZ-3289
**Epic**: AZ-3199

## Problem

After AZ-3284 the heap-free `Session` holds frame state only, and the Rust frame types are named `Session`, `Direction`, `Directions`, `Slot`, `Opened`, `MsgCtx`, where C# (and D1) say `FrameSession`, `FrameDirection`, `FrameDirections`, `FrameSlot`, `FrameOpened`, `MsgContext`.

## Outcome

- The public Rust frame API has the D1 names: `FrameSession`, `FrameConfig`, `FrameDirection`, `FrameDirections`, `FrameSlot`, `FrameOpened`, `MsgContext`, `ReplayWindow`, `Freshness`, `MacKey`; the frame bytes and the embedded figures are unchanged.

## Scope

### Included
- `rust/src/nostd/` (the session and frame modules, their re-exports), `rust/src/frame_core_tests.rs`, `frame_hostile_tests.rs`, `rust/tests/frame_vectors_tests.rs` and the other Rust tests and examples that name the frame types; `rust/embedded/probe/src/frame_extra.rs`.
- The Rust README frame example and its example test change together (`scripts/frame/readme-examples.sh`); the README hunk is applied by the parent of the batch.

### Excluded
- Error kinds (`TagMismatch`, `Duplicate`, `TooOld`) and constants (`MAX_BODY`) keep their names; docs other than the README frame example (AZ-3291).

## Acceptance Criteria

**AC-1: The D1 names**
Given the `nostd` public API
When `cargo doc` items are listed
Then the ten D1 names are present and 0 of `Session`, `Direction`, `Directions`, `Slot`, `Opened`, `MsgCtx` remain public

**AC-2: Bytes and figures unchanged**
Given `fixtures/frame/vectors.txt` and `rust/embedded/run.sh host`
When they run
Then 157 of 157 rows pass and every embedded figure equals the one AZ-3284 recorded (0 B moved)

**AC-3: README example**
Given `scripts/frame/readme-examples.sh`
When it runs
Then 0 differences between the Rust README frame example and its test

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | item listing, `git grep` of the old names | 10 present, 0 old |
| AC-2 | frame vectors, embedded run | 157/157, 0 B moved |
| AC-3 | `readme-examples.sh` | 0 differences |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| meshbell's Rust code names `Session` (another repository) | owner D1: rename; the README change note tells meshbell | accepted-risk | Low |
