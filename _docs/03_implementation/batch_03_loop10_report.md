# Batch Report

**Batch**: 3
**Tasks**: AZ-2062_cpp_core_grouped_kinds, AZ-2063_cpp_core_counted_kinds, AZ-2065_cpp_core_session
**Date**: 2026-10-04

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2062_cpp_core_grouped_kinds | Done | fields_grouped.hpp, order.hpp, pack.cpp, unpack.cpp, values.*, grouped_tests.cpp, flags_overflow.cpp | pass | None |
| AZ-2063_cpp_core_counted_kinds | Done | table.hpp, fields_counted.hpp, pack.cpp, unpack.cpp, values.*, counted_tests.cpp, container_tests.cpp | pass | 1 Low |
| AZ-2065_cpp_core_session | Done (subagent, parent review) | session.hpp, session.cpp, os_random.*, session_tests.cpp | pass | 1 Medium fixed, 1 Low |

AZ-2065 ran as a parallel subagent with exclusive files; the parent wired the Makefile and `tests/core/main.cpp`, reviewed, and fixed F1.

## Code Review Verdict: PASS_WITH_WARNINGS

`reviews/batch_03_loop10_review.md`

## Test Suite

- `make test` in `cpp/` (Apple clang 21): old suite `all tests passed` (nfr 149 ms); `core tests passed`; 7 compile-fail cases rejected with the expected text.
- CI-parity: PASS — `docker compose -f docker-compose.test.yml run --rm cpp` (gcc:16, clean `build/`): same results, nfr 114 ms.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | A list or dict takes no order id (same as today), so a short list count has no field id to report | AZ-2063, feature AC-6 | `field` is -1 for the list/dict count; errors inside an element report the element's id | clear (order rules unchanged) |
| 2 | The old dict packed keys in sorted order (std::map); the core has no map | AZ-2063 AC-1 | Keys are written in the caller's Array order; the cross-language vector passes with keys in that order | unclear — should pack reject unsorted keys? |
| 3 | Duplicate dict key on unpack was a `ShortPacket` with needed 0 | AZ-2063 | `BadValue` at the second key's entry offset | clear (D-2 B) |
| 4 | A list or dict element is one field; the old API accepted any field kind | AZ-2063 | Element is a leaf (number, utf8) or a nested list/dict; anything else is `SchemeInvalid` at compile time | clear (no vector uses another element kind) |
| 5 | Flag byte and its bits need a pairing key without names | AZ-2062 | `flag_byte(n)` / `bit(n, field)` with n = 0..7; vector mirrors Rust `split_flag_byte_and_be` (`01015a00`) | clear |
| 6 | Session `load` on a session that already holds a seed | AZ-2065 | `load` clears everything first; a bad length leaves no session | unclear (subagent choice) |
| 7 | Copying a session would reuse a pad for the same packet index | AZ-2065 | Copy and move deleted | unclear (security choice) |
| 8 | `start(random)` when random fails | AZ-2065 AC-2 | Returns false, opens nothing, `nonce_out` untouched, 0 bytes padded | clear |
| 9 | Failed session pack leaves clear bytes in `out` | AZ-2065, feature AC-6 | Clear bytes before the offset are zeroed; nothing past it is written | clear |
| 10 | Receive index on a failed unpack | AZ-2065 | Advances on every unpadded packet, as before; the caller buffer holds the (partial) clear bytes | clear (same as old) |
| 11 | `os_random` on a host that is neither Apple nor Linux | AZ-2065 | Reads `/dev/urandom` with `fopen`, like the old fallback | unclear |

## Commit

`[AZ-2062] [AZ-2063] [AZ-2065] Add C++ core kinds and session`

## Next Batch: AZ-2064_cpp_host_on_core, AZ-2066_cpp_target_ci
