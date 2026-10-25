# Implementation completeness — loop 69

Tasks: AZ-3200, AZ-3201, AZ-3202, AZ-3203, AZ-3204 (epic AZ-3199, umbrella AZ-3192). Date: 2026-10-25.

| Task | Verdict | Outcome check | Scaffold grep |
|------|---------|---------------|---------------|
| AZ-3200 | PASS | contract 2.0.0 (Configuration, Frame mode, MAC-only, replay window, error kinds), ADR-008, problem, restrictions, AC and architecture lines, README section: all present; E1 to E5 recomputed independently | none |
| AZ-3201 | PASS | `fixtures/crypto/vectors.txt` (27 rows), Python check with a pure-Python ChaCha20, corrupted-copy test, Rust test; the other seven packages are the owner's follow-up | none |
| AZ-3202 | PASS | 170 rows, reference, generator, coverage list, second implementation, corrupted-copy and determinism test | none |
| AZ-3203 | PASS | `frame` feature, `load_frame`, `set_previous`, `seal_frame`, `open_frame`, `MacKey`, `ReplayWindow`; real HKDF, HMAC and ChaCha20 of `session_core`; no stub, passthrough or fake | `grep -ri "stub\|placeholder\|todo\|fake\|passthrough" rust/src/nostd/frame rust/src/session_core/hmac.rs` empty |
| AZ-3204 | PASS | `frame` set on the device image, limits, `stream_hits`, docs; run in the embedded stage | none |

## System Pipeline Audit

| Pipeline | Status | Evidence |
|----------|--------|----------|
| seal (caller) to open (caller) with a window, in Rust | WIRED | the fixture test and the device probe call the production `seal_frame` and `open_frame` end to end |
| MAC-only tag and verify | WIRED | `MacKey::derive`, `tag`, `verify` called by the fixture test and the probe |
| frame vectors file to every implementation | PARTIAL (by scope) | Rust reads it; the other seven packages are later tasks (owner, 2026-10-25) |

Gate: all tasks PASS; the one PARTIAL pipeline is the owner's scope cut, recorded in `problem.md` and as a leftover.
