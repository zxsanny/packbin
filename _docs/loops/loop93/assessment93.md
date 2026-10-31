# Feature assessment — loop 93

loop: 93
feature: m33f-128k-ram-view
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-10-31
**Implement pass**: batch 1, `_docs/03_implementation/batch_01_loop93_report.md` (no separate implementation or completeness report, as in loops 89 to 92)
**Verdict**: COMPLETE — 7 covered / 1 out-of-scope / 0 gap-clear / 0 gap-unclear

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | First run of both M33F rows after the change | covered | AC-1, AC-2; real compose runs PASS with HEAD figures (315 of 315, 25,760 B, 724 B, 8,416 B, 912 B; Rust pins); `RAM` in `mps2-an505.ld`, `check_ram_end` in `arm.sh`, `target.sh` | intake |
| S2 | An edit makes an image need over 128 KiB of static RAM | covered | AC-3; scratch run: ``region `RAM' overflowed by 3264 bytes``, row FAIL; the linker, via `mps2-an505.ld` | intake |
| S3 | The script's window is moved (4 MB back) | covered | AC-4; scratch run: 4 images of `cpp-m33f` and 5 of `rust-m33f` FAIL naming 38020000; `check_ram_end`, `m33f_ram_end` in `lib.sh` | intake |
| S4 | The stack grows | covered | AC-2; existing pins and the 8 KiB ceiling in `target_m33f` / `rust_row` (unchanged, still green) | intake |
| S5 | The Rust row links into the same script | covered | AC-1, AC-2, AC-4; real `rust-m33f` PASS and scratch FAIL; `rust_row` in `target.sh` | intake |
| S6 | Other rows (M3, M4F, s390x, AVR) | covered | AC-5; arm stage 6 of 6 rows PASS with the same figures; `loop-tests.sh --only cpp-embedded-arm,rust-embedded,scaffold` 3 passed | intake |
| D1 | A deliberate window change needs two edits | covered | batch report discovery 1; both comments name the other place; AC-4 fails if they differ | batch_01 discoveries |
| X1 | Real TrustZone non-secure image, RRAM, timing | out-of-scope | spec `### Excluded`: "A real non-secure (TrustZone) image, RRAM, the part's peripheral memory map, cycle timing" | intake |

### Gaps that need a decision (gap-unclear)

none

### Gaps that are clear (gap-clear)

none

### Not walked

- Heap use of newlib in `vectors.elf` near the window end: the run is green with 315 of 315 and the image has no heap wrapper call in `ac2`/`frame`; no row of its own.
