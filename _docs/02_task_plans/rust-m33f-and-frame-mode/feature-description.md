# Feature: packbin frame mode, Rust first (AZ-3192)

Complexity: 19 points (new-task Step 2: scope 4 areas, novelty medium-high (a new authenticated mode and a new MAC primitive use), risk high on stream bytes; routing: mandatory `/decompose --feature`, 13 or more).
Loop: 69 (branch `dev`). Umbrella ticket: AZ-3192. Epic: new packbin epic "Frame mode" (created by decompose).

## Description

meshbell, a LoRa field mesh whose field stack is Rust, needs packbin **frame mode**: a `mode` setting on the session (`stream` today, `frame` new) that seals and opens radio frames with an explicit per-message nonce, associated data, a 4/8/16-byte truncated HMAC-SHA256 tag (encrypt-then-MAC with ChaCha20), keys per (key, epoch, direction) from HKDF-SHA256, a previous-key slot used by open only, a caller-owned 64-message replay window, and a **MAC-only** call (HKDF-derived label key, precomputed HMAC pad states, message hashed in parts) for the per-hop 4-byte network MIC and key fingerprints. The bytes are fixed by the "Normative specification" of PB-01 (`input/PB-01_frame_mode_contract_and_adr.md`); the worked examples E1 to E5 in `input_data/expected_results/results_report.md` were computed by meshbell with an independent implementation and are the first known answers.

This loop (owner, 2026-10-25: "Frame mode only, Rust-first") ships four hand-off specs as tasks:

| Spec | Points | Scope this loop | Depends on |
| --- | --- | --- | --- |
| PB-01 contract and ADR | 4 | `pack-session.md` 2.0.0 (Configuration, Frame mode, MAC-only), ADR 008, `_docs/00_problem/` files (authentication in scope for frame mode only; R-08 exception), the "Authentication: none" line of `architecture.md`, README "Frame session" section with the uniqueness rule in bold | none |
| PB-02 primitive reference vectors | 3 | `fixtures/crypto/vectors.txt`, `fixtures/crypto/README.md`, `scripts/crypto/check_vectors.py`, `scripts/crypto/chacha20.py`, `check-vectors.test.sh`, and the **Rust** test; the other seven packages are a follow-up | none |
| PB-03 frame golden vectors | 4 | `scripts/frame/framefmt.py`, `gen_vectors.py`, `check_vectors.py`, `fixtures/frame/` (vectors, README, check scripts; `ring-cases.txt` optional) | PB-01, PB-02 |
| PB-04 Rust frame mode | 8 | Cargo feature `frame`, frame mode in `nostd::Session`, `MacKey`, `ReplayWindow`, PB-03 tests, property and hostile tests, embedded `frame` set on the Cortex-M4F (`mps2-an386`), docs | PB-01, PB-03; AZ-2749 (done) |

Full text of each spec: `input/PB-0N_*.md`. Loop-level acceptance criteria: `acceptance_criteria.md` (AC-F1.* to AC-F4.*); every PB spec AC maps to one of them.

## Code sections / UI locations

`rust/src/nostd/session.rs` and a new frame module under `rust/src/nostd/`; `rust/src/session_core/` (SHA-256, HKDF, ChaCha20 block; the stream functions stay untouched); `rust/Cargo.toml` features; `rust/embedded/{feature-sets.txt,limits.txt,probe,README.md}`; `_docs/02_document/contracts/library/pack-session.md`; `_docs/02_document/adr/`; `_docs/00_problem/`; `fixtures/{crypto,frame}`; `scripts/{crypto,frame}`; CI wiring in the existing per-package jobs and `scripts/loop-tests.sh`.

## Scenarios

The matrix of `scenarios.md` (S1 to S12; S10 out of scope): first frame sealed and opened (S1); duplicate counter (S2); reordered frames inside the window (S3); tampering (S4); key rotation with the previous slot (S5); stream and frame calls crossed (S6); length and buffer refusals (S7); epoch, direction, kind and tag_len boundaries (S8); MAC-only in parts and label bounds (S9); `msg_id` reuse by a caller, out of scope and documented (S10); the device build with `frame` on and off (S11); stream bytes unchanged (S12).

## Fit decisions

1. Authentication enters scope for frame mode only: owner route A (2026-10-19); PB-01 edits the project files; ADR 008 states it amends ADR 001's "the size is the sum of the fields" for frame mode.
2. The frame pieces sit beside the shared pad, HMAC and HKDF code; the stream functions are not touched (AC-F4.9).
3. One `frame` embedded set with a limit at the measured figure plus 5%, at most 20,480 B flash and 2,048 B stack; the four existing sets keep their figures; `std` includes `frame`.

## Constraints and sizing notes for decompose

- Task order: PB-01 and PB-02 first (no dependency; disjoint files: docs/contracts vs `fixtures/crypto`, `scripts/crypto`, one Rust test file), then PB-03, then PB-04. PB-04 is 8 points: split it if its files allow (for example the frame module and `MacKey`/`ReplayWindow`, then the embedded `frame` set and docs).
- Wire stability: once PB-03's file exists, a changed row is a wire change (meshbell pins the commit).
- Packbin rules apply: source files at most 500 lines, tests in Arrange-Act-Assert form, `rust/src/nostd` bans `split_at_mut`, `rotate_left`, `copy_within`, `reverse`, `copy_from_slice` and `chunks*` (AGENT_GOTCHAS), no `unsafe`, `unwrap`, `expect` or panicking index in the frame module; standard library only for the Python scripts; any wall-clock assertion uses the package's load factor.
- Do not implement in sibling repositories; meshbell's side is its own.
