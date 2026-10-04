# Batch Report

**Batch**: 2
**Tasks**: AZ-2061_cpp_core_schemes
**Date**: 2026-10-04

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2061_cpp_core_schemes | Done | 13 files | core suite pass; 5 compile-fail cases pass; old host suite pass | 1 Low |

## Code Review Verdict: PASS_WITH_WARNINGS

`reviews/batch_02_loop10_review.md`

## Test Suite

- `make test` in `cpp/` (Apple clang 21): old suite `all tests passed` (nfr 150 ms); `core tests passed`; 6 compile-fail cases rejected with the expected text.
- CI-parity: PASS — `docker compose -f docker-compose.test.yml run --rm cpp` (gcc:16, clean `build/`): same results, nfr 112 ms.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | `when` is listed in AZ-2062, but AZ-2061 AC-3/AC-4 need a `when` to show "names an id not yet walked" and "wrong anchor" | AZ-2061 AC-3, AZ-2062 | `when` is built in this batch; AZ-2062 keeps flags, flag byte and group | clear |
| 2 | A `when` or a count reads a row member, so its target must be bound. The old map API could read an unbound value | AZ-2061 AC-4 | A reference to an unbound field, or to a field outside the current object, is `SchemeInvalid` with the referring field's id | clear (a row-bound API has no other place to hold the value) |
| 3 | Duplicate type numbers in one dispatch used to throw | AZ-2061 AC-1 | `unpack(data, len, on(...), ...)` returns `SchemeInvalid`, field -1, and runs no handler | clear (D-2 B, errors are values) |
| 4 | Each dispatch candidate needs its own row storage | AZ-2061 | `on(scheme, row, handler)`; the handler runs only after the whole packet reads | clear |
| 5 | GCC prints a constexpr argument as written (`s.status.field`), not its value | AZ-2061 AC-3 | The failing id becomes a template argument at compile time only; both compilers print it | clear |

## Commit

`[AZ-2061] Add C++ core scheme tables, dispatch and order checks`

## Next Batch: AZ-2062_cpp_core_grouped_kinds, AZ-2063_cpp_core_counted_kinds, AZ-2065_cpp_core_session
