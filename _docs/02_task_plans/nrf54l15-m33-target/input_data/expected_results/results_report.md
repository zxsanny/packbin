# Expected results — loop 68

No new input data: the loop adds a build target and budgets, not behavior. Baseline figures read on HEAD `c3d8767` in loop 68 from a scratch build (QEMU 8.2.2, `arm-none-eabi-g++` 13.2.1, `-Os`, whole core, codec and error correction on).

| Check | Today | Required after |
|-------|-------|----------------|
| Rows of the arm stage | 5 (`cpp-m0plus`, `cpp-m3-qemu`, `cpp-m4f`, `cpp-s390x`, `cpp-avr-uno`) | 6, `cpp-m33f` after `cpp-m4f` |
| M33F all-kinds image flash | 25,720 B | at most 65,536 B, pin = measured |
| M33F raw pack / unpack stack | 636 B / 788 B | measured; net of 64 B meter at most 8,192 B, pin = measured (724 B today) |
| M33F `FAILURES` of the all-kinds image on `mps2-an505` | 0 (code at 0x10000000, RAM at 0x38000000) | 0 |
| M33F vectors | not run | 290 run of 290 asserted |
| M4F flash / stack | 7,712 B / 540 B | unchanged, pins unchanged |
| Core `.data` plus `.bss` on M33F | 0 B | 0 B |
