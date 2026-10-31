# Batch Report

**Batch**: 1 (loop 93)
**Tasks**: AZ-3469_m33f_128k_ram_window
**Date**: 2026-10-31

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-3469_m33f_128k_ram_window | Done | 5 source files (`mps2-an505.ld`, `lib.sh`, `arm.sh`, `rust/embedded/target.sh`, `rust/embedded/README.md`) | real `cpp-embedded` and `rust-embedded` runs PASS; 3 failure runs as expected; `lib.test.sh`, `run-parts.test.sh`, `checks.test.sh` pass | None |

## Proof

- AC-1/AC-2: real compose runs: `cpp-m33f` PASS (315 of 315 vectors, flash 25,760 B, stack 724 B, frame 8,416 B / 912 B), `rust-m33f` PASS (pins of `limits-m33f.txt`), all 6 arm rows PASS, 0 target failures.
- AC-3: scratch copy, 130 KiB `volatile` array used by `main` in the all-kinds image: ``region `RAM' overflowed by 3264 bytes``, `cpp-m33f` FAIL. First attempt (unreferenced array) was dropped by `--gc-sections` and passed: the injection, not the gate, was wrong.
- AC-4: scratch copy with `LENGTH = 4M`: `cpp-m33f` FAIL for 4 images and `rust-m33f` FAIL for 5, each "stack top 38400000 is not the RAM window end 38020000".
- AC-5: `scripts/loop-tests.sh --only cpp-embedded-arm,rust-embedded,scaffold`: 3 passed, 0 failed, 186 s; arm stage 21 s.
- AC-6: no stale "4 MB" wording existed; the script header, `lib.sh` comment and `rust/embedded/README.md` now state the window and its limit.
- CI-parity: PASS (the loop-tests stages above are the CI jobs `scaffold`, `embedded-arm`, `rust-embedded`). `shellcheck` not installed (`bash -n` only).

## Code Review Verdict: PASS

code-review (low): 0 findings.

## Test Suite

- Stages run: scaffold, cpp-embedded-arm, rust-embedded: 3 passed, 0 failed.
- Not run locally (no source they build changed): go, typescript, csharp, python, rust, java, cpp, swift, ring, ac10, publish gate.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | The guard pins the window end in two places (script `LENGTH`, `m33f_ram_end`); a deliberate change needs both | AZ-3469 flagged concern 2 | AC-4 ties them; documented in both comments | clear |

## Commit

`[AZ-3469] Run the M33F rows in a 128 KiB RAM window`. Body: one line + `Loop: 93`.

## Next Batch: All tasks complete
