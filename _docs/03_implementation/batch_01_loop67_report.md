# Batch 01, loop 67 report

| Task | Status | Files |
|------|--------|-------|
| AZ-3185_cpp_unpack_flag_scope_stack | Done (shape V5 kept) | `cpp/src/core/unpack.cpp`, `cpp/tests/core/flag_scope_host_tests.cpp`, `cpp/embedded/lib.sh` |

## Figures (Cortex-M4F stage, `-fstack-usage`, read on HEAD `b478c53` and on the changed tree)

| Shape | Stack | Flash | Note |
|-------|-------|-------|------|
| HEAD | 612 B | 7,724 B | level = `with_outer_flags` 32 + `unpack_children` 48 |
| B2 `bool scope` argument | 564 B | 7,720 B | the 5th argument goes on the stack (`Result` is returned through a hidden pointer) |
| B3 outer as two `uint32_t` | 564 B | 7,720 B | no change |
| B4 scope from the entry kind, `outer` copied for a `when` only | 540 B | 7,720 B | GCC 16 `-Werror=maybe-uninitialized` at -O1 to -O3 (host build fails) |
| B4b `outer` always copied | 588 B | 7,716 B | frame 72 B |
| B4c `outer` zero-initialised | 564 B | 7,724 B | frame 64 B |
| **V5** `keep` pointer (null for a group) | **540 B** | **7,712 B** | frame 56 B; clean in gcc:16 -O1/-O2/-O3/-Os; kept |

## AC results

| AC | Result |
|----|--------|
| AC-1 stack <= 548 B | 540 B PASS |
| AC-2 flash <= 7,724 B | 7,712 B PASS |
| AC-3 same bytes and results | host suite and `gcc:16` `make test` pass; arm stage 290 of 290 vectors on M3 and s390x; new `when` test fails on a copy without the restore (8 FAIL lines in the broken run, 2 of them the new test); ring and corpus in step 11 |
| AC-4 other targets | m0plus, m3-qemu, s390x, avr-uno (15,402 B flash, was 15,476 B) PASS |
| AC-5 pin and notes | `stack_pin` 540, `flash_pin` 7712; `AGENT_GOTCHAS.md`, C++ description updated |
| AC-7 scope | `cpp/src/core/unpack.cpp`, one test file, `cpp/embedded/lib.sh` |

CI-parity: PASS (`docker run gcc:16 make test` in `cpp`, host `make test`, `docker compose -f docker-compose.test.yml run --rm cpp-embedded`); the full `scripts/loop-tests.sh` is the single step 11 run of this loop.
