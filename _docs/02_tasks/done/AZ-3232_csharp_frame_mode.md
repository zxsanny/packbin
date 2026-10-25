---
loop: 71
branch: dev
---

# C# frame mode: FrameSession, ReplayWindow, MacKey

**Task**: AZ-3232_csharp_frame_mode
**Name**: C# frame mode: FrameSession, ReplayWindow, MacKey
**Description**: The C# package seals and opens radio frames per contract `pack-session.md` 2.0.0 on caller buffers, with a constant-time tag check, a previous-key slot, a caller-owned 64-message replay window and the MAC-only call, and matches the shared vectors byte for byte.
**Complexity**: 5 points
**Dependencies**: None (document dependency: `_docs/02_document/contracts/library/pack-session.md` 2.0.0)
**Component**: C# package (`csharp/`)
**Tracker**: AZ-3232
**Epic**: AZ-3199

## Problem

meshbell's first consumers outside the Rust field stack are the C# server, Android (through Java) and iOS (through Swift). They must seal and open frames that equal the Rust bytes, and check a 4-byte network MIC. Frame mode exists only in Rust (loop 69); the C# package has the stream session only, which needs ordered, lossless packets and does not detect a changed byte. Loop plan: `_docs/02_task_plans/frame-mode-csharp-java-swift/` (this task is first (owner order C#, Java, Swift)).

## Outcome

- A `FrameSession` type beside the stream `PackSession` (stream code, bytes and results untouched): load from a 32-byte key, a 24-bit epoch and a configuration (tag length 4, 8 or 16; directions up, down, group), with an optional previous (key, epoch) used by open only.
- `seal` (deterministic, stateless, thread-safe; on refusal nothing written) and `open` in the contract's order (argument checks, replay check without any MAC for `Duplicate` or `TooOld`, tag with the current slot then the previous slot, decrypt, commit the window) reporting slot `Current` or `Previous`.
- A `ReplayWindow` the caller owns (64 messages; `check` never changes state; `commit` only after `Ok`) and a `MacKey` for the MAC-only call (label key from HKDF, message hashed in parts, tags of 4, 8, 16 or 32 bytes, constant-time `verify`).
- Error kinds: three new error classes beside the existing ones (`TagMismatch`, `Duplicate`, `TooOld`).
- The tag compare folds every byte with no early exit; keys and MAC pad states are overwritten at Dispose (best effort, stated in the docs); the uniqueness rule for `msg_id` is in the API documentation of `seal` and of the message context.
- PB-02: the package's SHA-256, HMAC-SHA256, HKDF-SHA256 and ChaCha20 rows of `fixtures/crypto/vectors.txt` run through the primitives the package uses.

## Scope

### Included
- `csharp/` (new frame source files, the error classes next to `Uncorrectable`), `csharp/tests/`: frame source, error kinds, tests (frame vectors, primitive vectors, tamper, replay, previous slot, MAC-only, refusals, hostile corpus, wipe, tag compare, concurrency of `seal`), and a test file that holds the README example code for the docs task (The test project already reads fixtures through `TextVectors.RepositoryFile`; frame tests use that helper.)

### Excluded
- README, component descriptions, `module-layout.md`, contract Change Log (task AZ-3235; the parent edits shared docs).
- Stream-mode bytes and behaviour; the other packages; changes to `fixtures/frame/` or `fixtures/crypto/`.
- Scenario S11 (a caller reusing a `msg_id`): the library cannot check it; documented.
- A frame session built from a `PackSession`; a cross-language ring.

## Acceptance Criteria

**AC-1: Frame vectors** (S1, S3, S5, S7; AC-G1.1, AC-G3.2)
Given `fixtures/frame/vectors.txt`
When the C# suite loads every `keys`, `seal`, `open`, `mac` and `replay` row and compares every output field
Then 0 rows mismatch, E1 to E5 included, epoch 0xFFFFFF works, and epoch 0x1000000, direction 0 and 4, `kind` 16, `tag_len` 0, 5 and 32 give `BadValue`

**AC-2: Primitive vectors** (AC-G1.2)
Given `fixtures/crypto/vectors.txt`
When the suite runs its SHA-256, HMAC-SHA256, HKDF-SHA256, ChaCha20 block and ChaCha20 cipher rows
Then 0 of the 27 rows mismatch

**AC-3: Fixtures are not vacuous** (AC-G1.3)
Given a temp copy of each fixture with 1 expected byte changed
When the loader runs on it
Then it fails and names the row (2 of 2 fixtures)

**AC-4: Tampering never yields plaintext** (S4; AC-G2.1)
Given E1, E2 and E3
When every single bit of `ad`, `clear`, ciphertext and tag is flipped in turn, and `msg_id`, `kind`, direction, epoch and key are each changed
Then each open is `TagMismatch`, the output buffer still holds its sentinel bytes, and the window is unchanged

**AC-5: Replay before crypto** (S2, S3; AC-G2.2)
Given a window and a test-only counter of MAC computations
When a seen counter and a counter 64 or more behind the highest are opened
Then they give `Duplicate` and `TooOld` with 0 MAC computations and the window unchanged; a fresh valid body commits its counter; a fresh tampered body does not

**AC-6: Previous slot** (S5; AC-G2.3)
Given a session at (B, 7) with previous (A, 6)
When bodies sealed under (A, 6) and under (B, 7) are opened
Then the first gives `Ok` with `Previous`, the second `Ok` with `Current`, and with no previous slot the first is `TagMismatch`

**AC-7: MAC-only** (S8; AC-G2.4)
Given E4 and E5
When the tag is computed over 1, 2 and 3 parts and verified
Then every split gives the same tag, a flipped tag bit gives `false`, and a label of 0 or 33 bytes and `n` of 0, 2, 5 give `BadValue`

**AC-8: Refusals and hostile input** (S6; AC-G2.5)
Given each contract refusal and 1,000 random hostile bodies, lengths and `clear_len` values (fixed seed)
When seal and open run
Then each refusal returns its kind (`BadValue`, `TooLong`, `BufferFull`, `ShortPacket`, `TagMismatch`, `Duplicate`, `TooOld`), seal leaves 0 partial output bytes, and the hostile run causes 0 unhandled exceptions or crashes

**AC-9: Tag compare** (AC-G2.6)
Given the compare helper
When it compares equal tags, tags differing only in the first byte and only in the last byte
Then it returns equal, not equal, not equal, and the code reads every byte before it decides (reviewed, and no early return in the helper)

**AC-10: Wipe and use after release** (S10; AC-G2.7)
Given a loaded session and a `MacKey`
When the session is released (Dispose) and then used
Then the derived keys and pad states read as all zero through the package's test access, and the call gives `BadValue`

**AC-11: Concurrent seal** (S9)
Given one session and 8 threads
When each seals 1,000 distinct `msg_id`s
Then every body opens `Ok` and equals the single-thread seal of the same inputs (0 differing bytes)

**AC-12: Stream unchanged and targets** (S12; AC-G3.1, AC-G3.3)
Given the existing session vectors and tests
When the package suite runs with the new code
Then 0 stream bytes change and all existing tests pass; additionally:
Given the library multi-target build
When the C# suite runs on `net10.0` and again with `-p:PackbinTarget=netstandard2.0`
Then both runs pass with every frame and primitive row matching (0 mismatches) and no `CryptographicOperations` call is needed on `netstandard2.0`

## Non-Functional Requirements

**Performance**
- AC-10 of the project (speed) is unchanged; a wall-clock assertion in a new test uses the package's load factor helper, never a fixed bound.

**Compatibility**
- `net10.0` and `netstandard2.0` (`-p:PackbinTarget=netstandard2.0`); the C# suite runs with `MSBUILDDISABLENODEREUSE=1`.
- Source files at most 500 lines; tests in Arrange-Act-Assert form.

**Reliability**
- Best-effort wipe and constant-time compare are stated in the API documentation where the runtime may copy or optimize.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | frame fixture loader over all rows | 0 mismatches |
| AC-2 | primitive fixture loader | 0 of 27 mismatches |
| AC-3 | loader on corrupted copies | fails, names the row |
| AC-4 | single-bit tamper sweep of E1 to E3 | `TagMismatch`, sentinel intact, window unchanged |
| AC-5 | counter of MAC computations around duplicate / too-old opens | 0 computations |
| AC-6 | previous slot opens | `Previous` / `Current` / `TagMismatch` |
| AC-7 | MAC-only splits and refusals | same tag, `false`, `BadValue` |
| AC-8 | refusal list and hostile corpus | kinds as listed, 0 crashes |
| AC-9 | compare helper | equal / not equal / not equal |
| AC-10 | release then use | zeroed state, `BadValue` |
| AC-11 | 8-thread seal | bodies equal single-thread |
| AC-12 | existing session tests, target runs | pass |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | fixture file unchanged | whole-file replay through the public API | every field equals the row | project AC-3 |
| AC-12 | full package suite | stream tests and the new tests together | all pass on every target | project AC-11 |

## Constraints

- Frame pieces sit beside the shared pad code; the stream functions and `PackSession` are not touched (fit decision 1).
- Error kinds are added the way the package already adds them; no existing kind is renamed (fit decision 2).
- The MAC computation counter is internal and test-only (fit decision 3).
- No formatter or linter write on files this task does not own; commands end on their own (stdin from `/dev/null`).

## Risks & Mitigation

**Risk 1: Managed runtimes copy secrets**
- *Risk*: a GC or ARC copy of a key survives the wipe.
- *Mitigation*: wipe the arrays the package owns, keep keys in as few places as possible, and state the limit in the docs.

**Risk 2: Platform HMAC behaves differently on a target**
- *Risk*: `netstandard2.0`, Android API 26 or Linux swift-crypto differ in a corner (empty key, empty message).
- *Mitigation*: the primitive rows of AC-2 include the corners and run on every target.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Constant-time and wipe are best effort in managed runtimes | stated in docs (AC-9, AC-10) | accepted-risk | Medium |
| PB-02 SHA-256 rows run through the platform digest | owner chose primitive tests in the three packages | resolved | Low |
| Contract is Rust-first; a C# corner not in the vectors | open to the independent review at loop close | open | Low |
