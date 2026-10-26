---
loop: 74
branch: dev
---

# Swift without the stream session; `MsgContext`

**Task**: AZ-3285_swift_stream_removal_and_names
**Name**: Remove `PackSession` from the Swift package and rename `MessageContext` to `MsgContext`
**Description**: Swift offers frame mode as its only session, with the D1 frame names.
**Complexity**: 3 points
**Dependencies**: AZ-3280_ring_ci_stream_removal
**Component**: 08_swift_package
**Tracker**: AZ-3285
**Epic**: AZ-3199

## Problem

`swift/Sources/Packbin/PackSession.swift` and `SessionKeys.swift` are the stream session (ADR-009). Swift's frame types already match D1 except `MessageContext` (D1: `MsgContext`). The README example test requires the README "Encrypted session / Swift" block.

## Outcome

- 0 public stream-session types; the frame types carry the D1 names; frame bytes unchanged.

## Scope

### Included
- Delete `PackSession.swift`, `SessionKeys.swift`, `Tests/PackbinTests/SessionTests.swift`, `SessionHostileTests.swift` (with the helpers they share: `sessionPair`, `sessionCipherHex`).
- Mixed tests keep their non-session halves: `EccSchemeTests.swift` (the `EccSessionTests` suite goes), `EccDispatchOrderTests.swift`.
- `ReadmeExampleTests.swift` and the README Swift blocks it reads change together: the session snippet and the README "Encrypted session / Swift" block go; the frame example uses `MsgContext`.
- `MessageContext` becomes `MsgContext` in sources, tests and the DocC catalog (`Packbin.docc/Packbin.md`, whose `### Session` section goes); wording in `ChaCha20.swift`, `FrameSession.swift`, `Unpack.swift`, `ChaCha20Tests.swift`.
- `fixtures/hostile/fuzz/swift/audit41_probe/`: session parts out.

### Excluded
- `Package.swift` and `swift-crypto` (frame mode still uses it off Apple platforms); the rest of README (AZ-3291).

## Acceptance Criteria

**AC-1: No stream session**
Given the Swift package
When `git grep -nE 'PackSession|sessionKeys|MessageContext' swift Package.swift fixtures/hostile/fuzz/swift` runs
Then it finds 0 hits

**AC-2: Frame and crypto unchanged**
Given the frame and crypto fixtures
When `swift test` runs
Then 157 of 157 frame rows and 27 of 27 crypto rows pass

**AC-3: README examples are the snippets**
Given the README Swift blocks
When `ReadmeExampleTests` and `scripts/frame/readme-examples.sh` run
Then both pass with 0 differences

**AC-4: Suite green**
Given `swift test` (and the release `swift_speed` build of `run-suite.sh`)
When they run
Then 0 tests fail

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | the grep | 0 hits |
| AC-2 | frame and crypto vector suites | 157/157, 27/27 |
| AC-3 | `ReadmeExampleTests`, `readme-examples.sh` | pass, 0 differences |
| AC-4 | the Swift suite | 0 failures |

## Constraints

- A Swift test hook is `package`, never `@_spi` or `@testable` (`AGENT_GOTCHAS.md`, loop 72).
- `README.md` has one writer at a time: the Swift README hunks are applied by the parent of the batch.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The rename is a source change for a Swift frame user | owner D1 | accepted-risk | Low |
