---
loop: 72
branch: dev
---

# C# frame hardening: no key hooks shipped, pad wipe, Load with no direction, Seal with overlapping buffers

**Task**: AZ-3254_csharp_frame_hardening
**Name**: C# frame hardening
**Description**: The C# package's pad and HMAC temporaries are wiped, and its test hooks stay `internal` (owner decision B). `Load` with no direction builds a refusing session, as the other packages do. `Seal` gives the same bytes whatever the buffer overlap.
**Complexity**: 3 points
**Dependencies**: None (document dependency: `_docs/02_document/contracts/library/pack-session.md` 2.0.0)
**Component**: C# package (`csharp/`)
**Tracker**: AZ-3254
**Epic**: AZ-3199

## Problem

The loop 71 security review (`_docs/05_security/frame_mode_managed_loop71.md`) carried four items in the C# package that meshbell's C# server runs:

- item 5: internal test hooks return live key arrays and the MAC count, and `InternalsVisibleTo("Packbin.Tests")` grants them to any assembly that takes that name;
- item 6: `SessionPad.Block` leaves the 16-word `state` and `work` spans unwiped, and `Seal` leaves its 32-byte HMAC output unwiped;
- item 8: `FrameSession.Load` returns null for an empty direction set, where Rust, Java and Swift build a session that refuses every call;
- item 10: `Seal` writes `clear` into `output` before it reads `plain` and `ad`, so overlapping buffers give a wrong frame.

Loop plan: `_docs/02_task_plans/frame-hardening-csharp-java-swift/`.

## Outcome

- Owner decision B (2026-10-26): the test hooks `FrameSession.KeyArrays()`, `CurrentKeys`, `MacComputations` and `MacKey.KeyArray` stay `internal`, reached through `InternalsVisibleTo("Packbin.Tests")`, the official .NET mechanism. Item 5 is accepted for C#: an access level is API hygiene, not a boundary against code in the same process.
- `SessionPad.Block` zeroes `state` and `work` before it returns. `Seal` zeroes its `full` span after the tag is copied out. Both use `Compat.Zero`, which is `CryptographicOperations.ZeroMemory` on net10.0 and the kept clear on netstandard2.0.
- `Load` with `FrameDirections.None` returns a session; `Seal` and `Open` on it return `BadValue` and write nothing. The XML doc of `Load` no longer lists "no direction" as a refusal.
- `Seal` reads `ad`, `clear` and `plain` in full before its first write to `output`. It builds `clear ‖ ciphertext ‖ tag` in a stack buffer of at most 255 bytes, then copies that buffer out. On a refusal nothing is written, as before.

## Scope

### Included
- `csharp/FrameSession.cs`, `csharp/MacKey.cs`, `csharp/FrameKeys.cs` (only if a hook lives there), `csharp/SessionPad.cs`, and the frame tests in `csharp/tests/` (`FrameReplayTests.cs`, `FrameRefusalTests.cs`, `FrameVectors.cs`, `FrameWipeAndCompareTests.cs`, `FrameSupport.cs` or a new test-support file).

### Excluded
- Keeping or removing `InternalsVisibleTo`. Other internals stay test-visible; no internal member reached from a session or `MacKey` instance returns key material any more.
- Java and Swift (AZ-3255, AZ-3256); Rust; wire bytes; `fixtures/`; README text (only the API doc of `Load` changes).
- Hardening `HKDF` temporaries beyond what the code-read list (AC-2) names.

## Acceptance Criteria

**AC-1: Test hooks stay internal (decision B)**
Given the C# package
When its source is read
Then the hooks `KeyArrays()`, `CurrentKeys`, `MacComputations` and `MacKey.KeyArray` are `internal` (none `public`), and `dotnet test csharp -c Release --filter "FullyQualifiedName~Nfr_PublicTyped"` (stage `ac10`) still compiles and passes.

**AC-2: Pad and HMAC temporaries wiped**
Given `SessionPad.Block` and `FrameSession.Seal`
When they return
Then `state`, `work` and the `full` HMAC span have been passed to `Compat.Zero`. The batch report lists every C# frame and pad temporary that holds key-derived words, pad bytes or a full HMAC, each with its wipe; `MacKey` and `Matches` already zero `full`.

**AC-3: `Load` with no direction**
Given a 32-byte key, epoch 0, tag length 4, 8 or 16 and `FrameDirections.None`
When `FrameSession.Load` runs
Then it returns a session (not null), and `Seal` and `Open` in directions 1, 2 and 3 return `BadValue` and write nothing. A key that is not 32 bytes, an epoch above 0xFFFFFF, a tag length outside 4, 8 or 16, or a direction bit outside `All` still returns null.

**AC-4: `Seal` with overlapping buffers**
Given row `E1.seal` of `fixtures/frame/vectors.txt`
When `Seal` runs with `plain` at `output[clear.Length..]` (in place), with `plain` at `output[0..]`, with `clear` at `output[0..clear.Length]` followed by `plain`, and with `ad` inside `output`
Then each `output` equals the E1 body byte for byte. A refusal still writes nothing.

**AC-5: Bytes unchanged**
Given the 157 rows of `fixtures/frame/vectors.txt`, the 27 rows of `fixtures/crypto/vectors.txt` and the stream session tests
When `env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --nologo` runs on both targets
Then every test passes, and the load-aware timing checks pass with no new fixed bound.

## Non-Functional Requirements

**Performance**
- One more 64-byte clear per ChaCha20 block and one 255-byte stack copy per seal. The existing `Timing.Bound` checks pass.

**Compatibility**
- netstandard2.0 and net10.0 both build with `-warnaserror` as today. The public API changes only in `Load` with no direction, from null to a session.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | existing wipe, replay-refusal-no-MAC and `keys` vector tests through the internal hooks | pass |
| AC-3 | `Load` with `None`; `Seal` and `Open` in directions 1 to 3; the four other refusals | session; `BadValue` with 0 bytes written; null |
| AC-4 | E1 sealed with the four overlap layouts | E1 body each time |
| AC-5 | full C# suite, both targets | green |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-5 | `scripts/loop-tests.sh` stages `csharp`, `ac10`, `ring` | C# suite, Release build of the tests, cross-language stream ring | PASS | Compatibility |

## Constraints

- Fit decision F1 (`feature-description.md`, owner decision B): the hooks stay `internal` as at loop 71.
- Fit decision F3: build the body in a stack buffer and write to `output` last. Do not refuse overlap.
- `Compat.Zero` is the one wipe helper. Do not add a second one.

## Risks & Mitigation

**Risk 1: A copied stack buffer of 255 bytes per seal**
- *Risk*: one more copy per seal.
- *Mitigation*: the timing checks of the suite bound the session.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A wipe of a stack span is best effort under the JIT | L71-1, documented | accepted-risk | Low |
| `Load` with no direction changes from null to a session | owner, 2026-10-25 | resolved | Low |
