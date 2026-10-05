# Batch Report

**Batch**: 2 (assessment round 1 re-entry; python, typescript, csharp, java, rust in parallel, then review fixes)
**Tasks**: AZ-2107_python_zero_width_elements, AZ-2108_typescript_zero_width_elements, AZ-2109_csharp_zero_width_elements, AZ-2110_java_zero_width_elements, AZ-2111_rust_zero_width_elements
**Date**: 2026-10-05

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2107_python_zero_width_elements | Done | 2 files (1 src, 1 test) | 78/78 pass | None |
| AZ-2108_typescript_zero_width_elements | Done | 7 files (4 src incl. pack-fields.ts split, 3 tests) | 80/80 pass | None |
| AZ-2109_csharp_zero_width_elements | Done | 8 files | 136/136 pass | None |
| AZ-2110_java_zero_width_elements | Done | 4 files | java/test.sh green (44 methods + 10 vectors) | None |
| AZ-2111_rust_zero_width_elements | Done | 7 files | 88/88 pass | None |

## Code Review Verdict: PASS_WITH_WARNINGS

Three fresh-reviewer reports (python+typescript PASS; csharp+java and rust PASS_WITH_WARNINGS). No Critical or High, no wire regression. Fixed after review:

- C#: two tests passed on the old code (now assert needed 0 / left 0); unreachable `Scope` parent chain removed; accept-side orphan-bit tests assert values.
- Java: flag-bit construction message names kind plus id; real 131 KB amplifier test; stale fallback comment.
- Rust: typed `Scheme::new` refusal test (fails if the enforcing check is disabled); spec-named tests; stale docs.
- TypeScript: aligned `flag-scope.ts` with the other packages (bit inner field uses a copy of the visible set; combined `flags` members are checked); alias removed; group-transparency test.

## Test Suite

CI-parity: PASS — `docker compose -f docker-compose.test.yml run --rm {csharp,typescript,python,rust,cpp,java}`, `bash fixtures/hostile/cases.test.sh`, `bash .github/workflows/report-row.test.sh`.

- Python 78, TypeScript 80, C# 136, Rust 88 (68 lib, 6, 10, 4), Java all four runners, C++ untouched

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | The specs' literal AC-1/AC-2 packets (`01ffffffff`, `01ffff0100 61`) already errored (short packet) on the old code; the tests assert the exact zero-width shape and a real amplifier packet instead | AZ-2107..2111 AC-1, AC-2 | Done; specs keep their wording | clear |
| 2 | A flag bit before its flag byte in the same scope is also a construction error in all four packages that have split form (TypeScript, C#, Java, Rust) | AZ-2108..2111 AC-5, AZ-2100 AC-3 | Done; Python gets it with AZ-2100 | clear |
| 3 | Rust matches the flag byte by name; TypeScript, C# and Java match by object identity, so two handles named alike build in Rust and are refused elsewhere | AZ-2111 | Leave; runtime keys differ per package | unclear |
| 4 | Newly refused shape: flag byte in `when A`, bit in a later `when B` with the same condition (worked before) | AZ-2108..2111 | List as a breaking change in release notes | clear |
| 5 | TypeScript: a `when` inside a list or dict element resolves its condition id against top-level ids (element-local ids restart at 0) | AZ-2108 | Pre-existing; follow-up | unclear |
| 6 | C#: a `Group` as a list or dict element throws KeyNotFoundException on unpack | AZ-2109 | Ticket AZ-2119 | clear |
| 7 | C#: a `When` directly under combined `Flags` is dropped on pack (pack and unpack disagree) | AZ-2109 | Ticket AZ-2120 | clear |
| 8 | Rust bound list whose element is a bare flag bit now panics at construction (no test covers it) | AZ-2111 | Follows the owner decision | unclear |
| 9 | Error label for the zero-width list/dict error is `""` in Python/Java/TS list conventions and the list/dict name in C#, Rust, TypeScript | AZ-2107..2111 | One definition when C15 lands | unclear |

## Commit

`[AZ-2107] [AZ-2108] [AZ-2109] [AZ-2110] [AZ-2111] Zero-width list and dict elements are errors; orphan flag bits refused at build`

## Next Batch: All tasks complete (assessment round 2 next)
