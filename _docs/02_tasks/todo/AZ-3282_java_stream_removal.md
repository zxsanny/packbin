---
loop: 74
branch: dev
---

# Java without the stream session

**Task**: AZ-3282_java_stream_removal
**Name**: Remove `PackSession` from the Java package
**Description**: The Java package offers frame mode as its only session.
**Complexity**: 2 points
**Dependencies**: AZ-3280_ring_ci_stream_removal
**Component**: 06_java_package
**Tracker**: AZ-3282
**Epic**: AZ-3199

## Problem

`java/src/main/java/packbin/PackSession.java` is the stream session (ADR-009 removes it); its tests and the mixed ECC and strictness tests still use it.

## Outcome

- 0 public stream-session types or members; frame mode, clear pack and message ECC unchanged.

## Scope

### Included
- Delete `PackSession.java`, `SessionTest.java`, `HostileSessionTest.java`; `test.sh` and `PackbinTest.java` stop running them.
- `SessionPad.java`: the stream-only parts (the 3-argument HKDF with the "packbin" info, the packet-counter `xor`, `writeU64Le`); the frame parts stay.
- Mixed tests keep their non-session halves: `EccSchemeTest.java`, `EccDispatchOrderTest.java`, `MissingNestedValueTest.java`, `PackStrictTest.java`, `TimesLongerTest.java`.
- Wording in `FrameSession.java`, `CryptoVectorsTest.java`.
- `fixtures/hostile/fuzz/java/` probes: session parts out.

### Excluded
- The frame renames (AZ-3290); README (AZ-3291); the Java ring driver (AZ-3280).

## Acceptance Criteria

**AC-1: No stream session**
Given the Java package
When its public API is listed (`api-check.sh`)
Then 0 types or members load a seed, start, join, or pack and unpack on a counter

**AC-2: Frame and crypto unchanged**
Given the frame and crypto fixtures
When the Java suite runs
Then 157 of 157 frame rows and 27 of 27 crypto rows pass

**AC-3: Suite green**
Given `java/test.sh`
When it runs
Then 0 tests fail, and the clear and ECC tests of the mixed files still run (count recorded before and after)

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `git grep PackSession java fixtures/hostile/fuzz/java` | 0 hits |
| AC-2 | frame and crypto vector tests | 157/157, 27/27 |
| AC-3 | `java/test.sh` | 0 failures |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| None beyond `problem.md` | — | resolved | Low |
