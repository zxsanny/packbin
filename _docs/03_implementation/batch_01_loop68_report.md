# Batch 01, loop 68 report

| Task | Status | Files |
|------|--------|-------|
| AZ-3189_cpp_m33f_target_nrf54l15 | Done | `cpp/embedded/arm.sh`, `lib.sh`, `run.sh`, `arm/mps2-an505.ld`, `arm/stack_meter.hpp`, `run-parts.test.sh`, `lib.test.sh`, docs |

## Figures (read on HEAD `c3d8767` in a scratch build, then on the changed tree)

| Check | Figure |
|-------|--------|
| M33F all-kinds image flash (whole core, codec and ECC on) | 25,720 B of 65,536 B (pin 25,720 B) |
| M33F raw pack / unpack stack | 636 B / 788 B; net of the 64 B meter 724 B of 8,192 B (pin 724 B) |
| M33F core `.data` plus `.bss` | 0 B |
| M33F vectors | 290 run of 290 asserted (22 session) on `mps2-an505`; the packet equals the Cortex-M3 packet |
| M4F | 7,712 B flash, 540 B stack, pins unchanged |
| AVR Uno | 15,402 B, as before |
| Arm stage wall | 14 s with a warm cache |

## What the prototype found

- QEMU `mps2-an505` starts the Cortex-M33 in Secure state. Code linked at 0 (the non-secure alias) locks up on the first fetch (`Lockup: can't escalate 3 to HardFault`); code at 0x10000000 and RAM at 0x38000000 (secure aliases of SSRAM1 and SSRAM2/3) run. RAM at 0x28000000, 0x30000000 and 0x21000000 with code at 0x10000000 also failed or were not tried past the first fault; only 0x38000000 ran.
- The stack meter window was 8,192 B, equal to the new ceiling, so an overrun would have read as the window size; it is 16,384 B now (the M4F meter overhead is still 64 B).
- `lib.test.sh` stubs every target function and counts rows: it failed 6 checks until `target_m33f` was stubbed and the counts became 6.

## AC results

| AC | Result |
|----|--------|
| AC-1 builds the whole core | PASS, 0 warnings |
| AC-2 runs on mps2-an505 | PASS: FAILURES 0, packet equals M3, 290 of 290, 0 exception/heap/OS-random refs |
| AC-3 flash ceiling and pin | 25,720 B at most 65,536 B, pin 25,720 B |
| AC-4 stack ceiling and pin | 724 B at most 8,192 B, pin 724 B, meter window 16,384 B |
| AC-5 no static RAM | 0 B |
| AC-6 pins and ceilings bite | PASS (smoke step 4: a pin 1 B low and a ceiling below the figure fail the row naming the figure) |
| AC-7 other targets unchanged | PASS |
| AC-8 harness and CI | `run-parts.test.sh`, `lib.test.sh`, `publish-jobs.test.sh` pass; the `embedded-arm` job runs the row through the table (no workflow edit) |
| AC-9 notes | `AGENT_GOTCHAS.md`, C++ description, `tests.md` |
| AC-10 source untouched | 0 changes in `cpp/src` and `cpp/include` since `4151a90` |

CI-parity: PASS (`docker compose -f docker-compose.test.yml run --rm cpp-embedded`, `bash cpp/embedded/run-parts.test.sh`, `bash cpp/embedded/lib.test.sh`, `bash .github/workflows/publish-jobs.test.sh`, `bash -n` on every changed script); the full `scripts/loop-tests.sh` is the single step 11 run of this loop.
