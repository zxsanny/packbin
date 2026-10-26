---
loop: 72
branch: dev
---

# Java frame hardening: no key hooks shipped, pad and HMAC wipe, per-instance MAC counter

**Task**: AZ-3255_java_frame_hardening
**Name**: Java frame hardening
**Description**: The Java package's pad and HMAC temporaries are wiped, each session and MAC key counts its own MAC computations with no static counter, and its test hooks stay package-private (owner decision B).
**Complexity**: 3 points
**Dependencies**: None (document dependency: `_docs/02_document/contracts/library/pack-session.md` 2.0.0)
**Component**: Java package (`java/`)
**Tracker**: AZ-3255
**Epic**: AZ-3199

## Problem

The loop 71 security review (`_docs/05_security/frame_mode_managed_loop71.md`) carried three items in the Java package that meshbell's Android app runs:

- item 5: package-private test hooks (`encKeyForTest`, `macKeyForTest`, `macComputationsForTest`, `MacKey.keyForTest`) ship in the jar, and any class compiled into `package packbin` on the classpath can call them;
- item 6: `SessionPad.block` leaves the 16-word `state` and `work` arrays unwiped, and the 32-byte `full` HMAC outputs in `FrameSession` and `MacKey` are not wiped;
- item 7: every HMAC increments one `static AtomicLong` (`FrameCrypto.MAC_COMPUTATIONS`), which is shared by all sessions and threads and lives on the production path.

Loop plan: `_docs/02_task_plans/frame-hardening-csharp-java-swift/`.

## Outcome

- Owner decision B (2026-10-26): the hooks `encKeyForTest`, `macKeyForTest` and `MacKey.keyForTest` stay package-private, the official Java mechanism; `macComputationsForTest()` becomes an instance method of `FrameSession` and of `MacKey` that reads the per-instance counter. Item 5 is accepted for Java: an access level is API hygiene, not a boundary.
- `SessionPad.block` fills `state` and `work` with zero before it returns. `FrameSession` and `MacKey` fill each `full` HMAC array with zero once the tag is copied or compared.
- `FrameCrypto` holds no static field that changes after class load. `FrameSession` and `MacKey` each keep a private `AtomicLong` that counts their own MAC computations.

## Scope

### Included
- `java/src/main/java/packbin/FrameSession.java`, `MacKey.java`, `FrameCrypto.java` and `SessionPad.java`, plus the frame tests in `java/src/test/java/packbin/` (`FrameLifecycleTest.java`, `FrameRows.java`, `FrameTamperReplayTest.java`, and a new test-support class). Add a new test class to `java/test.sh` if it has a `main` of its own.
- One guard test (`FrameStaticStateTest`): reflection over `FrameSession`, `MacKey`, `FrameCrypto` and their nested classes finds no `static` field that is not `final` or that holds an atomic type.

### Excluded
- A sealed jar manifest; the module system.
- C# and Swift (AZ-3254, AZ-3256); Rust; wire bytes; `fixtures/`; README.
- The stream session's `sendCount` (`PackSession`), which is a per-instance send counter of the stream contract, not a MAC counter.

## Acceptance Criteria

**AC-1: Test hooks stay package-private (decision B)**
Given the Java main sources
When they are read
Then `encKeyForTest`, `macKeyForTest`, `macComputationsForTest` (on `FrameSession` and on `MacKey`) and `MacKey.keyForTest` are package-private, none `public` or `protected`, and the wipe, replay and `keys` row tests use them.

**AC-2: Pad and HMAC temporaries wiped**
Given `SessionPad.block`, `FrameSession` and `MacKey`
When a block, a tag or a MAC is computed
Then `state`, `work` and every 32-byte `full` array are filled with zero before the method returns. The batch report lists every Java frame and pad temporary that holds key-derived words, pad bytes or a full HMAC, each with its wipe.

**AC-3: Per-instance MAC counter**
Given two sessions, A and B
When A opens a frame and B refuses a replay (Duplicate or TooOld)
Then A's count rises by the MACs it started and B's count does not move. No static field in `FrameCrypto`, `FrameSession` or `MacKey` changes after class load. The batch report records the result of one run of the replay-refusal test against a copy of `open` that computes the tag before the window check: the test must fail on that copy.

**AC-4: Bytes unchanged**
Given the 157 rows of `fixtures/frame/vectors.txt`, the 27 rows of `fixtures/crypto/vectors.txt` and the stream session tests
When `java/test.sh` runs (including the Android API 26 signature check)
Then every test passes, and the load-aware timing checks (`Timing.bound`) pass with no new fixed bound.

## Non-Functional Requirements

**Performance**
- Two more 64-byte clears per ChaCha20 block, and an uncontended per-instance increment in place of the shared static one. The existing `Timing.bound` checks pass.

**Compatibility**
- `javac --release 17` and the Android API 26 signature check (`java/api-check.sh`) stay green. The public API does not change.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | existing lifecycle (wipe), tamper/replay and `keys` row tests through the hooks | pass |
| AC-3 | `FrameStaticStateTest`: no non-final or atomic static field | holds |
| AC-3 | two sessions, one open and one replay refusal | A rises; B unchanged |
| AC-4 | full `java/test.sh` | green |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-4 | `scripts/loop-tests.sh` stages `java`, `ring` | Java suite and cross-language stream ring | PASS | Compatibility |

## Constraints

- Fit decision F1 (`feature-description.md`, owner decision B): the hooks stay package-private. Do not seal the jar.
- Fit decision F2: use a per-instance `AtomicLong` in `FrameSession` and in `MacKey`. Do not use a static field.
- Tests have no framework: each class has a `main`, and `PackbinTest.expectTrue` is the assertion. Fixtures are read relative to the repository root.

## Risks & Mitigation

**Risk 1: The per-instance counter costs an atomic increment per MAC**
- *Risk*: a little work on the production path.
- *Mitigation*: uncontended per object, unlike the old shared static; the timing checks bound it.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| JIT escape analysis may drop a fill of a local array that does not escape | L71-1, documented | accepted-risk | Low |
