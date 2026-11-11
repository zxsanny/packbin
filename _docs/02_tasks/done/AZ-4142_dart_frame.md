---
loop: 99
branch: dev
---

# Dart: frame mode (`FrameSession`, `MacKey`, replay window, key wipe)

**Task**: AZ-4142_dart_frame
**Name**: Dart: frame mode (`FrameSession`, `MacKey`, replay window, key wipe)
**Description**: Sealed frames in Dart with the shared names and the 157 shared vectors.
**Complexity**: 5 points
**Dependencies**: AZ-4141_dart_crypto
**Component**: dart
**Tracker**: AZ-4142
**Epic**: AZ-4133

## Problem

Frame mode (ADR-008, ADR-009, `pack-session.md` 3.0.0) seals a packed message with a key so a radio link cannot read or forge it. Dart needs it with the shared names and the same bytes.

Feature criteria, scenarios and decisions: `_docs/02_task_plans/dart-package/` (`acceptance_criteria.md` DT-1 to DT-20, `scenarios.md`, `problem.md` D-1 to D-5 and A-1 to A-7, `task_map.md` for the write sets).

## Outcome

- All 157 rows of `fixtures/frame/vectors.txt` pass in Dart.
- Refusals are result values; keys are zeroed on `close()`.

## Scope

### Included

- `FrameSession` (load, seal, open, set and clear a previous key, close), `FrameConfig`, `FrameDirection`, `FrameDirections`, `FrameSlot`, `FrameOpened`, `MsgContext`, `ReplayWindow` (caller-owned, 64 messages), `Freshness`, `MacKey` (derive, tag, verify; tags of 4, 8, 16 or 32 bytes; frame tags of 4, 8 or 16).
- Caller-owned output buffers with `buffer_full` when too small, as TypeScript.
- A loader of the frame vectors and tests for the five operations (keys, seal, open, mac, replay).
- Owns: `dart/lib/src/frame*`, `mac_key*`, `replay*` and their tests.

### Excluded

- The frame ring (AZ-4146)
- The README frame example test (AZ-4148)

## Acceptance Criteria

**AC-1: Frame vectors (DT-6)**
Given every row of `fixtures/frame/vectors.txt`
When run in Dart
Then the row's keys, sealed bytes, opened text, tag, or refusal kind; mismatched bytes 0

**AC-2: Refusals as values (DT-6)**
Given a bad key length, a tag length that is not allowed, a text over the bound, a small output buffer, a forged tag
When load, seal, open or tag is called
Then a result with `bad_value`, `too_long`, `buffer_full` or `tag_mismatch`; exceptions 0; the output buffer holds no plain text after a `tag_mismatch`

**AC-3: Replay and close (DT-6, S10)**
Given an opened frame presented again, a frame older than the 64-message window, and a session after `close()`
When opened
Then `duplicate`, `too_old`, and a refusal after close; every key buffer of the closed session reads 0; a second `close()` is harmless

**AC-4: Tag compare**
Given two forged tags, one wrong in byte 0 and one wrong in the last byte
When verified
Then both are refused and the compare reads every byte of the tag (a fold with no early exit; checked with a counting test hook)

**AC-5: Previous key**
Given a frame sealed with the previous key after a key change, and the same after the previous key is cleared
When opened
Then opened with the slot named as previous; refused after the clear

## Non-Functional Requirements

**Reliability**
- Uncaught exceptions from unpack on any input: 0.

**Compatibility**
- Dart 3.13 and newer, native targets (VM and ahead-of-time); no web.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | Frame vectors: every row of `fixtures/frame/vectors.txt` | the row's keys, sealed bytes, opened text, tag, or refusal kind; mismatched bytes 0 |
| AC-2 | Refusals as values: a bad key length, a tag length that is not allowed, a text over the bound, a small output buffer, a forged tag | a result with `bad_value`, `too_long`, `buffer_full` or `tag_mismatch`; exceptions 0; the output buffer holds no plain text after a `tag_mismatch` |
| AC-3 | Replay and close: an opened frame presented again, a frame older than the 64-message window, and a session after `close()` | `duplicate`, `too_old`, and a refusal after close; every key buffer of the closed session reads 0; a second `close()` is harmless |
| AC-4 | Tag compare: two forged tags, one wrong in byte 0 and one wrong in the last byte | both are refused and the compare reads every byte of the tag (a fold with no early exit; checked with a counting test hook) |
| AC-5 | Previous key: a frame sealed with the previous key after a key change, and the same after the previous key is cleared | opened with the slot named as previous; refused after the clear |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | the `dart` service of `docker-compose.test.yml` (from AZ-4145 on) or `dart test` in `dart/` | the task's tests run on the real package and the shared fixtures read as files | all pass; no fixture is copied into the test code | Reliability |

## Constraints

- `pack-session.md` 3.0.0 is the contract; names are the shared frame names (owner decision D1 of loop 74).
- A `FrameSession` is used by one isolate at a time (documented, DT-14).
- Keys are wiped on `close()`; Dart has no wipe at garbage collection (accepted risk in `problem.md`).
- No file over 500 lines.

## Risks & Mitigation

**Risk 1: Buffers that alias**
- *Risk*: Seal and open in place when input and output are views of one buffer.
- *Mitigation*: The TypeScript rule is copied and pinned by a test.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| None beyond the feature's concerns in `problem.md` | — | resolved | Low |
