# Expected results — loop 67

No new input data: the loop changes how the C++ unpack walk keeps its flag-scope state, not behavior. Baseline figures read on HEAD `b478c53` in loop 67 (arm embedded stage, `-fstack-usage`).

| Check | Today | Required after |
|-------|-------|----------------|
| Cortex-M4F deepest pack/unpack stack (all-kinds image, scheme 0x5e) | 612 B (raw 676 B less 64 B meter) | at most 548 B |
| Cortex-M4F flash of the budget image | 7,724 B (pin), margin 468 B | at most 7,724 B |
| Frames per flag-scope level | `with_outer_flags` 32 B + `unpack_children` 48 B = 80 B | the shapes tried are measured; a win cuts at least 64 B in all |
| Other frames on the chain | `unpack_table` 64, `unpack_one` 56, `unpack_items` 88, `unpack_one` 56 | not larger |
| Vectors (m3 QEMU, s390x) | 290 run, 290 asserted | 290 / 290 |
| Packets of the C++ tests and shared corpus | equal to Python | byte-equal, 0 differences |
