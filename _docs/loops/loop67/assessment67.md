# Feature assessment — loop 67

loop: 67
feature: flag-scope-times-stack
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-10-25
**Implement pass**: one batch, commit `642f139`
**Verdict**: COMPLETE — 8 covered / 0 out-of-scope / 0 gap-clear / 0 gap-unclear

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| AC-1 | stack <= 548 B on the 0x5e image | covered | arm stage `cpp-m4f` 540 B (HEAD 612 B); `unpack_children` in `unpack.cpp`; `when_chain_host_tests.cpp` rows 0x5e | intake |
| AC-2 | flash <= 7,724 B | covered | arm stage 7,712 B; `flash_pin` 7712 | intake |
| AC-3 / S1-S5 | same bytes, errors and offsets | covered | host `make test` and `gcc:16` `make test` pass (when chains 0x5b to 0x5e, `flag_scope_host_tests.cpp`, `when_flag_bit_host_tests.cpp`, `container_tests.cpp` reuse, dict order); 290 of 290 vectors on M3 and s390x; the ring and corpus are read in step 11 | intake |
| S3 | outer byte 0 back after a `when` that reuses byte 0 | covered | new `outer_byte_serves_a_bit_after_a_when` in `flag_scope_host_tests.cpp`; fails on a copy without the restore (8 FAIL lines, 2 of them this test) | intake |
| AC-4 / S7 | other targets | covered | arm stage: m0plus, m3-qemu, s390x, avr-uno PASS (avr 15,402 B, was 15,476 B) | intake |
| AC-5 / S8 | pins and notes | covered | `stack_pin` 540, `flash_pin` 7712 in `cpp/embedded/lib.sh`; `AGENT_GOTCHAS.md`; C++ description | intake |
| AC-6 / S6 | no-saving branch | out-of-scope | not taken: a shape won; the shape table is in the batch report and `AGENT_GOTCHAS.md` anyway | intake |
| AC-7 | scope | covered | diff touches `unpack.cpp`, one test, `lib.sh` plus docs | intake |

### Residual risk (not a gap in a written criterion)

`unpack_children` now takes its flag-scope decision from the entry kind (`Kind::When`), not from the caller. A future caller that passes a `FlagBit` or another kind gets no restore; today only `unpack_one` (`When`) and the loop in `unpack_children` itself (`When` after `held_of`) call it, and a `Group` is deliberately not a scope. The 12 B between the pin (540 B) and `PackSession::open` (528 B) means a later saving on this chain stops at 528 B unless the session frame also falls.

### Discovered during implementation

| scenario | spec ref | handling | clear |
|----------|----------|----------|-------|
| GCC 16 `-Werror=maybe-uninitialized` on a conditionally copied array (host build only; arm `-Os` and Apple clang do not warn) | AC-3 | `keep` pointer shape (V5), checked in `gcc:16` at -O1, -O2, -O3, -Os | clear |
| `Result` is returned through a hidden pointer, so a fifth argument goes on the stack and a 16 B temporary sits in every `unpack_children` frame | none | recorded in the batch report; not changed (changing `Result` is out of scope) | clear |

### Gaps that need a decision (gap-unclear)

none

### Gaps that are clear (gap-clear)

none

### Not walked

- Pack-side stack (464 B, not the limiting side).
- Whether the CI jobs pass on GitHub: read after the push.
