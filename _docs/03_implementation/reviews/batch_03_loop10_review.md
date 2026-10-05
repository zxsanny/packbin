# Code Review Report
**Batch**: AZ-2062, AZ-2063, AZ-2065 | **Date**: 2026-10-04 | **Verdict**: PASS_WITH_WARNINGS

## Findings
| # | Severity | Category | File:Line | Title |
|---|----------|----------|-----------|-------|
| 1 | Medium | Bug | cpp/include/packbin/session.hpp | Failed session pack zeroed `out[0..cap)`, past the reported offset (fixed in batch) |
| 2 | Low | Maintainability | cpp/src/core/pack.cpp | `u2` packs at most 64 values (16-byte scratch); more is `BadValue` |
| 3 | Low | Scope | cpp/include/packbin/session.hpp | `PackSession::is_open()` added beyond the spec |

### Finding Details
**F1: Failed session pack wrote past the offset** (Medium / Bug)
- Location: `PackSession::pack`.
- Description: the subagent wiped the whole output buffer on failure, which breaks feature AC-6 ("bytes written beyond the reported offset: 0").
- Fix applied: only the clear bytes before the offset are zeroed; the session test now checks the byte past the offset is untouched.
- Task: AZ-2065

**F2: u2 scratch** (Low) — the old API had no limit either in practice; 64 two-bit values in one `u2` is far beyond any scheme in the tree.

**F3: `is_open()`** (Low) — read-only, used by the AC-2/AC-4 tests to count sessions. Kept.

## Notes

- Spec compliance: AZ-2062 AC-1/AC-2/AC-3, AZ-2063 AC-1…AC-5, AZ-2065 AC-1…AC-4 each have tests (`grouped_tests.cpp`, `counted_tests.cpp`, `container_tests.cpp`, `session_tests.cpp`, `compile-fail/flags_overflow.cpp`). Every old C++ hex vector for these kinds is asserted through the core.
- Core profile: `session.cpp` includes only `<cstddef>`, `<cstdint>`, `<cstring>`; OS random lives only in `src/os_random.cpp` (host adapter, not in `CORE_SRCS`). AZ-2065 AC-3 test scans core includes.
- One walker (`pack.cpp`, `unpack.cpp`) for all kinds; the old walker is untouched until AZ-2064.
