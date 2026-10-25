# Batch Report

**Batch**: 1
**Tasks**: AZ-3231_rust_m33f_embedded_row
**Date**: 2026-10-25

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-3231_rust_m33f_embedded_row | Done (docs of AC-9 in step 13) | 7 (`run.sh`, `target.sh`, `checks.test.sh`, `limits-m33f.txt`, `rust/.gitignore`, `test.yml`, `loop-tests.sh` comment) | stage run `rust-m4f`, `rust-m33f`, `rust-mutants` 0 failed; `checks.test.sh`, `run-parts.test.sh`, `lib.test.sh`, `publish-jobs`, `publish-workflow`, `publish-pins` pass | None |

## Figures (HEAD `999b5a3` plus the change, Rust 1.98.1, `packbin-embedded` image, QEMU `mps2-an505`)

| Set | M33F flash | M33F net stack | M4F flash (same run) | M4F net stack |
|-----|-----------|----------------|----------------------|---------------|
| base | 15,132 B | 456 B | 15,060 B | 456 B |
| text | 27,268 B | 2,736 B | 27,156 B | 2,736 B |
| ecc | 18,764 B | 744 B | 18,692 B | 744 B |
| session | 18,884 B | 1,528 B | 18,812 B | 1,528 B |
| frame | 20,236 B | 1,752 B | 20,164 B | 1,752 B |

Log lines: `SIZE frame ram=0 B flash=20236 B (limit 20236) stack=1752 B (limit 1752) raw=1816 meter=64` (pins equal the figures). `ROUTE_HEX` equal to the M4F run for all five sets; `FAILURES 0`, `GOLDEN_OK 1`, `ram=0` everywhere. The M4F frame figure 20,164 B equals the CI figure of loop 69. With Rust 1.79 (the Mac default) the M33F figures are lower (frame 19,844 B).

AC-6 smoke: `limits-m33f.txt` with `frame 20235`: `NOTE FAIL frame: flash 20236 B over 20235 B`, stage `1 target(s) failed`. The real file: `0 target(s) failed`.

## Code Review Verdict: not run per batch

Owner preference (one total review and test per loop): feature-assess at step 10.5 and the step 11 run cover it; the change is shell only, no `rust/src`.

## Test Suite

- CI-parity: PASS. The Rust stage of the `embedded-arm` job run locally with the CI toolchain (`RUSTUP_TOOLCHAIN=1.98 rust/embedded/run.sh libs`, then `docker compose -f docker-compose.test.yml run --rm rust-embedded`), `checks.test.sh`, `run-parts.test.sh`, `lib.test.sh`, `publish-jobs.test.sh`, `publish-workflow.test.sh`, `publish-pins.test.sh`; shellcheck shows only the findings the existing sourced-global pattern gives.
- The full suite is the single step 11 run.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | The ceilings (65,536 B / 8,192 B) come from `m33f_*` in `cpp/embedded/lib.sh`; a ceiling bite cannot be smoked without editing lib.sh | AC-6 | the ceiling check is the same `within` helper that the pin check uses (tested in `checks.test.sh`); the pin smoke covers the bite | clear |
| 2 | The M33F row compares its route packet with the M4F run in the same stage, so a single-row run needs the M4F logs | AC-4 | the row fails naming the missing log, like `cpp-m33f` does for the M3 packet | clear |
| 3 | The probe crate and `rust/src` needed no change | AC-10 | none | clear |

## Commit

`[AZ-3231] Rust Cortex-M33F row with pins per set in the embedded stage`. Body: one line + `Loop: 70`.

## Next Batch: All tasks complete
