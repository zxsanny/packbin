# Feature assessment — loop 68

loop: 68
feature: nrf54l15-m33-target
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-10-25
**Implement pass**: one batch, commit `cc75443`
**Verdict**: COMPLETE — 8 covered / 0 out-of-scope / 0 gap-clear / 0 gap-unclear (two rows deferred by the owner's scope, below)

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| AC-1 / S1 | the target builds the whole core, 0 warnings | covered | `target_m33f` in `arm.sh`; arm stage `cpp-m33f: PASS`; `smoke68.sh` step 1 | intake |
| AC-2 / S4 | runs on `mps2-an505`; packet equals M3; 290 of 290 vectors | covered | `cpp-m33f` log (FAILURES 0, `vectors run 290 asserted 290`, `session_tests.cpp asserted=22 run=22`); `cmp` of `m3-all-kinds.hex` and `m33f-all-kinds.hex`; `smoke68.sh` step 3 | intake |
| AC-3 / S2 / S3 | flash ceiling 65,536 B and pin 25,720 B | covered | `m33f_flash_*` in `lib.sh`; `smoke68.sh` steps 2 and 4 (pin 1 B low and ceiling below the figure fail the row) | intake |
| AC-4 / S2 / S3 | stack ceiling 8,192 B and pin 724 B, meter window above the ceiling | covered | `m33f_stack_*`, `stack_meter.hpp` window 16,384 B; `smoke68.sh` steps 2 and 4 | intake |
| AC-5 | 0 B static RAM | covered | `core data+bss 0 B` in the row message | intake |
| AC-7 / S5 | other targets unchanged | covered | arm stage: M0+, M3, M4F (7,712 B / 540 B), s390x, AVR (15,402 B) pass; `smoke68.sh` step 1 | intake |
| AC-8 / S6 | harness and CI | covered | `run-parts.test.sh`, `lib.test.sh`, `publish-jobs.test.sh` pass; `embedded-arm` runs `run.sh host arm`, which reads the table | intake |
| AC-9, AC-10 / S7 | notes; core source untouched | covered | `AGENT_GOTCHAS.md`, C++ description, `tests.md`; `git diff 4151a90 -- cpp/src cpp/include` empty (`smoke68.sh` step 6); S7 (machine missing) shows as the QEMU error in the row | intake |
| S8 | the owner drops M4F later | out-of-scope | `scenarios.md` S8 deferred by the owner's scope ("M4F stays"); the row and pins do not depend on M4F | intake |

### Residual risk (not a gap in a written criterion)

QEMU `mps2-an505` runs the Cortex-M33 in Secure state with 4 MB code and data regions; the part has 128 KiB of RAM in a non-secure image and 1.5 MB of RRAM. The ceilings (64 KB, 8 KB) are far under both, but a green row proves the architecture and the byte figures, not the part's memory map, TrustZone partitioning or timing.

### Discovered during implementation

| scenario | spec ref | handling | clear |
|----------|----------|----------|-------|
| Code linked at the non-secure alias 0 locks up on `mps2-an505` | none | linker script uses 0x10000000 and 0x38000000; recorded in `AGENT_GOTCHAS.md` | clear |
| The stack meter window (8,192 B) equalled the new ceiling | AC-4 | window is 16,384 B | clear |
| `lib.test.sh` stubs every target and counts rows | AC-8 | `target_m33f` stubbed, counts 6 | clear |

### Gaps that need a decision (gap-unclear)

none

### Gaps that are clear (gap-clear)

none

### Not walked

- Real nRF54L15 hardware, non-secure images, the RISC-V coprocessor, cycle timing.
- Whether the `embedded-arm` CI job passes on GitHub with the new row: read after the push.
