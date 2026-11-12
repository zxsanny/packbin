# Feature assessment — loop 111

loop: 111
feature: csharp-element-row-lows
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-11-12
**Implement pass**: batch 01 (`_docs/03_implementation/batch_01_loop111_report.md`, commit `bb99503`), completeness `_docs/03_implementation/implementation_completeness_loop111_report.md`
**Verdict**: COMPLETE — 10 covered / 1 out-of-scope / 0 gap-clear / 0 gap-unclear

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | Row form on a `Comment[]` member, 0 / 1 / 3 rows | covered | AC-1; `ElementRowLowsTests.Ac1_Pack_ArrayMemberOfRows_*` (6 cases); `Field.List<T, TChild>(Expression<Func<T, TChild[]>>, ...)`, `Fields<T>.List` | scenarios #1 |
| S2 | Row form on an `IList<Comment>` member | covered | AC-1; `Ac1_Pack_IListMemberOfRows_*` (6 cases, unpack gives `List<Comment>`); `Field.List` `IList<TChild>` overload | scenarios #2 |
| S3 | Row form on an `IDictionary<string, Comment>` member | covered | AC-1b; `Ac1b_Pack_IDictionaryMemberOfRows_*` (2 cases); `Field.Dict` `IDictionary` overload | scenarios #3 |
| S4 | A null array member | covered | AC-1; `Ac1_Pack_NullArrayMember_IsRefusedAsTheListFormRefusesIt`; existing collection pack path | scenarios #4 |
| S5 | Members of another row type, list / dict element row, nested row | covered | AC-2, AC-2b; `Ac2_Scheme_ListElementRow...`, `Ac2_Scheme_DictElementRow...`, `Ac2b_Scheme_NestedRow...` (fail on the old walk, pass now); `SchemeOrder.Walk` element-row case, `WalkFromZero`, `RequireRow` | scenarios #5 |
| S6 | Members declared for a base type | covered | AC-2b; `Ac2b_Pack_MembersDeclaredForABaseRowType_BuildAndRoundTrip`; `RequireRow` (`IsAssignableFrom`) | scenarios #6 |
| S7 | `when` / `times` inside an element row | covered | AC-3, AC-3b; `Ac3_Pack_WhenInside...` (`010200010700`), `Ac3b_Pack_TimesInside...` (`01020002050600`), TypeScript's bytes; existing walker | scenarios #7 |
| S8 | `repeat` inside an element row | out-of-scope | spec `### Excluded`: "A `repeat` inside a list or dict element, or any field after a repeat ... its own cross-package task"; AZ-4206 in `todo/` | scenarios #8 |
| D1 | A map-row-only scheme with nested-row members of another type is now refused | covered | batch 01 discovery 1 (clear: owner chose nested rows, problem.md In scope (2)); README refusal bullet; same `RequireRow` path as S5 | batch_01 discoveries |
| D2 | A member of another row type under a `when` inside an element row | covered | AC-2; `Ac2_Scheme_ElementRowMemberOfAnotherRowTypeUnderAWhen_IsRefusedWhenBuilt` (added from the review); `Walk` threads row and wording through `When` | review Low |
| A1 | Map rows (dictionaries) with the row form on an array / `IList` member | covered | AZ-4199 AC-5 `ElementRowTests.Ac5_Pack_MapRow_*`: map-row pack reads values by member name and never the typed member, and the field tree of the row form is the same for every member type; README unchanged for map rows | assess-round-1 |

### Gaps that need a decision (gap-unclear)

None.

### Gaps that are clear (gap-clear)

None.

### Not walked

None (11 rows, under the cap of 12).
