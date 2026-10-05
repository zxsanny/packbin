# Batch Report

**Batch**: 5
**Tasks**: AZ-2070_hostile_vectors, AZ-2078_cpp_flag_byte_scope, AZ-2081_cpp_bool_u2_construction
**Date**: 2026-10-05

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2070_hostile_vectors | Done | `fixtures/hostile/{cases.txt,README.md,check-cases.sh,cases.test.sh}`, `.github/workflows/test.yml` (scaffold step), `_docs/02_document/tests/test-data.md` | format check passes on the 17 ids; four corrupted copies fail with the line named; bash 3.2 and Ubuntu 24.04 | None |
| AZ-2078_cpp_flag_byte_scope | Done | `cpp/src/core/unpack.cpp`, `cpp/tests/core/{container_tests,hostile_host_tests,main}.cpp`, `cpp/Makefile` | AC-1, AC-2, AC-3 failed first (AC-3 hung), now pass; 17 hostile cases run on the host | 1 (below) |
| AZ-2081_cpp_bool_u2_construction | Done | `cpp/include/packbin/order.hpp`, `cpp/include/packbin/table.hpp`, `cpp/tests/core/scheme_tests.cpp`, `cpp/tests/compile-fail/{bool_outside_flags,u2_too_wide}.cpp`, `cpp/Makefile`, `README.md` | AC-1, AC-2, AC-4 failed first, now pass; AC-3 regression vectors unchanged | 1 (below) |

Issues:
- gcc 16 (`-Werror`) rejected the empty-`repeat` scheme the AC-3 test builds: `nest()` set `at` and never used it with no children. Fixed with `[[maybe_unused]]` in `table.hpp`.
- The per-scope flag bytes cost stack: the first version (an RAII guard) peaked at 512 B of the 512 B budget (was 464 B). The review flagged the zero margin; the guard became a plain 8 B save and restore on the success paths, and the peak is now 488 B.

## Code Review Verdict: PASS_WITH_WARNINGS

`reviews/batch_05_loop10_review.md`

## Test Suite

| Target | Result | Evidence |
|--------|--------|----------|
| Host (Apple clang 21) | PASS | `all tests passed`; 9 compile-fail cases; 17 hostile cases; nfr 12–24 ms |
| Host (gcc:16 container, `docker compose run --rm cpp`) | PASS | same suite, `all tests passed` |
| Cortex-M0+ build | PASS | 0 warnings; link refs `__cxa_*` 0, heap 0 |
| Cortex-M3 QEMU mps2-an385 | PASS | vectors run 213 = asserted 213 (was 184); malloc/new wrapper calls 0; session vectors 22 |
| Cortex-M4F size/stack | PASS | flash core + 14-field table 7648 B ≤ 8192 (was 7600); deepest pack/unpack 488 B ≤ 512 (was 464); .data/.bss 0 |
| s390x big-endian QEMU user | PASS | vectors 213/213; all-kinds packet equals Cortex-M3 bytes |
| Hostile format check | PASS | `bash fixtures/hostile/cases.test.sh` |

ESP-IDF targets and the packaged examples were not re-run: no ESP, Pico or Arduino source, manifest or build file changed in this batch.

CI-parity: PASS for the host and embedded ARM jobs (`make test`; `docker compose -f docker-compose.test.yml run --rm cpp`; `docker compose … run --rm cpp-embedded`; the `scaffold` hostile check).

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | The AC-2 example `scheme<R>(1, group<&R::flag>(0), u8<&R::v>(1))` is already `SchemeInvalid` for an id reason: an empty group consumes no order id, so the next field must repeat its id. The tests use valid ids (`u8(0), group<&R::b>(1)`) so they prove the placement rule | AZ-2081 AC-2 | Spec example corrected in the tests; no code change | clear |
| 2 | `invalid_utf8` and `invalid_utf8_dict_key` unpack Ok in C++ (borrowed bytes, no validation). The runner accepts `ok` for those two ids only, with a printed note | AZ-2078 Flagged concerns | User decides: validate in the core (about 540 B of flash are left) or mark C++ exempt in `cases.txt` | unclear — user decision (C15) |
| 3 | `oversize_count_times` expects `short_packet` only; a bound `Array` returns `too_many` first. The runner uses an unbound `times` to reach `short_packet` | AZ-2078 Flagged concerns | Propose `short_packet\|too_many` in `cases.txt`, as `oversize_list_count` has | clear |
| 4 | A `times` with an empty body and a huge count spun through the whole count (0.6 s at 0x0fffffff, about 10 s at `u32` max; found by the review) | AZ-2078 Reliability | Fixed here: any round that reads nothing ends an unbound container (`times`, `list`, `dict`) as it ends a repeat; bound containers stop at their capacity. Test `empty-body times ends at once` | clear |
| 5 | A bool nested in a plain `group` inside `flags(...)` is now `SchemeInvalid`; the spec says "child of `flags` or `flag_bit`". No shipped scheme does this | AZ-2081 | README note added; same rule as Rust task 13 | clear |
| 6 | The stack budget is 488 of 512 B: 24 B of margin | AZ-2078 Risk 1 | The next change that deepens the unpack recursion must free stack first | clear |

## Commit

`[AZ-2070] [AZ-2078] [AZ-2081] Add hostile vectors, per-scope flag bytes and bool placement`

## Next Batch: none (AZ-2068 AVR stretch is optional and stays in `todo/`)
