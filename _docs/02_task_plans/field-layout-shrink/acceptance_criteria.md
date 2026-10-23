# Acceptance criteria — loop 62 (field-layout-shrink)

Project ACs inherited: the C++ package suite (host, `gcc:16`, ring) and the embedded budget (flash at most 8,192 B, stack at most 512 B). New ones:

**AC-1: Entry size**
Given the C++ package built for 32-bit ARM (Cortex-M4F)
When `sizeof(Field)` is read
Then it is at most 32 B (36 B today), and on no other target (x64, AArch64, x86-32, AVR) is it larger than today.

**AC-2: Flash**
Given the flash-budget image of the arm embedded stage (`PACKBIN_NO_TEXT`, 14-entry table)
When it is built after this loop
Then the flash figure is at most 7,976 B (8,032 B today, so at least 56 B saved, half of the expected 112 B).

**AC-3: Stack**
Given the all-kinds image of the arm embedded stage
When it measures the deepest pack and unpack stack
Then the figure is at most 504 B (504 B today).

**AC-4: Same bytes and results**
Given the C++ host suite, the `gcc:16` suite, the ring and the shared corpus
When they run after this loop
Then they pass with 0 changed expectations: packets for Array, list and dict rows are byte-equal to today, and unpacked rows equal.

**AC-5: Other targets build**
Given the `cpp-avr-uno` target and the example targets of `cpp/embedded`
When they are built after this loop
Then each builds as it did before (a stage that fails by design on this host, such as the Pico example, still fails only that way).

**AC-6: No saving**
Given the flash figure of AC-2 is not reached
When the loop closes
Then the library source stays at HEAD, the measured figures and the shape tried are recorded in `_docs/AGENT_GOTCHAS.md`, and the loop closes as a measurement (as loop 61 did); the pin is not raised.

**AC-7: Public API unchanged**
Given the scheme-building API and the examples in the README and `cpp/embedded`
When they are compiled without edits
Then they compile; 0 source changes outside `cpp/include/packbin/table.hpp` and `cpp/src/core` plus their tests.

**AC-8: Pin and notes**
Given AC-2 is met
When the loop closes
Then `flash_pin` in `cpp/embedded/lib.sh` is lowered to the measured figure, and `AGENT_GOTCHAS.md` and the C++ description state the new `sizeof(Field)`, flash figure and margin.

**AC-9: Guarded** (new-task Step 4.7, scenario S6)
Given AC-2 is met
When a later edit makes `Field` larger on a 32-bit target
Then the build fails at compile time (a size check on `Field`, next to the `offsetof(Field, eq) == 16` guard), not only the arm stage.

Owner decision 2026-10-23 (in chat): AC-1 relaxed from 28 B to 32 B after the first measurement (dropping the count pointer alone: flash 7,808 B, stack 496 B; the item pointer needs the element size and stays).
