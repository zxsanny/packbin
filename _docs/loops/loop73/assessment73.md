# Feature assessment — loop 73

loop: 73
feature: rust-hkdf-wipes
rounds: 2
verdict: COMPLETE
report_of_round: 2

## Round 1

**Date**: 2026-10-26
**Implement pass**: batch 01, report `_docs/03_implementation/batch_01_loop73_report.md` (commit a1c456a)
**Verdict**: CLARIFY — 13 covered / 2 out-of-scope / 0 gap-clear / 1 gap-unclear

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | a stream session opens: keys as at HEAD, HKDF temporaries cleared | covered | AC-2, AC-4, AC-7; `nostd_session_tests`, `session_tests`, `every_hkdf256_row_matches`; `session_core/mod.rs` `split_keys`, `hkdf.rs` | intake |
| S2 | a frame session loads, then rotates epochs: each key fill clears its temporaries | covered | AC-2, AC-4; `frame_vectors_tests` (157 rows), `frame_core_tests`; `nostd/frame/mod.rs` `DirKeys::fill` | intake |
| S3 | `derive` leaves early (more than 255 blocks, short slice): `prk` and `previous` cleared | covered | AC-2.2; single exit in `hkdf.rs` `derive` (code read, batch report); `rfc5869_case_1` | intake |
| S4 | `MacKey::derive` with a bad epoch or label: `BadValue`, nothing derived | covered | inherited loop 69 ACs; `frame_hostile_tests`; `nostd/frame/mac.rs` `derive` (unchanged guard) | intake |
| S5 | HMAC key longer than 64 bytes: block and hashed key cleared | covered | AC-2.1; `every_hmac256_row_matches` (long-key rows); `hkdf.rs` `hashed`, `sha256.rs` `hash` | intake |
| S6 | two std sessions on two threads: no shared state | covered | AC-7; `session_tests`; the helper keeps no state (`session_core/wipe.rs`) | intake |
| S7 | drop of a heap-free `Session`, frame session or `MacKey` clears seed, keys and pads | covered | AC-4.1; `test_previous_is_zero` and the drop tests in `nostd_session_tests`; `nostd/session.rs` `Drop`, `SlotKeys::wipe`, `MacKey` `Drop` | intake |
| S8 | firmware `session` and `frame` sets: no heap, no panic path, figures within AC-5 | covered | AC-5; `rust-embedded` rows `rust-m4f`, `rust-m33f`, `rust-mutants` PASS; `limits-m33f.txt` | intake |
| D1 | `xor_with_nonce` plain-loop pad wipe moved to the helper | covered | AC-3.2; `every_chacha_row_matches`, frame vectors; `pad.rs` | batch_01 discoveries |
| D2 | heap-free `Session::open` plain-loop seed wipe moved to the helper | covered | AC-4 (owner: every Rust wipe); `nostd_session_tests`; `nostd/session.rs` `open` | batch_01 discoveries |
| D3 | `Option::take` left the seed bytes in the session slot; now wiped in place | covered | problem.md "The wipe method is a hint"; `nostd_session_tests`, `session_tests` (open twice, open after load); `open` in both sessions | batch_01 discoveries |
| D4 | `sha256::hash` hasher held a long HMAC key | covered | AC-2.1; `nist_vectors_and_pieces_agree`; `sha256.rs` `hash` | batch_01 discoveries |
| D5 | `Sha256::finish` takes `&mut self` so the hasher is wiped where it lives | covered | AC-2.1; `every_sha256_row_matches`; `sha256.rs` | batch_01 discoveries |
| D6 | full 32-byte HMAC outputs (`MacKey::tag` / `verify`, frame seal and open) are not wiped, while Java wipes its copies since loop 72 | gap-unclear | question below | batch_01 discoveries |
| D7 | `.unwrap()` on the seed in the std `PackSession::open` replaced | covered | `session_tests`; `session/mod.rs` `open` | batch_01 discoveries |
| C1 | std `PackSession` keeps its send and receive keys until the memory is reused | out-of-scope | spec `### Excluded`: "A `Drop` wipe for the std `PackSession` keys" | spec flagged concerns |
| C2 | copies made by moves and by-value returns (L73-1) | out-of-scope | spec Risk 2 and problem flagged concern: "the contract keeps best effort"; described in the Rust description (AC-8) | spec flagged concerns |

### Gaps that need a decision (gap-unclear)

#### D6: full HMAC outputs

**What is not decided**
Every frame seal, open and `MacKey` call computes a 32-byte HMAC and keeps the first 4, 8 or 16 bytes as the tag. The whole 32 bytes stay on the stack after the call in Rust. Since loop 72, Java overwrites its copy of the 32 bytes once the tag is copied or compared. These bytes are not key material: they cannot be used to compute the tag of another message. In Rust the same 32 bytes also stay in the hasher inside `Pads::mac`, so clearing only the callers' copies would clear half of them.

**Options**
- **A — Leave them (as now)**: no change; the Rust description says why. Trade-off: Rust and Java differ on this one point.
- **B — Clear the callers' copies (Java parity)**: four call sites clear their 32 bytes. Trade-off: about the same as Java, but the copy inside the hasher stays, so the gain is mostly symbolic; a few bytes of flash.
- **C — Clear the copies and the hasher states**: every frame MAC also clears its two hashers. Trade-off: complete, but every seal, open and MAC pays roughly 200 extra stores, on the device too.

**Recommendation**: A — the bytes are not key material, and B clears only half of them.

### Gaps that are clear (gap-clear)

none

### Not walked

none

### Harness gaps

none

## Round 2

**Date**: 2026-10-26
**Implement pass**: none after round 1 (the clarify answer added no spec)
**Verdict**: COMPLETE — 13 covered / 3 out-of-scope / 0 gap-clear / 0 gap-unclear

### Coverage matrix

Rows S1 to S8, D1 to D5, D7, C1 and C2 as in round 1.

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| D6 | full 32-byte HMAC outputs are not wiped | out-of-scope | owner, 2026-10-26 (`new-task --clarify`, AskQuestion "Full HMAC"): "Leave them (Recommended)"; spec `### Excluded` line added | assess-round-1 |

### Gaps that need a decision (gap-unclear)

none

### Gaps that are clear (gap-clear)

none

### Not walked

none

### Harness gaps

none
