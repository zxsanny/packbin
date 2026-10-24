# Acceptance criteria — loop 68 (nrf54l15-m33-target)

Project ACs inherited: the C++ package suite, the Cortex-M4F small-part bar (flash 7,712 B pin, stack 540 B pin, loop 67) and the other arm-stage targets. Figures below were read on HEAD `c3d8767` in loop 68 from a scratch build of the new target (Cortex-M33F, full core, QEMU `mps2-an505`). Owner decisions 2026-10-25 (chat and AskQuestion): the target part is the nRF54L15 (Cortex-M33F, 256 KB RAM, about 1.5 MB NVM) or higher; re-base the budgets and add a Cortex-M33F target; ceilings flash 64 KB and stack 8 KB for the C++ core, pins at the measured values.

**AC-1: The target builds the whole core**
Given the arm embedded stage
When it runs after this loop
Then it has a row `cpp-m33f` that compiles the whole core (string codec and message error correction both on) and the all-kinds scheme with `-mcpu=cortex-m33 -mfloat-abi=hard -mfpu=fpv5-sp-d16`, 0 compiler warnings and 0 link warnings.

**AC-2: It runs on a Cortex-M33 machine**
Given the QEMU machine `mps2-an505`
When the all-kinds image and the vector runner run on it
Then the round trip reports FAILURES 0, the all-kinds packet equals the Cortex-M3 packet byte for byte, the runner reports 290 vectors run of 290 asserted (22 session vectors), and the images hold 0 references to exceptions, the heap and OS random, with 0 malloc wrapper calls.

**AC-3: Flash ceiling and pin**
Given the all-kinds image of the new target (codec and error correction included)
When its flash (text plus data) is measured
Then it is at most 65,536 B (25,720 B today) and `m33f_flash_pin` in `cpp/embedded/lib.sh` equals the measured figure.

**AC-4: Stack ceiling and pin**
Given the same image
When it measures the deepest pack and unpack stack, net of the 64 B meter overhead
Then the figure is at most 8,192 B (724 B today: raw 788 B) and `m33f_stack_pin` equals the measured figure; the meter window is larger than the ceiling, so a stack above 8,192 B is reported as a number over the ceiling, not as the window size.

**AC-5: No static RAM**
Given the core objects of the new target
When their `.data` plus `.bss` is summed
Then it is 0 B, as on the Cortex-M4F target.

**AC-6: The ceilings and pins bite**
Given a copy of the stage in which a pin is lowered by 1 B or a ceiling is lowered below the measured figure
When the stage runs
Then the `cpp-m33f` row fails naming the figure and the pin or ceiling.

**AC-7: Other targets unchanged**
Given the existing arm-stage rows
When the stage runs
Then `cpp-m0plus`, `cpp-m3-qemu`, `cpp-m4f` (flash 7,712 B, stack 540 B, both pins unchanged), `cpp-s390x` and `cpp-avr-uno` pass with the figures they have today; the stage reports 0 targets failed.

**AC-8: Harness and CI**
Given `cpp/embedded/run-parts.test.sh` and the `embedded-arm` job of `test.yml`
When they run
Then the test lists `cpp-m33f` in run order (after `cpp-m4f`) and passes, and the job runs the new row through the table with 0 workflow edits besides what the row needs.

**AC-9: Notes**
Given the loop closes
When the docs are read
Then `_docs/AGENT_GOTCHAS.md` and the C++ description name the target chip, the ceilings and pins, the QEMU secure aliases (code at 0x10000000, RAM at 0x38000000) and why the M4F bar stays.

**AC-10: Source untouched**
Given the diff
When it is read
Then 0 changes in `cpp/src/core` and `cpp/include`; the changes are in `cpp/embedded`, its tests and the docs.
