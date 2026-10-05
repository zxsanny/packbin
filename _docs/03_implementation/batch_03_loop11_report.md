# Batch Report

**Batch**: 3 (security-audit follow-through; typescript, csharp, java, rust in parallel)
**Tasks**: AZ-2122_typescript_proto_key_when_scope_bom, AZ-2123_csharp_top_range_ints_capacity_session_counter, AZ-2124_java_atomic_session_counter, AZ-2125_rust_capacity_hint_bounded
**Date**: 2026-10-05

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2122_typescript_proto_key_when_scope_bom | Done | 3 files + 4 call-site fixes after review | 89/89 pass | None |
| AZ-2123_csharp_top_range_ints_capacity_session_counter | Done | 5 files | 152/152 pass | None |
| AZ-2124_java_atomic_session_counter | Done | 3 files | java/test.sh green (46 methods + 10 vectors) | None |
| AZ-2125_rust_capacity_hint_bounded | Done | 4 files | 90/90 pass | None |

## Code Review Verdict: PASS_WITH_WARNINGS

One fresh reviewer over the four packages returned FAIL on one High finding, fixed before the commit:

- High: four TypeScript call sites in `walker.ts` still passed `false` to the `round: Value | null` parameter. It ran correctly (falsy), but `tsc --noEmit --strict` over `src` failed with four TS2345 errors while HEAD was clean. Fixed (`false` to `null`), `tsc` clean, 89/89 tests, TypeScript Docker job PASS.
- Low, fixed: stale C# comment and C# package doc line (u64/i64 are no longer boxed as double); `Object.hasOwn` used consistently.

Security re-verification (auditor's own fuzz, 276 855 hostile packets per package): F4, F5, F6, F8, F9 fixed, F7 partly (reservation gone; no packet-size budget, now stated in the README), 0 regressions, 0 new findings.

## Test Suite

CI-parity: PASS — `docker compose -f docker-compose.test.yml run --rm {csharp,typescript,python,rust,cpp,java}` (all six exit 0), `bash fixtures/hostile/cases.test.sh`, `bash .github/workflows/report-row.test.sh`; TypeScript job re-run after the call-site fix; `tsc --noEmit --strict` over `typescript/src/index.ts` clean.

- Python 78, TypeScript 89, C# 152, Rust 90, Java 46 methods + 10 vectors, C++ untouched

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | C# `UnpackResult.Values` holds `ulong`/`long` instead of `double` for u64/i64 (breaking for callers that read 64-bit values straight from `Values`) | AZ-2123 AC-1 | Documented in README and package doc; AZ-2116 does the other kinds | clear |
| 2 | TypeScript: counts naming a field of the same `repeat` round still read the accumulated list (same shape as F6) | AZ-2122 | Follow-up ticket | unclear |
| 3 | TypeScript: a `when` in an outer round naming a field of an inner repeat does not see the inner round | AZ-2122 | Leave | clear |
| 4 | TypeScript: dicts still inherit `Object.prototype` members (`"toString" in dict` is true); `Object.assign({}, dict)` re-triggers the `__proto__` setter on the target | AZ-2122 | README note: use `Object.hasOwn`, copy with care | clear |
| 5 | Java: session `send`/`recv`/`seed` fields are plain; cross-thread packing needs the session opened before other threads start | AZ-2124 | Document; `volatile` is cheap if wanted | unclear |
| 6 | Java: packet number is a `long` with no overflow guard (2^63 packets) | AZ-2124 | Leave | unclear |
| 7 | No packet-size budget: time and memory grow linearly with packet size (1 MB: C# times 265 MB, Rust bits 256 MB) | audit F7 residual | README says to cap the packet length at the transport | clear |
| 8 | Receive counters are plain increments by contract (in-order, one caller) | audit | README states it | clear |

## Commit

`[AZ-2122] [AZ-2123] [AZ-2124] [AZ-2125] Fix security audit findings F4 to F9`

## Next Batch: All tasks complete
