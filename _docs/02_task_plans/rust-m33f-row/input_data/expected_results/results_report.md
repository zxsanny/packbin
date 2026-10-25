# Expected results — loop 70

No new input data: the loop adds a build target and pins, not behavior. Figures are read on HEAD in this loop (batch report), never from an earlier table.

| Check | Today | Required after |
|-------|-------|----------------|
| Rows of the Rust embedded stage | 2 (`rust-m4f`, `rust-mutants`) | 3, `rust-m33f` after `rust-m4f` |
| Sets on the M33F image | 0 | 5 (base, text, ecc, session, frame), `FAILURES` 0, `GOLDEN_OK` 1 |
| Flash and net stack per set on M33F | not measured | at most 65,536 B and 8,192 B; pin = measured with Rust 1.98 |
| Heap, panic path, `.data`+`.bss` on M33F | not checked | none, none, 0 B |
| `ROUTE_HEX` M33F vs M4F | — | equal |
| M4F limits (base 16384/512 ... frame 20480/1991) | as `limits.txt` | unchanged |
