# Batch 1 report — loop 62

Task: AZ-PENDING_cpp_field_layout_shrink (3 points; last task). No per-batch review (owner preference); the total review is feature-assess and the total test is step 11.

| Task | Status | Evidence |
|------|--------|----------|
| AZ-PENDING_cpp_field_layout_shrink | Done | `Field::count` removed: an Array's count is its first member (`static_assert(offsetof(Array, count) == 0)`), read in place by `array_count`; readers in `pack.cpp`, `unpack.cpp`, `values.cpp` changed; `sizeof(Field)` 36 B to 32 B on 32-bit ARM with a `static_assert` (at most 32 B where pointers are 4 B). Cortex-M4F: flash 8,032 B to 7,808 B (-224 B; pin lowered to 7,808 B), stack 504 B to 496 B. `make -C cpp test` pass; `gcc:16 make test` pass; arm stage `0 target(s) failed` (m0+, M3 QEMU 287 vectors, M4F, s390x 287 vectors, AVR Uno 15,538 B flash). Shape tried first and kept: A (drop `count`). Not tried: dropping `item` too (needs element offset and stride; no free bytes in the entry). |

AC-1 was relaxed from 28 B to 32 B by the owner in chat (2026-10-23) after the first measurement. CI-parity: PASS by `make -C cpp test`, `gcc:16 make test` and the arm stage (`docker compose run cpp-embedded`); `scripts/loop-tests.sh` runs at step 11.

## Discovered during implementation

| # | Finding | Handling | clear/unclear |
|---|---------|----------|---------------|
| 1 | the saving is 4x the table estimate (224 B, not 56 B): the `array_count<A>` instantiations and their indirect calls were the larger part | recorded in `AGENT_GOTCHAS.md`; margin is now 384 B | clear |
| 2 | the same trick for `item` is not possible without an element offset and stride in the entry | candidate in the loop 63 handoff | clear |
