# Batch Report

**Batch**: 1 (loop 111)
**Tasks**: AZ-4205_csharp_element_row_lows
**Date**: 2026-11-12

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-4205_csharp_element_row_lows | Done | 5 files (`Field.cs`, `Fields.cs`, `FieldAccess.cs`, `SchemeOrder.cs`, `README.md`) + 1 new test file | 25 new tests pass; 37 element-row tests (13 AZ-4199 + 24) and the whole C# suite pass | None |

Proof on the old source: the new tests run against HEAD `SchemeOrder.cs` (scratch copy with only the overloads applied) fail exactly the three row-type refusals (the scheme built, no exception); AC-1 does not compile on HEAD (no overload); AC-3 / AC-3b pass on HEAD (they pin the current bytes, equal to TypeScript's).

## Code Review Verdict: PASS_WITH_WARNINGS

5 Low (`/code-review`, high): map-row-only schemes with nested members of another type built before and are now refused (spec risk text corrected, behavior kept as the owner chose); a round bound to a collection inside an element row keeps the top-level wording `this scheme is for` (kept: the existing round message is pinned by `RowRoundTests`); fixture hex duplicated from `ElementRowTests` (kept, the suite's style); no test for a wrong-type member under a `when` in an element row (added); element row detected through the binding flag (no change: every element row has a binding).

## Test Suite

- `env MSBUILDDISABLENODEREUSE=1 dotnet test csharp -v n --nologo` (console logger): 5,384 of 5,384 on `net10.0`; same with `-p:PackbinTarget=netstandard2.0`: 5,384 of 5,384 (before the one review test was added; afterwards the element-row and round tests: 103 of 103 on `net10.0`)
- Failed: 0; Skipped: 0

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | A scheme used only with map rows (dictionaries) whose nested-row members are declared for another type could pack before (values found by name) and is now refused | AZ-4205 AC-2b, Risk 2 | refused, as a top-level member of another type already is; README says so | clear (owner chose nested rows in scope, problem.md In scope (2)) |
| 2 | Before this loop the AZ-4199 batch counted 5,363 C# tests; this run counts 5,384 with 24 new, so 3 fewer than 5,363 + 24 | AC-4 | count read from this run; no test failed or skipped; the earlier figure was taken by another session with a different filter | clear |

## Commit

`[AZ-4205] C# element row: array and IList members, row type checked` — body: one line + `Loop: 111`.

## Next Batch: All tasks complete (AZ-4206 is unclaimed, for a later loop)
