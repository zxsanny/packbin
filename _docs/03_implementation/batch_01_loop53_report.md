# Batch Report

**Batch**: 1 (loop 53)
**Tasks**: AZ-2756_rust_core_session
**Date**: 2026-10-20

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2756_rust_core_session | Done | 14 files (crypto moved to `rust/src/session_core/`, new `nostd/session.rs`, walk split into `pack_clear` + `read`, probe, run-suite) | 21 new session tests + 539 lib + all suites pass | None |

## Code Review Verdict: deferred

One total `/code-review` at the end of the loop (owner rule 2026-10-06), no per-batch review.

## Test Suite

- `cargo test` (default): all pass; `--features session,ecc,text`: all pass (539 lib tests, 21 in `nostd_session_tests`)
- `--no-default-features --features session --test nostd_session_tests`: 12 passed (std cross-open and `ecc` tests are gated off)
- Embedded stage (Cortex-M4F, QEMU): PASS, no heap symbol and no panic path with `session` on. Figures: session flash 18,076 B, stack 1,776 B (no limit yet; the owner owes one). Base unchanged at 14,532 B / 456 B.
- `run-suite.test.sh`, `checks.test.sh`: pass
- CI-parity: PASS (`cargo test` default and `session,ecc,text`, clippy with the `nostd` deny lints on `session,ecc,text`, `run-suite.test.sh`, `rust/embedded/run.sh host`)

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | The first embedded run linked `panic_const_div_by_zero` and `panic_fmt`: `chunks_mut` / `chunks_exact` do a division and an assert that opt-level z does not fold | AC-2 | the shared pad, hash and HKDF read bytes by index with `get` and rolling windows, no `chunks*`; gotcha line added | clear (AC-2 says no panic path) |
| 2 | The session stack on the probe is 1,776 B (key derivation at `start` / `join`: SHA-256 state, HMAC block, two sessions in the probe frame) against 456 B for the base probe | AC-2 | the schedule window was cut from 64 to 16 words and HMAC reuses one block (1,944 B to 1,776 B); a limit is the owner's | unclear (needs a limit from the owner; handoff) |
| 3 | `Session::unpack` on a protected scheme with `ecc` on detects only; a repair needs `unpack_repair` (as std `unpack` vs `unpack_repair`) | AC-1 | same as std | clear |
| 4 | An error kind for "session not open", "seed/nonce size": no new kind, `BadValue` with `needed` (C++ does the same) | AC-3 | `BadValue` | clear |

## Commit

`[AZ-2756] Rust nostd core: session on caller buffers`. Body: one line + `Loop: 53`.

## Next Batch: AZ-2757
