# Batch Report

**Batch**: 2
**Tasks**: AZ-3275_rust_key_wipes (security review follow-up)
**Date**: 2026-10-26

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-3275_rust_key_wipes | Done | 3 source files, 1 limits file | 972 / 972 pass (1 ignored) | None |

Parent alone. Source: `rust/src/session_core/sha256.rs` (`compress` wipes its schedule window; doc line on `finish`), `rust/src/session_core/wipe.rs` (module doc), `rust/src/nostd/frame/mod.rs` (`keys.wipe()` for an unloaded direction). Limits: `rust/embedded/limits-m33f.txt`. Docs: problem pack, ACs (AC-2.4, AC-6.3), spec, Rust description, `AGENT_GOTCHAS.md`, `_docs/05_security/rust_key_wipes_review_loop73.md`.

## Why this batch

The independent security review of batch 1 (`_docs/05_security/rust_key_wipes_review_loop73.md`, PASS_WITH_WARNINGS) found that the SHA-256 schedule window left on the stack gives back the whole block hashed when the recurrence is run backwards; at key load that block is the MAC key XOR the outer pad. The parent re-ran the reviewer's script (`recovered key: True`) and took it back to the owner: the first answer ("leave the schedule") rested on the parent's wrong description of the window. Owner, 2026-10-26: wipe it at the end of every compression.

## Code Review Verdict: PASS_WITH_WARNINGS (security review of batch 1)

All four findings handled here; no per-batch code review otherwise (owner preference).

## Embedded figures (Rust 1.98.1, QEMU), final tree

| Row | Set | HEAD (72beacb) flash / stack | Batch 1 | Final | Change against HEAD | Limit |
|-----|-----|------------------------------|---------|-------|---------------------|-------|
| rust-m4f | base | 15,060 / 456 | 15,060 / 456 | 15,060 / 456 | 0 / 0 | 16,384 / 512 |
| rust-m4f | text | 27,156 / 2,736 | 27,156 / 2,736 | 27,156 / 2,736 | 0 / 0 | 27,964 / 2,898 |
| rust-m4f | ecc | 18,692 / 744 | 18,692 / 744 | 18,692 / 744 | 0 / 0 | 18,879 / 798 |
| rust-m4f | session | 18,812 / 1,528 | 18,828 / 1,504 | 18,844 / 1,504 | +32 / -24 | 19,325 / 1,924 |
| rust-m4f | frame | 20,164 / 1,752 | 20,316 / 1,728 | 20,332 / 1,728 | +168 / -24 | 20,480 / 1,991 |
| rust-m33f | base, text, ecc | 15,132 / 456; 27,268 / 2,736; 18,764 / 744 | same | same | 0 / 0 | pins |
| rust-m33f | session | 18,884 / 1,528 | 18,900 / 1,504 | 18,916 / 1,504 | +32 / -24 | re-pinned 18,916 / 1,504 |
| rust-m33f | frame | 20,236 / 1,752 | 20,388 / 1,728 | 20,404 / 1,728 | +168 / -24 | re-pinned 20,404 / 1,728 |

AC-5.2 holds (at most +384 B of flash and +32 B of stack); the M4F `frame` set keeps 148 B under its owner bound of 20,480 B. Log of the final run: `SIZE frame ram=0 B flash=20404 B (limit 20404) stack=1728 B (limit 1728) raw=1792 meter=64` (M33F), `SIZE frame ram=0 B flash=20332 B (limit 20480) stack=1728 B (limit 1991) raw=1792 meter=64` (M4F); `rust-m4f`, `rust-m33f`, `rust-mutants` PASS, `0 target(s) failed`.

## Speed (AC-6)

`MacKey::tag` (8-byte tag of a 36-byte message, 200,000 calls), release, this Mac at load 4 to 9, the claim commit 72beacb (`git archive`) and this tree side by side, interleaved: claim 696.3 / 583.6 / 583.1 ns, this tree 618.1 / 580.4 / 578.4 ns; smallest 583.1 against 578.4, ratio 0.99 (AC-6.3 bound 1.10). The schedule wipe costs nothing measurable on the per-message path. The stream pad (`pad.rs`) did not change in this batch; its ratio stays 1.044 (batch 1).

## Code-read list changes (AC-4.2)

| Place | Temporary | Wipe or reason |
|-------|-----------|----------------|
| `session_core/sha256.rs` `compress` | 16-word schedule window `w` (gives back the block hashed) | `wipe(&mut w)` at the end of every compression (replaces the batch 1 row "not wiped") |
| `sha256.rs` `compress` | working words `a` to `h`, `word` | registers or compiler spills: L73-1 |
| `nostd/session.rs` `Session::load` | `owned` seed copy | moved into the session: L73-1 |
| `nostd/frame/mod.rs` `Session::load_frame` | the session with its keys, returned by value | L73-1; `load_frame_in_place` (used by the device probe) derives the keys where the session lives |
| `nostd/frame/mac.rs` `MacKey::derive` | 64 B of pad states returned by value | L73-1 (no in-place variant) |
| `nostd/frame/mod.rs` `SlotKeys::fill` | an unloaded direction's keys | `keys.wipe()` (was `*keys = DirKeys::empty()`, plain stores) |

## Test Suite

- `docker compose -f docker-compose.test.yml run --rm rust`: 13 steps, 60 test binaries, 972 passed, 0 failed, 1 ignored, 94 s, exit 0
- Host (Rust 1.79): the helper, HKDF, SHA-256, ChaCha20 and primitive-row tests, the frame vectors with and without `std`, the heap-free and std session tests: all pass

CI-parity: PASS — `docker compose -f docker-compose.test.yml run --rm rust` and `rust/embedded/run.sh host` on the final tree.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 8 | the SHA-256 schedule window gives back the block hashed, so leaving it left a key copy at key load | AZ-3275 AC-2 (owner decision on the schedule) | taken back to the owner; wiped at the end of every compression (AC-2.4) | clear (owner answer, 2026-10-26) |
| 9 | `SlotKeys::fill` cleared an unloaded direction with plain stores | AZ-3275 AC-4.1 | `keys.wipe()` | clear (AC-4.1 "nothing else clears them") |

## Commit

`[AZ-3275] Wipe the SHA-256 schedule window after each compression`. Body: one line + `Loop: 73`.

## Next Batch: All tasks complete
