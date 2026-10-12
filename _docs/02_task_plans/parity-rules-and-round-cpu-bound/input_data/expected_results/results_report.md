# Expected I/O — loop 21

Mapped onto rows of `fixtures/hostile/cases.txt` (stage `pack`) added by AZ-2394, plus the unchanged golden and route fixtures. Exact hex rows and error texts come from the TypeScript reference table `_docs/03_implementation/reference_loop21_slots.md` (AZ-2382, AZ-2390) and the existing loop 20 table `reference_loop20_budget.md`.

| Input | Expected |
|-------|----------|
| round packed at `maxSlots`, then unpacked, in each package | round-trips |
| round at `maxSlots + 1` | pack error (slots) |
| optional flags position with a short list | pack error naming the member, no bytes (was `010101050200` in TypeScript) |
| split-bit `times`, count above 0 after the byte, body absent | clear bit packed, TypeScript's bytes in 5 of 5 |
| count 1 behind a clear `when`, no rounds | pack error (was `0100025a00` in Python) |
| `bits` / `packed` / `sized` count behind a clear `when` | pack error in 6 of 6 |
| `times(65535) {}` or `repeat {}` | scheme build error naming the member |
| C# `u8` field with `5.0` | pack error naming the field; `f64` with `5.0` packs |
