# Batch Report

**Batch**: 2 (fix batch after feature assessment round 1)
**Tasks**: AZ-3334_py_ts_edges_key_order
**Date**: 2026-10-27

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-3334_py_ts_edges_key_order | Done | 2 edited (`fixtures/hostile/fuzz/python/edges.py`, `fixtures/hostile/fuzz/typescript/edges.ts`) | both probes exit 0, 0 FAIL, 86 / 87 PASS; the NFC/NFD INFO line went from `refused` to `accepted as two keys (no normalization; Swift F47 differs)`; the other lines equal | None |

Low review fixes of the independent reviewer (applied by the parent, same commit): `publish-timing.selftest.sh` last early-exit reader (`trap_offenders`) read from a captured variable (selftest exit 0, 240 lines); `rust/tests/nostd_dict_tests.rs` header says "`std` and `text`"; ADR-003 note "the reason that remains"; `scenarios.md` S12 reworded, S13 and S14 added; batch 1 report rows corrected (dead-code warnings are `cfg(test)` items; burner count); smoke76 gained step 10 and the burners live 600 s.

## Code Review Verdict

Independent read-only review of `a50e750..f102eba` (the assessment agent, Part B): no Critical, High or Medium finding; 5 Low and 4 Info, dispositions in `assessment76.md`. Not run again on this 4-line batch.

## Rust feature sets at test time (assessment row A2, owner: run each once)

Cargo 1.79.0, `cargo test --no-default-features [--features <set>] --no-fail-fast`, 40 test targets per run, 0 failed in all six:

| Set | Passed |
|-----|--------|
| (none) | 19 |
| alloc | 20 |
| text | 28 |
| ecc | 29 |
| text,ecc | 38 |
| text,ecc,frame | 45 (4 dead-code warnings in `cfg(test)` items) |

## Discovered during implementation

| Spec ref | Discovery | Proposed handling | Class |
|----------|-----------|-------------------|-------|
| AZ-3334 | the Python and TypeScript probes print no hint when a packet is refused for key order rather than for normalization | none; the info line now reports the accepted case | clear |
