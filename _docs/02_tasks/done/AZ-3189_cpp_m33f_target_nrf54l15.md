---
loop: 68
branch: dev
---

# C++ embedded: Cortex-M33F target for the nRF54L15

**Task**: AZ-3189_cpp_m33f_target_nrf54l15
**Name**: Cortex-M33F target and chip-scale budgets in the arm embedded stage
**Description**: Add a `cpp-m33f` row that builds and runs the whole C++ core on a Cortex-M33F (QEMU `mps2-an505`) with flash and stack ceilings of 64 KB and 8 KB and pins at the measured figures.
**Complexity**: 3 points
**Dependencies**: None
**Component**: C++ embedded harness (`cpp/embedded`)
**Tracker**: AZ-3189
**Epic**: AZ-2645

## Problem

The embedded stage checks the C++ core on a Cortex-M4F with a flash budget of 8,192 B and a stack budget of 2,048 B, taken from an early feature criterion, not from a part. The owner's target part is the nRF54L15 (Cortex-M33F, 256 KB of RAM, about 1.5 MB of non-volatile memory, 128 KiB of RAM in a non-secure image). On the M4F target the string codec stays out of the flash figure and message error correction is switched off, so nothing checks the whole core on the part's architecture, and loops 61 to 67 spent effort on bytes no part needs.

## Outcome

- The arm stage has a `cpp-m33f` row that builds the whole core (codec and error correction on) and the all-kinds scheme for a Cortex-M33F, runs it on QEMU `mps2-an505` with the vector runner, and reports flash and stack against ceilings of 64 KB and 8 KB with pins at the measured figures.
- The M4F row and its pins stay as the small-part bar.

## Scope

### Included
- `cpp/embedded/arm.sh` (`target_m33f`), `cpp/embedded/lib.sh` (budgets and pins), `cpp/embedded/run.sh` (table row), `cpp/embedded/arm/mps2-an505.ld`, `cpp/embedded/arm/stack_meter.hpp` (window above the ceiling), `cpp/embedded/run-parts.test.sh` (oracle row).
- `AGENT_GOTCHAS.md`, the C++ description and `tests.md` (AC-9).

### Excluded
- `cpp/src/core`, `cpp/include`, other packages.
- Real hardware, TrustZone non-secure images, the RISC-V coprocessor, cycle timing.
- Dropping the M4F target (the owner may decide later).

## Acceptance Criteria

See `_docs/02_task_plans/nrf54l15-m33-target/acceptance_criteria.md` (AC-1 to AC-10); copied here:

**AC-1: The target builds the whole core** — row `cpp-m33f`, codec and error correction on, `-mcpu=cortex-m33 -mfloat-abi=hard -mfpu=fpv5-sp-d16`, 0 warnings.
**AC-2: It runs on a Cortex-M33 machine** — `mps2-an505`: FAILURES 0, packet equals M3's, 290 of 290 vectors, 0 exception, heap and OS random references.
**AC-3: Flash ceiling and pin** — all-kinds image at most 65,536 B (25,720 B today), `m33f_flash_pin` = measured.
**AC-4: Stack ceiling and pin** — net stack at most 8,192 B (724 B today), `m33f_stack_pin` = measured, meter window above the ceiling.
**AC-5: No static RAM** — core `.data` plus `.bss` is 0 B.
**AC-6: The ceilings and pins bite** — a pin 1 B lower or a ceiling below the figure fails the row.
**AC-7: Other targets unchanged** — M0+, M3, M4F (7,712 B / 540 B), s390x, AVR pass as today.
**AC-8: Harness and CI** — `run-parts.test.sh` lists `cpp-m33f` after `cpp-m4f` and passes; `embedded-arm` runs the row.
**AC-9: Notes** — chip, ceilings, pins, secure aliases (code 0x10000000, RAM 0x38000000) and why M4F stays.
**AC-10: Source untouched** — 0 changes in `cpp/src/core` and `cpp/include`.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-8 | `run-parts.test.sh` oracle with `cpp-m33f` | `list arm` order matches, test passes |
| AC-6 | copy of the stage with a pin 1 B low and with a ceiling below the figure | row fails naming the figure and the pin or ceiling |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 to AC-5, AC-7 | HEAD with the change | `docker compose -f docker-compose.test.yml run --rm cpp-embedded` | 6 targets pass, `cpp-m33f` figures within ceilings and equal to pins | — |
| AC-8 | pushed commit | `embedded-arm` job of `test.yml` | green with the new row | — |

## Constraints

- No change in the core source; the figures come from what the core already is.
- The stage runs in the `packbin-embedded` image (QEMU 8.2.2, GCC 13.2.1): code at the secure alias 0x10000000 (the Cortex-M33 starts in Secure state; code at 0x0 locks up), RAM at 0x38000000.
- Wait for host load below 6 before timing the stage.

## Risks & Mitigation

**Risk 1: the AN505 machine differs from the part (TrustZone, memory map)**
- *Risk*: a green QEMU row says nothing about the part's non-secure 128 KiB image.
- *Mitigation*: the ceilings leave a factor of 5 or more over the stack and 2 over the flash; the gap is recorded under `## Not walked`.

**Risk 2: stage time grows**
- *Risk*: the `embedded-arm` job gets longer.
- *Mitigation*: the figure is read in the batch report (the M4F-only measure took 3 s per run).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Figures an AC names are read from a run on HEAD in this loop | read on `c3d8767` (flash 25,720 B, raw stack 788 B) | resolved | Medium |
| M4F target stays beside the M33F row | owner may drop it later | accepted-risk | Low |
| QEMU is not the part | Not walked, recorded | accepted-risk | Low |
