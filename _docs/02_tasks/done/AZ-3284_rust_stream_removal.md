---
loop: 74
branch: dev
---

# Rust without the stream session

**Task**: AZ-3284_rust_stream_removal
**Name**: Remove the std `PackSession`, the stream half of the heap-free session, the `session` feature and its embedded set
**Description**: The Rust crate offers frame mode as its only session, with the same frame bytes and embedded figures.
**Complexity**: 5 points
**Dependencies**: AZ-3280_ring_ci_stream_removal
**Component**: 04_rust_package
**Tracker**: AZ-3284
**Epic**: AZ-3199

## Problem

The crate has the std `PackSession` and a heap-free `Session` that hosts the stream mode (feature `session`) beside frame mode (feature `frame`). ADR-009 removes the stream mode. Frame code uses the shared crypto (`hkdf`, `hmac`, `pad::xor_with_nonce`, `wipe`) and the shared session struct, and none of the stream-only symbols (`split_keys`, `SEED_SIZE`, `NONCE_SIZE`, `pad::xor`, the stream calls); its one link to the stream is the guard that refuses frame keys on a session holding stream state.

## Outcome

- 0 stream-session types, calls, constants or features; the frame bytes, the crypto rows and the `frame`, `base`, `text`, `ecc` embedded figures are kept.

## Scope

### Included
- Delete `src/session/`, `src/session_hostile_tests.rs`, `tests/session_tests.rs`, `tests/nostd_session_tests.rs`, `embedded/probe/src/session_extra.rs`.
- `Cargo.toml` (the `session` feature), `src/lib.rs`, `src/nostd/mod.rs`, `src/nostd/session.rs` (only the frame state stays), `src/nostd/io.rs`, `src/nostd/frame/mod.rs` (the stream-state guard and its docs), `src/session_core/` (`split_keys`, the seed and nonce sizes, the packet-counter pad), `src/walk/mod.rs` and `src/scheme/mod.rs` (`pack_clear`, which loses its only user), `src/crypto_vectors_tests.rs` (the stream branch; the 27 rows keep running in the default `cargo test`), `src/frame_hostile_tests.rs` (the two stream tests; the size assert becomes unconditional).
- Mixed tests keep their non-session halves: `tests/ecc_session_dispatch_tests.rs` (renamed), `tests/times_shapes_tests.rs`.
- `rust/embedded/`: `feature-sets.txt`, `limits.txt`, `limits-m33f.txt`, `probe/Cargo.toml`, `probe/src/lib.rs`, `checks.sh`, `target.sh`, `checks.test.sh` (its mutant uses `frame` in place of `session`), `main.cpp` and `README.md` wording.
- `fixtures/hostile/fuzz/rust/` probes: delete `session.rs`, the session parts of the others.

### Excluded
- The frame renames (AZ-3289); `rust/tests/nostd_docs_tests.rs` and the docs (AZ-3291); `run-suite.sh` (AZ-3280, unless the crypto test gating needs a new line, which then lands here after AZ-3280).

## Acceptance Criteria

**AC-1: No stream session**
Given the crate
When `git grep -nE 'PackSession|feature = "session"|split_keys|SEED_SIZE|NONCE_SIZE' rust fixtures/hostile/fuzz/rust` runs
Then it finds 0 hits, and `cargo build --features session` is refused as an unknown feature

**AC-2: Frame builds alone**
Given `--no-default-features --features frame` and `--features frame,text,ecc`
When each builds and its tests run
Then 0 errors and 0 failures, and 157 of 157 frame rows pass

**AC-3: Crypto rows in the default test run**
Given `cargo test` with default features
When it runs
Then 27 of 27 rows of `fixtures/crypto/vectors.txt` pass

**AC-4: Embedded figures**
Given `rust/embedded/run.sh host`
When it runs on this task's tree
Then it exits 0 with no `session` set; `frame` is at most 20,480 B of flash on M4F (20,332 B on HEAD) and equals its M33F pin (20,404 B / 1,728 B on HEAD, re-pinned and reported if it moves); `base`, `text`, `ecc` move by 0 B on both targets; `checks.test.sh` passes and catches its missing-line mutant

**AC-5: Suite green**
Given the Rust CI step list (`run-suite.sh` rust section)
When it runs
Then 0 tests fail

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | the grep; `cargo build --features session` | 0 hits; refused |
| AC-2 | the two feature builds with tests | 0 errors, 0 failures, 157/157 |
| AC-3 | crypto vector tests | 27/27 |
| AC-4 | `rust/embedded/run.sh host`, `checks.test.sh` | exit 0, figures as stated |
| AC-5 | the Rust suite | 0 failures |

## Constraints

- In `nostd`, `ecc_core.rs` and `session_core/` never call `split_at_mut`, `copy_from_slice`, `chunks*` and the rest of the `AGENT_GOTCHAS.md` list (a panic path breaks the M4F link check).
- A removed enum variant or public item breaks exhaustive matches in test targets: run the full `run-suite.sh` Rust list, not a hand-picked set (`AGENT_GOTCHAS.md`, loop 69).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The `frame` embedded figure could move once the stream fields and guard are gone | AC-4: report and re-pin M33F; M4F bound 20,480 B | open | Low |
