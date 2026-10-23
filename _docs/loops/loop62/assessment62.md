# Feature assessment — loop 62

loop: 62
feature: field-layout-shrink
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-10-23
**Implement pass**: batch 01, `_docs/03_implementation/batch_01_loop62_report.md`
**Verdict**: COMPLETE — 8 covered / 0 out-of-scope / 0 gap-clear / 0 gap-unclear

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | repeat, times, list, dict rounds packed and unpacked | covered | AC-4; `container_tests.cpp`, `flags_times_repeat_member_host_tests.cpp`, `dict_order_host_tests.cpp`, M3/s390x vector runs (287 of 287); `pack_items`, `unpack_items` | intake |
| S2 | bits and packed arrays | covered | AC-4; `counted_tests.cpp`, `packed_bias_novalue_host_tests.cpp`; `pack_small`, `unpack_small` (`array_count`, `item`) | intake |
| S3 | an Array member that is absent (unbound) | covered | AC-4; `novalue_nested_host_tests.cpp`, `hostile_host_tests.cpp`; `m == nullptr` checks before every `array_count(m)` in `pack.cpp`, `values.cpp` | intake |
| S4 | count at capacity, one past it on unpack | covered | AC-4; `counted_tests.cpp`, `container_tests.cpp`, hostile `TooMany` cases; `unpack_items` `filled >= f.size` | intake |
| S5 | nested arrays and rounds in rounds | covered | AC-4; `held_count_nested_late_host_tests.cpp`, `container_tests.cpp`; all-kinds image `RoundChainRow` (arm stage, packets equal Cortex-M3 bytes on s390x) | intake |
| S6 | a later edit grows `Field` again | covered | AC-9; `static_assert(sizeof(void*) != 4 || sizeof(Field) <= 32)` in `table.hpp` (compiled by the host, arm and AVR targets; the host is 64-bit so only arm and x86-32 build it live) | intake |
| S7 | saving under 56 B or stack above 504 B | covered | AC-6; not triggered: flash 7,808 B (-224 B), stack 496 B; the arm stage fails by its own bytes above the new pin | intake |
| S8 | 16-bit targets and the example targets | covered | AC-5; arm stage `cpp-avr-uno` PASS (Uno example flash 15,538 B), M0+, M3, M4F, s390x PASS | intake |

### Gaps that need a decision (gap-unclear)

none

### Gaps that are clear (gap-clear)

none

### Not walked

- A direct test that `array_count` equals the old accessor for an Array of a large element type (alignment of `items` does not move `count`, which is the first member; the `static_assert(offsetof(...) == 0)` on one instantiation is the guard, and the standard-layout rule makes it hold for every `Array<T, N>`).
