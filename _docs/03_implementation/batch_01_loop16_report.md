# Batch Report

**Batch**: 1 (loop 16)
**Tasks**: AZ-2112, AZ-2102, AZ-2185 (TypeScript); AZ-2118, AZ-2105, AZ-2117 (+ AZ-2121 AC-3), AZ-2189 (Rust); AZ-2127, AZ-2187, AZ-2190 (Java); AZ-2113, AZ-2104, AZ-2186, AZ-2192 (Python)
**Date**: 2026-10-06

Four package workers in parallel, one directory each; a fix pass by the same workers after the review; Docker suites, the cross-language ring and the hostile-file checks run by the parent.

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2112_typescript_u64_counts | Done (AC-1 to AC-3) | 3 src + 1 new test | in the 323 | none |
| AZ-2102_typescript_list_group_elements | Done (AC-1 to AC-6) | 3 src + 1 new test | in the 323 | dict key flattening is pre-existing (AZ-2184) |
| AZ-2185_typescript_times_list_longer | Done (AC-1 to AC-6) | 2 src + 1 new test | in the 323 | none |
| AZ-2118_rust_pack_checked_count | Done (AC-1) | 2 | in the 261 | none |
| AZ-2105_rust_session_pack_error | Done (AC-1 to AC-4); the Rust handoff driver call site changed by the parent | 4 + driver | in the 261 | `PackSession::pack` is source-breaking (Option to Result) |
| AZ-2117_rust_named_reference_scope | Done (AC-1 to AC-4) + AZ-2121 AC-3 | 6 + 1 new test file | in the 261 | one existing test renamed a condition; hostile vector not added (see below) |
| AZ-2189_rust_map_times_list_under_flags | Done (option A, AC-1 to AC-4) | 4 | in the 261 | empty list still packs |
| AZ-2127_java_nested_rounds | Done (AC-1 to AC-4) + owner decision on inner `repeat` | 5 + 1 new test | in the 1064 checks | gap left for the owner (see below) |
| AZ-2187_java_times_list_longer | Done (AC-1 to AC-6) | 1 + 1 new test | in the 1064 checks | none |
| AZ-2190_java_pack_integer_float_strict | Done (AC-1 to AC-7) | 1 + 1 new test | in the 1064 checks | f64 oversize now refused too (review F3) |
| AZ-2113_python_later_field_refs | Done (AC-1, 2, 4; AC-3 amended) | 1 src + 3 tests + 1 new test file | in the 190 | three existing tests rebuilt |
| AZ-2104_python_session_star_import | Done (AC-1 to AC-5) | 3 + 1 new test | in the 190 | README snippets need aliases |
| AZ-2186_python_times_list_longer | Done (AC-1 to AC-6) | 1 + 1 new test | in the 190 | none |
| AZ-2192_python_float_pack_strict | Done (AC-1 to AC-6) | 1 + 1 new test | in the 190 | `10**400` into f64 stays an unnamed OverflowError (spec excluded) |

## Code Review Verdict: PASS_WITH_WARNINGS

Report: `_docs/03_implementation/reviews/batch_01_loop16_review.md`. First Python verdict FAIL (one High: a weakened existing test), fixed with the owner's approval; the Java Medium on an inner `repeat` fixed by the owner's decision (refuse at pack). Remaining Mediums are pre-existing and owned by AZ-2184.

## Test Suite

CI-parity run by the parent after the fix pass, one stage at a time:

- TypeScript (node 24, Docker): 323 of 323 (was 279); strict `tsc` clean.
- Python (3.14, pinned pytest 9.1.1, Docker): 190 passed (was 103).
- Rust (1.98, Docker): 261 passed, 0 warnings (was 234); host cargo 1.79 debug and `--release` also 261.
- Java (JDK 26, Docker): all four mains pass; 1064 checks counted on the host (was 824), api-check PASS (Android API 26).
- `report-row.test.sh`, `hostile case file` checks (`cases.test.sh`, `check-cases.sh`): pass.
- `language-pair.sh` (all six languages, committed HEAD for C# and C++, loop 16 changes for the other four; `PACKBIN_CXX_SYSROOT` set): PASS in 84 s. Run on an overlay tree (HEAD export plus the batch's changed files) so the owner's uncommitted C# work is not in the gate.
- C# and C++ were not changed in this batch; the C# suite and the owner's uncommitted work are not part of the gate (C# runs from a clean HEAD export at loop end).

Evidence: golden, route and hostile fixtures unchanged; wire bytes of rows that packed before unchanged (differential runs against HEAD in the review).

CI-parity: PASS locally. Linux-only parts: none new; the first CI run after the push decides anything Linux-specific.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | TypeScript: `flattenValues` merges dict entries into the row, so a dict entry member with the same name as a row member overwrites it on pack, depending on key order (also per item of a group element) | AZ-2102, review TS-F1 | AZ-2184 (batch 2) must fix both flatten sites, tests in both key orders | clear |
| 2 | TypeScript: the member-name collision check does not enter list / dict element scopes (`group(g, [u8 a, group(h, [u8 a])])` builds and writes `07 07`) | AZ-2102, TS-F2 | extend `member-names.ts` with a fresh namespace per element, in AZ-2188 (batch 2) | clear |
| 3 | TypeScript: an anchored `group`, `when` or `times` as a direct list / dict element keeps the old flat path | AZ-2102 flagged concern | ticket it, or refuse at construction | unclear (owner) |
| 4 | TypeScript, Python, Java, Rust word the longer-list refusal differently (`x: 3 items, times count 2`, `2: 3 items, times count is 2`, `<id>: list has 3 entries for a count of 2`, `times at id 1: ...`) | AZ-2185, 2186, 2187, 2189 | accepted (kinds unchanged, C15) | clear |
| 5 | Python still builds a `repeat` or `times` inside a round and a count that names a bool or float (TypeScript refuses the count) | AZ-2113 | owner decision or ticket | unclear |
| 6 | Python: `PackSession.load(32)` returns a session keyed by 32 zero bytes (`bytes(32)`) | AZ-2104, review PY-F3 | guard `load` for bytes-like input; spec says `load` is unchanged | unclear |
| 7 | Python: numpy `float32` / ints are refused for float fields (`float64` still works) | AZ-2192 | mention in the upgrade note | clear |
| 8 | Python (pre-existing): a `bool` under `flags` inside a `times` ignores per-round lists (`{"a":2,"on":[True,False]}` packs `01 02 00 00`); a scheme holding a `flag_byte()` node and its `.bit(...)` nodes cannot be built | review PY | new specs or AZ-2128 / AZ-2100 | unclear |
| 9 | Rust: the hostile construct vector `when_names_inner_field_after_times` (AZ-2117 flagged concern) is not added: a new case needs all six loaders, C# included | AZ-2117 | add with AZ-2194 after the C# work lands | clear |
| 10 | Rust: a numeric reference to a slot whose field has a non-numeric name is now refused (it never matched) | AZ-2117 | upgrade note | clear |
| 11 | Rust: `PackError::Type` label text for counts of 2^63 or more changed (`item count out of range`); `src/scheme/bound.rs` is 514 lines at HEAD | AZ-2118 | note only | clear |
| 12 | Rust: AZ-2189's check works on the flat name map; an outer field that shares a member's name is refused as if it were the member's | AZ-2189 | known limit, documented in the spec | clear |
| 13 | Java: an inner `repeat` reached by one round but followed by later rounds, and a field written after an inner `repeat`, still pack bytes that read back differently | AZ-2127 | owner call (the rule built refuses only a second write of the same repeat) | unclear |
| 14 | Java: `flags(.., repeat/times)` drops the group silently (pre-existing, now reachable inside rounds) | AZ-2127, AZ-2128 open concern | refuse at construction or define presence (owner) | unclear |
| 15 | Java: nested-row field ids collide in `seen` with outer ids; `u2` inside a round ignores the round item (both pre-existing at HEAD) | AZ-2127 | fold into AZ-2101 or new specs | unclear |
| 16 | Java: a typed nested row inside a round unpacks into a fresh `HashMap` | AZ-2127, AZ-2101 | handle in AZ-2101 (batch 2) | clear |
| 17 | `fixtures/hostile/README.md:134` still says only Python builds the `when_names_outer_field_in_repeat` shape | AZ-2113 | edit in the docs pass | clear |
| 18 | README and `_docs/02_document/components/04_rust_package/description.md` are stale for references, nested rounds, AZ-2105, AZ-2189, the longer `times` list and `import *` | all | step 13 docs pass (README through the patch route) | clear |

## Commit

`[AZ-2112] [AZ-2127] [AZ-2113] Fix u64 counts, nested rounds, later refs` (≤72 chars). Body: one line per package + all 14 ticket ids + `Loop: 16`. Never `[autodev]` / `docs checkpoint` / `task specs`.

## Next Batch: B2 (TypeScript: AZ-2188, AZ-2128 TS, AZ-2183, AZ-2184, AZ-2197; Rust: AZ-2128, AZ-2114, AZ-2121 AC-4; Java: AZ-2101, AZ-2128, AZ-2114, AZ-2121; Python: AZ-2100, AZ-2134, AZ-2128)
