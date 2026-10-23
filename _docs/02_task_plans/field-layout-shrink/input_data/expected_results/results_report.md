# Expected results — loop 62

No new input data: the loop changes a table layout, not behavior. Baseline figures come from loop 61 (`_docs/loops/loop61/record61.md`, `AGENT_GOTCHAS.md`).

| Check | Today | Required after |
|-------|-------|----------------|
| `sizeof(Field)` on 32-bit ARM | 36 B (16 + `eq` 8 + `access`, `item`, `count` 4 each) | at most 32 B |
| `sizeof(Field)` on x64 / AArch64 / x86-32 / AVR | measured in the task and recorded | not larger |
| Cortex-M4F flash of the budget image | 8,032 B (pin), margin 160 B | at most 7,976 B |
| Cortex-M4F deepest stack (all-kinds image) | 504 B of 512 B | at most 504 B |
| Packets of the C++ tests and shared corpus | equal to Python | byte-equal, 0 differences |
| `offsetof(Field, eq)` | 16 | 16 (the `static_assert` stays) |
