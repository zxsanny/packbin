---
loop: 69
branch: dev
---

# Rust frame mode: seal, open, MacKey, ReplayWindow

**Task**: AZ-3203_rust_frame_mode_core
**Name**: Rust heap-free frame mode behind the `frame` feature (PB-04, part 1)
**Description**: The Rust package seals and opens frames per the contract on caller buffers with no heap, a constant-time tag check, a previous-key slot, a 64-message replay window and the MAC-only call; a Cargo feature `frame` builds it without the stream code.
**Complexity**: 5 points
**Dependencies**: AZ-3200_frame_mode_contract_and_adr, AZ-3201_primitive_vectors_python_and_rust, AZ-3202_frame_golden_vectors
**Component**: Rust package (`nostd` session, `session_core`, features)
**Tracker**: AZ-3203
**Epic**: AZ-3199

## Problem

meshbell's field stack is Rust: relays and packs on an nRF52840 seal their status and open one record, smart devices open commands and group frames, every node and the ESP32 station radio compute and check a 4-byte network MIC at every hop, and servers do the same with `std`. About fifty meshbell tasks are blocked on this. The Rust package has the heap-free `nostd` core and a stream session but no frame mode. Full spec: `_docs/02_task_plans/rust-m33f-and-frame-mode/input/PB-04_rust_frame_mode.md` (the proposed shape there may change in the contract; the capabilities may not).

## Outcome

- Cargo feature `frame` (needs no `alloc`; always on with `std`, as `session` is). With `default-features = false, features = ["frame"]` the crate builds `#![no_std]` with frame mode, the MAC-only call and the replay window, and none of the stream session.
- Frame mode in the `nostd` session: load with a key, epoch and configuration (tag length 4, 8 or 16; directions up, down, group); optional previous (key, epoch) used by open only; `seal_frame` (deterministic, stateless; on refusal nothing written; zeroed on a late error); `open_frame` in the contract's order (argument checks, replay check without any MAC for `Duplicate` or `TooOld`, tag with the current slot, then once with the previous slot, decrypt, commit the window) reporting `Current` or `Previous`.
- `MacKey` (HMAC pad states and epoch, at most 72 B, `Debug` without key bytes; `tag` over parts into 4, 8, 16 or 32 bytes; constant-time `verify`) and `ReplayWindow` (16 B; `check` never changes state; `commit` only after `Ok`).
- Keys and pad states are overwritten on drop; the tag compare folds every byte with no early exit and passes the accumulator through `core::hint::black_box`; no `unsafe`, no `unwrap`, `expect` or panicking index in the frame module (`#![forbid(unsafe_code)]` there); the uniqueness rule is in the rustdoc of `seal_frame` and the message context type.
- Test-only counters for ChaCha20 blocks and SHA-256 compressions.

## Scope

### Included
- A frame module under `rust/src/nostd/` and the frame pieces beside the shared pad, HMAC and HKDF in `rust/src/session_core/` (new functions; the stream functions are not touched); `rust/Cargo.toml` feature; Rust tests: the PB-03 fixture in both feature configurations, exhaustive single-bit tamper tests of E1 to E3, replay, previous slot, MAC-only, cost counters, hostile corpus, a property test (random round trips; random window steps against a model of the contract); rustdoc.

### Excluded
- The embedded `frame` set, README example, component description (AZ-3204).
- Stream-mode bytes and behaviour; other packages; hardware cycle counts.
- A frame-mode session on the std `PackSession` type (not in this loop).
- Scenario S10: a caller reusing a `msg_id` (the library cannot check it; documented).

## Acceptance Criteria

**AC-1: Vectors** (S1, S8)
Given `fixtures/frame/vectors.txt`
When the Rust suite runs with default features and with `--no-default-features --features frame`
Then every row matches (0 mismatches), E1 to E5 included, and the largest epoch 0xFFFFFF works while epoch 0x1000000, direction 0 and 4, `kind` 16 and `tag_len` 0, 5, 32 are `BadValue`

**AC-2: Tampering never yields plaintext** (S4)
Given E1, E2 and E3
When every single bit of `ad`, `clear`, ciphertext and tag is flipped in turn, and `msg_id`, `kind`, direction, epoch and key are each changed
Then each open is `TagMismatch`, the output buffer still holds its sentinel bytes, and the window is unchanged

**AC-3: Replay before crypto** (S2, S3)
Given a window and a counter that is a duplicate or 64 or more behind the highest
When `open_frame` runs
Then the result is `Duplicate` or `TooOld` with 0 SHA-256 compressions; a never-seen counter inside the window is `Fresh` and opens; a fresh valid body commits its counter; a fresh tampered body does not

**AC-4: Previous slot** (S5)
Given a session at (B, 7) with previous (A, 6)
When bodies sealed under (A, 6) and under (B, 7) are opened
Then the results are `Ok` with `Previous` and `Ok` with `Current`; with no previous slot the first is `TagMismatch`

**AC-5: MAC-only** (S9)
Given E4 and E5 and their messages split into one, two and three parts
When `tag` and `verify` run
Then the tags match and do not depend on the split, a flipped bit gives `false`, label of 0 or 33 bytes and `n` of 0, 2, 5 are `BadValue`, and `size_of::<MacKey>()` is at most 72 B

**AC-6: Cost per message**
Given a 236-byte plaintext, an 11-byte `ad`, no clear part, `tag_len` 4, and a 255-byte MAC-only message
When seal, open and `tag` run
Then seal and open each use at most 4 ChaCha20 blocks and 6 SHA-256 compressions and `tag` at most 6 compressions

**AC-7: Stream unchanged** (S12)
Given the existing session vectors, the std/core cross-open tests and the ring
When the suite runs
Then all pass with 0 changed stream bytes

**AC-8: Refusals and hostile input** (S6, S7)
Given the contract's refusals and the hostile corpus style of `nostd` (random bodies, lengths and `clear_len`)
When seal and open run
Then a stream call on a frame session and the reverse are `BadValue`; body 256 B and `ad` 256 B are `TooLong`; a body shorter than `clear_len + tag_len` is `ShortPacket`; an output one byte short is `BufferFull`; seal leaves 0 partial output bytes; 0 inputs panic

**AC-9: Sizes**
Given the frame types
When their sizes are measured
Then `size_of::<ReplayWindow>()` is 16 B and a frame `Session` with two slots and three directions is at most 640 B

## Non-Functional Requirements

**Compatibility**
- Builds for `thumbv7em-none-eabihf` and the host; no target-specific code (the ESP32 radio uses only `MacKey`).
- Source files at most 500 lines; `rust/src/nostd` bans `split_at_mut`, `rotate_left`, `copy_within`, `reverse`, `copy_from_slice` and `chunks*` (they link a panic path).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | fixture rows, both feature configurations | all match |
| AC-2 | exhaustive single-bit flips of E1 to E3 and field changes | `TagMismatch`, sentinel intact, window unchanged |
| AC-3 | duplicate, too-old, reordered counters; fresh valid and tampered bodies | refused with 0 compressions; commit only on `Ok` |
| AC-4 | two-slot and one-slot sessions | `Previous`, `Current`; `TagMismatch` |
| AC-5 | E4, E5, part splits, flipped tag, bounds, `size_of` | match; `false`; `BadValue`; at most 72 B |
| AC-6 | block and compression counters | within the counts |
| AC-7 | stream vectors, cross-open tests | green |
| AC-8 | refusal rows, random hostile inputs | error kinds, no partial output, no panic |
| AC-9 | `size_of` asserts | 16 B; at most 640 B |

Property test: random keys, epochs, contexts, `ad`, `clear` and `plain` within the limits round-trip; a random sequence of window steps matches a model of the contract.

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1, AC-7 | HEAD with the change | `docker compose -f docker-compose.test.yml run --rm rust` and the ring | green | — |

## Constraints

- Bytes and results exactly as the contract (AZ-3200); any difference is a contract change first.
- Fit decision 2: the frame pieces sit beside the shared pad, HMAC and HKDF code; the stream functions stay as they are.
- Packbin conventions: tests in Arrange-Act-Assert form, no verbose logs, no new dependency (the primitives are `session_core`'s).
- Tests with a wall-clock assertion use the Rust load factor (`timing_support.rs`).

## Risks & Mitigation

**Risk 1: The compiler shortens the constant-time compare**
- *Mitigation*: a fold over all bytes with `black_box` on the accumulator; reviewed in the frame-mode security audit (later task).

**Risk 2: Stream users pay for frame state**
- *Mitigation*: the frame variant exists only with the `frame` feature; AZ-3204 checks the existing sets' figures are unchanged.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| PB-04 was 8 points; split into this task (5) and AZ-3204 (3) | decompose, owner 2026-10-25 | resolved | Low |
| Public names in the spec are proposals | the contract (AZ-3200) fixes names; "names may change, capabilities may not" | accepted-risk | Low |
| The spec says `frame` is "always on with `std`, as `session` is"; in this crate `session` is not implied by `std` (the `nostd` session needs `--features session`), so `frame` follows `session`: an opt-in feature, tested with `--features frame` and `--no-default-features --features frame` | agent follows the crate's practice; owner may change it | accepted-risk | Low |
| With `session` and `frame` both on, `Session` also holds the stream fields; the 640 B size bound is asserted for the frame-only build | agent | accepted-risk | Low |
