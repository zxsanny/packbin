---
loop: 74
branch: dev
---

# C# without the stream session

**Task**: AZ-3281_csharp_stream_removal
**Name**: Remove `PackSession` from the C# package
**Description**: The C# package offers frame mode as its only session.
**Complexity**: 2 points
**Dependencies**: AZ-3280_ring_ci_stream_removal
**Component**: 01_csharp_package
**Tracker**: AZ-3281
**Epic**: AZ-3199

## Problem

`csharp/PackSession.cs` is the stream session (ADR-009 removes it). Its tests, its stream pad overload and the mixed ECC tests still use it.

## Outcome

- 0 public stream-session types or members; frame mode, clear pack and message ECC unchanged.

## Scope

### Included
- Delete `PackSession.cs`, `tests/SessionTests.cs`, `tests/HostileSessionTests.cs`, `tests/SessionPrivates.cs`.
- `SessionPad.cs`: the packet-counter `Xor` overload goes; the nonce overload and the block function stay (frame mode).
- Mixed tests keep their non-session halves: `EccSessionTextTests.cs` (EC-11 stays), `EccDispatchOrderTests.cs`, `TopRangeAndSessionTests.cs`, `WrittenWhenTests.cs`.
- Wording in `FrameSession.cs` and `tests/CryptoVectors.cs`.
- `fixtures/hostile/fuzz/csharp/` probes: session parts out, ECC parts kept.

### Excluded
- README (AZ-3291); the C# ring driver (AZ-3280).

## Acceptance Criteria

**AC-1: No stream session**
Given the C# package
When its public API is listed
Then 0 types or members load a seed, start, join, or pack and unpack on a counter

**AC-2: Frame and crypto unchanged**
Given `fixtures/frame/vectors.txt` and `fixtures/crypto/vectors.txt`
When the C# suite runs
Then 157 of 157 frame rows and 27 of 27 crypto rows pass

**AC-3: Suite green**
Given the C# suite (`env MSBUILDDISABLENODEREUSE=1 dotnet test csharp`)
When it runs
Then 0 tests fail, and the clear and ECC tests that were in mixed files still run (their count is recorded before and after)

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `git grep PackSession csharp fixtures/hostile/fuzz/csharp` | 0 hits |
| AC-2 | frame and crypto vector tests | 157/157, 27/27 |
| AC-3 | the C# suite | 0 failures |

## Constraints

- `MSBUILDDISABLENODEREUSE=1` on every `dotnet test` (`AGENT_GOTCHAS.md`).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| None beyond `problem.md` | — | resolved | Low |
