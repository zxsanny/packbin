# Frame mode in TypeScript

**Task**: AZ-3295_typescript_frame_mode
**Name**: `FrameSession`, `ReplayWindow` and `MacKey` in the TypeScript package, equal to Rust on the frame and crypto rows
**Description**: A TypeScript caller seals and opens the same authenticated frames as Rust, C#, Java and Swift.
**Complexity**: 5 points
**Dependencies**: AZ-3288_typescript_stream_removal_crypto (loop 74), AZ-3291_docs_stream_removal (loop 74)
**Component**: 02_typescript_package
**Tracker**: AZ-3295
**Epic**: AZ-3199

Scheduled for loop 75 (owner D4, 2026-10-26). Not claimed by loop 74.

## Problem

After loop 74 (ADR-009) the TypeScript package has no session at all. Frame mode (`_docs/02_document/contracts/library/pack-session.md` 3.0.0, § Frame mode, § MAC-only call) exists in Rust, C#, Java and Swift. The TypeScript package already has verified SHA-256, HMAC-SHA256, HKDF-SHA256 and ChaCha20 in an internal module (loop 74, 27 of 27 crypto rows).

## Outcome

- The D1 types: `FrameSession`, `FrameConfig`, `FrameDirection`, `FrameDirections`, `FrameSlot`, `FrameOpened`, `MsgContext`, `ReplayWindow`, `Freshness`, `MacKey`, and the error kinds `TagMismatch`, `Duplicate`, `TooOld` beside the existing ones, under the same names as the other four packages (in TypeScript spelling).
- Load (key, epoch, directions, tag length), seal, open in the contract's normative order (argument checks, replay check, tag with the current key, then the previous key, decrypt, commit), set and clear the previous key, the caller-owned replay window, the MAC-only call.
- `FrameSession.close()` (and `Symbol.dispose` where the runtime has it) wipes the derived keys (best effort); `@noble/hashes` stays the only runtime dependency.
- A README "Frame session / TypeScript" example whose code is the code of an example test.

## Scope

### Included
- The TypeScript package sources and tests; its README frame example (one writer at a time for `README.md`); the component description, `module-layout.md` rows and the contract's consumer list.

### Excluded
- A cross-language frame ring (a candidate); changes to frame bytes or to the contract text.

## Acceptance Criteria

**AC-1: Frame rows**
Given `fixtures/frame/vectors.txt`
When the TypeScript vector test runs
Then 157 of 157 rows give the recorded body, result and error kind

**AC-2: Crypto rows**
Given `fixtures/crypto/vectors.txt`
When the TypeScript suite runs
Then 27 of 27 rows still pass

**AC-3: Open order and state**
Given a forged tag, a duplicate, a counter 64 or more below the top, and a frame under the previous key
When each is opened
Then the results are `TagMismatch`, `Duplicate` (no MAC computed), `TooOld` (no MAC computed) and `Ok` with slot `Previous`; the output buffer and the window are unchanged on every refusal (4 tests)

**AC-4: Names**
Given the TypeScript public API
When it is listed
Then the D1 names are present and spelled as in the other four packages

**AC-5: README example**
Given `scripts/frame/readme-examples.sh`
When it runs
Then 0 differences between the TypeScript README frame example and its test

**AC-6: Suite green**
Given `npm test` and the type check
When they run
Then 0 failures

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | frame vector test | 157/157 |
| AC-2 | crypto vector test | 27/27 |
| AC-3 | open-order and window tests | 4 results as stated |
| AC-4 | public API listing | D1 names |
| AC-5 | `readme-examples.sh` | 0 differences |
| AC-6 | the suite | 0 failures |

## Constraints

- The uniqueness rule (`msg_id` never sealed twice with different contents under one key, epoch and direction) is stated in bold in the README example, as in the other packages.
- The compare runs over every tag byte with no early exit; wipes are best effort and the limits of the runtime are written in the type's doc comment.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Concurrency rules of open, set-previous, clear-previous and close in TypeScript | the contract's rules; the loop 75 plan names the TypeScript mechanism | open | Low |
