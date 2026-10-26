---
loop: 73
branch: dev
---

# Rust key wipes: one volatile helper, HKDF and stream pad temporaries cleared

**Task**: AZ-3275_rust_key_wipes
**Name**: Rust key wipes
**Description**: Every Rust wipe of key material goes through one helper whose writes the compiler keeps, and the HKDF and stream pad temporaries that are left on the stack today are cleared.
**Complexity**: 3 points
**Dependencies**: None (document dependency: `_docs/02_document/contracts/library/pack-session.md` 2.0.0)
**Component**: Rust package (`rust/`)
**Tracker**: AZ-3275
**Epic**: AZ-3199

## Problem

Loop 72 made C#, Java and Swift overwrite every temporary that held key-derived bytes. The Rust package, which those three follow, still has two gaps (`_docs/02_task_plans/rust-hkdf-wipes/problem.md`):

- the key derivation (`session_core/hkdf.rs`) and the ChaCha20 stream pad (`session_core/pad.rs`) leave key-derived temporaries on the stack: the key-and-pad block, the inner digest, `prk`, `previous`, the SHA-256 hashers holding the key's midstate, the ChaCha20 state and work words and the keystream block;
- the wipes that exist write zeros and then call `core::hint::black_box`, which the Rust documentation calls best effort, or use plain loops the compiler may drop as dead stores.

meshbell's Rust side and the nRF54L15 firmware run this code through the std `PackSession` and the heap-free `session` and `frame` features.

## Outcome

- One wipe helper (owner, 2026-10-26): each element overwritten through `core::ptr::write_volatile`, then `core::sync::atomic::compiler_fence`; one documented `unsafe` block; `frame` keeps `#![forbid(unsafe_code)]`.
- The HKDF and pad temporaries are cleared before every return, and the 9 existing wipes call the helper.
- Wire bytes, the vectors and the embedded golden packet are unchanged; the embedded `session` and `frame` figures stay within the bounds below and the M33F pins are re-set.

## Scope

### Included
- `rust/src/session_core/`: a new `wipe.rs` (the helper and its unit test), `hkdf.rs`, `sha256.rs` (a hasher wipe), `pad.rs`, `hmac.rs`, `mod.rs`.
- `rust/src/session/mod.rs` (`PackSession::open`), `rust/src/nostd/session.rs`, `rust/src/nostd/frame/mod.rs`, `rust/src/nostd/frame/mac.rs`.
- `rust/embedded/limits-m33f.txt` (re-pin `session` and `frame`), `_docs/AGENT_GOTCHAS.md` (what the bytes bought), `_docs/02_document/components/04_rust_package/description.md`, `_docs/02_document/module-layout.md` (the new `wipe.rs`).

### Excluded
- A `Drop` wipe for the std `PackSession` keys (the managed stream sessions have none either); the `zeroize` crate; wiping the SHA-256 round schedule `w` and the `compress` working words (owner decision); the constant-time compare in `nostd/frame/mod.rs`; C#, Java, Swift, Python, TypeScript, Go, C++; `fixtures/`; the contract text ("best effort" stays).

## Acceptance Criteria

Feature criteria in full: `_docs/02_task_plans/rust-hkdf-wipes/acceptance_criteria.md` (AC-1 to AC-8). Inherited: the Rust frame-mode criteria of loop 69 and the stream session criteria.

**AC-1: One helper whose writes stay**
Given `rust/src`
When `grep -rn -e black_box -e unsafe rust/src` runs and the helper's unit test runs
Then `session_core` has exactly 1 wipe function with exactly 1 `unsafe` block (with a `SAFETY:` comment), there is no other `unsafe`, `black_box` is left only in `timing_support.rs` and the constant-time compare, `frame` keeps `#![forbid(unsafe_code)]`, and the test finds 64 zero bytes and 16 zero words after wiping 0xA5 / 0xA5A5A5A5.

**AC-2: HKDF temporaries cleared**
Given `hmac_sha256` and `derive` in `session_core/hkdf.rs`
When either returns (in `derive`: the normal end and both early returns)
Then `block` (64 B), `digest` (32 B), the `state` and `block` of both hashers, `prk` (32 B) and `previous` (32 B) have been overwritten through the helper, and RFC 5869 case 1 and the HKDF and HMAC rows of `fixtures/crypto/vectors.txt` give the same bytes as at HEAD.

**AC-3: Stream pad temporaries cleared**
Given `session_core/pad.rs`
When `block`, `xor` or `xor_with_nonce` returns
Then `state` and `work` (16 words each) and the 64-byte keystream `pad` have been overwritten through the helper, and the RFC 8439 block vector and the ChaCha20 rows of `fixtures/crypto/vectors.txt` are unchanged.

**AC-4: Existing wipes moved**
Given the 9 wipes `Pads::new` `ipad` and `opad`, `Pads::wipe`, `split_keys` `both`, `PackSession::open` `seed`, `nostd::session` `wipe`, frame `fill` `mac`, the key slot `wipe`, `SlotKeys::wipe` and `MacKey::derive` `derived`
When the code is read
Then each calls the helper and nothing else clears them, and the batch report holds a code-read list of every Rust temporary that held key bytes, key-derived words, a pad block or keystream, each with its wipe line or the reason it has none (by-value moves, L73-1; the `compress` schedule, owner decision).

**AC-5: Embedded figures**
Given `docker compose -f docker-compose.test.yml run --rm rust-embedded` (libraries from `rust/embedded/run.sh libs`, Rust 1.98)
When both rows run
Then both pass; `base`, `text` and `ecc` keep their HEAD figures (M4F flash 15,060 / 27,156 / 18,692 B, M33F 15,132 / 27,268 / 18,764 B, stack 456 / 2,736 / 744 B); `session` and `frame` grow by at most 384 B of flash and 32 B of stack each on each row; the M4F `frame` flash stays at or under 20,480 B (a figure above it stops the loop for the owner); the M33F `session` and `frame` pins equal the new figures with a line in `_docs/AGENT_GOTCHAS.md`.

**AC-6: Speed**
Given a release build of this tree and of a HEAD copy (`git archive` into the scratchpad), each with the same bench calling `pad::xor` over 1 MiB
When each runs 3 times on this Mac in the same session
Then the smallest time of this tree is at most 1.15 times the smallest of HEAD, and every existing Rust load-aware timing check passes with no new fixed bound. The figures go in the batch report.

**AC-7: Bytes unchanged**
Given the 27 rows of `fixtures/crypto/vectors.txt`, the 157 rows of `fixtures/frame/vectors.txt` and the stream session vectors
When `docker compose -f docker-compose.test.yml run --rm rust` (the full CI step list) and `scripts/loop-tests.sh` stages `rust` and `ring` run
Then every test passes, and the embedded golden packet decodes on both rows (`GOLDEN_OK 1`).

**AC-8: Docs**
Given the Rust package description
When it is read
Then it names the wipe helper, what it guarantees (the writes are not removed by the compiler) and what it does not (copies left by moves and by-value returns, L73-1; the SHA-256 round schedule); `module-layout.md` lists `session_core/wipe.rs`; `pack-session.md` keeps "best effort".

## Non-Functional Requirements

**Performance**
- The pad pays three clears per 64-byte block; AC-6 bounds the cost at 1.15 times HEAD. Key derivation runs at session open and key load only.

**Compatibility**
- No public API change: the helper and the hasher wipe are crate-private. The crate keeps zero dependencies. Rust 1.79 (host default) and 1.98 (CI, embedded) both build it.

**Reliability**
- The heap-free sets keep no heap call and no panic path (`rust-mutants` and the link checks of the embedded stage).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | new test in `session_core/wipe.rs`: 64 bytes of 0xA5 and 16 words of 0xA5A5A5A5 through the helper | all zero |
| AC-2 | `rfc5869_case_1`, `crypto_vectors_tests.rs` HKDF and HMAC rows | unchanged bytes |
| AC-3 | `rfc8439_block_vector`, `crypto_vectors_tests.rs` ChaCha20 rows | unchanged bytes |
| AC-7 | `frame_vectors_tests.rs` (157 rows), `nostd_session_tests.rs`, the std session tests | pass |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-5 | `rust/embedded/run.sh libs` with Rust 1.98, then `docker compose -f docker-compose.test.yml run --rm rust-embedded` | M4F and M33F rows, five sets each | PASS; figures within AC-5 | Reliability |
| AC-6 | HEAD copy and this tree, release, same bench | `pad::xor` over 1 MiB, 3 runs each | ratio at most 1.15 | Performance |
| AC-7 | `docker compose -f docker-compose.test.yml run --rm rust`; `scripts/loop-tests.sh --only rust,ring` | full Rust step list; cross-language stream ring | PASS | Compatibility |

## Constraints

- Owner decision (2026-10-26): one volatile helper for every Rust wipe; no `zeroize`; the SHA-256 round schedule is not wiped.
- `rust/src/nostd` and `session_core` never call `split_at_mut`, `rotate_left`, `copy_within`, `reverse`, `copy_from_slice` or any `chunks*` (`_docs/AGENT_GOTCHAS.md`).
- `rustfmt` on single files only; restore `rust/src/walk/text_tables.rs` after it.
- Embedded figures are read from a run on this tree in this loop, never estimated.

## Risks & Mitigation

**Risk 1: the M4F `frame` set crosses its owner bound**
- *Risk*: 316 B of flash are left under 20,480 B at HEAD; inlined volatile loops at every site could take more.
- *Mitigation*: measure the helper inlined and out of line (`#[inline(never)]`) and keep the smaller; above the bound the loop stops for the owner.

**Risk 2: by-value copies stay out of reach**
- *Risk*: `hmac_sha256` results, the `split_keys` tuple and `Pads` returned by value may leave copies the helper never sees.
- *Mitigation*: L73-1 in the Rust description; the contract keeps "best effort".

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| `black_box` is a hint; wipes need a write the compiler keeps | owner, 2026-10-26: one volatile helper | resolved | Medium |
| One `unsafe` block in a crate whose `frame` module forbids `unsafe` | owner, 2026-10-26: the helper lives in `session_core` | resolved | Low |
| The SHA-256 round schedule and `compress` working words are not wiped | owner, 2026-10-26: left, documented | resolved | Low |
| Moves and by-value returns can leave copies no code can reach (L73-1) | the contract keeps "best effort" | open | Low |
| Three clears per ChaCha20 block slow the pad; no Rust timing check covers it | AC-6 | open | Low |
| M4F frame set has 316 B of flash under its owner bound | AC-5 stop condition | open | Low |
| The std `PackSession` keeps its keys until the memory is reused (no `Drop`) | out of scope, candidate | open | Low |
