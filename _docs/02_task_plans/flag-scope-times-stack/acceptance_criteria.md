# Acceptance criteria — loop 67 (flag-scope-times-stack)

Project ACs inherited: the C++ package suite (host, `gcc:16`, ring), the embedded budget (flash at most 8,192 B, stack at most 2,048 B) and the pins `flash_pin` 7,724 B and `stack_pin` 612 B in `cpp/embedded/lib.sh`. Figures below were read from the arm embedded stage on HEAD `b478c53` in loop 67 (`cpp-m4f: PASS ... 7724 B ... 612 B`). Owner decision 2026-10-25 (AskUserQuestion): a win is stack at most 548 B with flash no higher than 7,724 B; otherwise a measured no-go.

**AC-1: Stack**
Given the all-kinds image of the arm embedded stage (`cpp-m4f`, scheme 0x5e: a flag-byte chain three `when`s deep inside a `times` round)
When it measures the deepest pack and unpack stack
Then the figure is at most 548 B (612 B today, at least 64 B less).

**AC-2: Flash**
Given the flash-budget image of the arm embedded stage (`PACKBIN_NO_TEXT`, 14-entry table)
When it is built after this loop
Then the flash figure is at most 7,724 B (7,724 B today; margin to 8,192 B stays at least 468 B).

**AC-3: Same bytes and results**
Given the C++ host suite, the `gcc:16` suite, the ring and the shared corpus
When they run after this loop
Then they pass with 0 changed expectations: packets are byte-equal to today and unpacked rows equal, errors and their offsets unchanged.

**AC-4: Other targets build**
Given the `cpp-avr-uno`, `cpp-m0plus`, `cpp-m3-qemu`, `cpp-s390x` targets and the example targets of `cpp/embedded`
When they are built after this loop
Then each builds and passes as before (the Pico example still fails only by design on this host); the vector count stays 290 run of 290 asserted.

**AC-5: Pin and notes**
Given AC-1 and AC-2 are met
When the loop closes
Then `stack_pin` in `cpp/embedded/lib.sh` is lowered to the measured figure (at most 548 B) and `AGENT_GOTCHAS.md` and the C++ description state the new stack figure, the flash figure and the shape that won.

**AC-6: No saving**
Given AC-1 or AC-2 is not reached by any shape tried
When the loop closes
Then the library source stays at HEAD, the table of shapes with measured stack and flash is recorded in `_docs/AGENT_GOTCHAS.md`, and the pins are not raised (the loop closes as a measurement, as loops 61 and 62 did).

**AC-7: Scope**
Given the change
When the diff is read
Then 0 source changes outside `cpp/src/core` (and its tests) and `cpp/embedded/lib.sh`; the public API, the wire format and the other seven packages are untouched.
