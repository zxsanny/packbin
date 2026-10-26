---
loop: 72
branch: dev
---

# Swift frame hardening: key accessors internal, pad wiped through the kept wipe helper

**Task**: AZ-3256_swift_frame_hardening
**Name**: Swift frame hardening
**Description**: The Swift test hooks use `package` access instead of the unofficial `@_spi(Vectors)`, and the ChaCha20 pad and the stream session keys are zeroed through the wipe helper the optimizer keeps.
**Complexity**: 2 points
**Dependencies**: None (document dependency: `_docs/02_document/contracts/library/pack-session.md` 2.0.0)
**Component**: Swift package (`swift/`)
**Tracker**: AZ-3256
**Epic**: AZ-3199

## Problem

The loop 71 security review (`_docs/05_security/frame_mode_managed_loop71.md`) carried two items in the Swift package that meshbell's iOS app runs:

- item 5: `FrameSession.derivedKeys(for:previous:)` and `MacKey.storedKey` are `public`, so any app can read the live keys. The `@_spi(Vectors)` surface is a test hook too: any app that writes `@_spi(Vectors) import Packbin` gets `FrameProbe` (`onMac` counts MACs, `onRelease` receives key bytes), `load(key:epoch:config:probe:)` and the ChaCha20 and HMAC primitives (parent, loop 72, found while the worker ran);
- item 6: `ChaCha20` zeroes its pad with a plain `for` loop that the optimizer may drop.

Loop plan: `_docs/02_task_plans/frame-hardening-csharp-java-swift/`.

## Outcome

- Owner decision B (2026-10-26): every `@_spi(Vectors) public` declaration (`derivedKeys(for:previous:)`, `storedKey`, `FrameProbe`, `FramePrimitives`, `ChaCha20`, `load(…probe:)`, `derive(…probe:)`) becomes `package` (SE-0386), members included; the tests use a plain `import Packbin` (no `@testable`, no SPI), so the one release test build (`run-suite.sh` `swift_speed`) needs no extra flag.
- `ChaCha20` zeroes its pad through `FrameCrypto.wipe` (`@inline(never) @_optimize(none)`), and so does the stream `PackSession.wipe` (owner decision 2); no plain zeroing loop is left in the pad, session, frame or MAC code.

## Scope

### Included
- `swift/Sources/Packbin/FrameSession.swift`, `MacKey.swift`, `ChaCha20.swift`, `FrameCrypto.swift`, `PackSession.swift` (the wipe only), and every test file that imported the `Vectors` SPI.

### Excluded
- C# and Java (AZ-3254, AZ-3255); Rust; wire bytes; `fixtures/`; README (it shows neither member). The DocC catalogue changes only if it names them.

## Acceptance Criteria

**AC-1: Hooks in `package` access only (decision B)**
Given the Swift package
When `grep -rn -E '_spi|@testable' swift` runs, the strict release test build `swift build -c release --build-tests -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete` runs with no `-enable-testing`, and a probe file outside the package (`import Packbin`, then `@_spi(Vectors) import Packbin`) calling `derivedKeys(for:)`, `storedKey` or `FrameProbe(onMac:)` is type-checked against the built module
Then the grep prints nothing, the release build passes with 0 warnings, and the probe fails with "inaccessible due to 'package' protection level" (or "cannot find in scope"). The batch report records the probe output.

**AC-2: Pad wiped through the kept helper**
Given `ChaCha20`
When the pad loop ends
Then the pad is zeroed by `FrameCrypto.wipe` or a helper with the same `@inline(never) @_optimize(none)` attributes. The batch report lists every Swift frame and pad temporary that holds key-derived words, pad bytes or a full HMAC, each with its wipe.

**AC-3: Bytes unchanged**
Given the 157 rows of `fixtures/frame/vectors.txt`, the 27 rows of `fixtures/crypto/vectors.txt` and the stream session tests
When `swift test` runs on this Mac (and in the Linux CI job)
Then every test passes, including `readme_swiftBlocks_areTheSnippets`, and the load-aware timing checks (`expectWithin`) pass with no new fixed bound.

## Non-Functional Requirements

**Performance**
- One out-of-line call per stream or frame cipher run in place of an inlined loop. The existing timing checks pass.

**Compatibility**
- Swift 6 language mode as today. The public API loses two test-only members; no published version exists yet (the first tags are still pending).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | existing wipe, replay and `keys` vector tests with a plain `import Packbin` | pass |
| AC-1 | strict release test build without `-enable-testing`; probe from outside the package | passes; compile error, recorded |
| AC-3 | full `swift test` | green |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | `scripts/loop-tests.sh` stages `swift`, `ring` | Swift suite (Docker Linux stage too) and cross-language stream ring | PASS | Compatibility |

## Constraints

- Fit decision F1 (`feature-description.md`, owner decision B): `package` access. No `@testable`, no SPI, no `Mirror`.
- Only one `swift build` or `swift test` runs at a time in the root tree (SwiftPM locks `.build`).

## Risks & Mitigation

**Risk 1: `package` access can be claimed by a compiler flag**
- *Risk*: a module compiled with `-package-name packbin` sees the hooks.
- *Mitigation*: accepted (decision B): no access level is a boundary inside one process; it keeps the hooks out of the normal API.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Swift states no guarantee that no copy of an array was made before a wipe | L71-1, documented | accepted-risk | Low |
