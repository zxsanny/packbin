# Traceability — loop 111 (AZ-4205, C# element row Lows)

ACs: `_docs/02_tasks/done/AZ-4205_csharp_element_row_lows.md`; tests in `csharp/tests/ElementRowLowsTests.cs` unless named. The AZ-4199 element row they extend is pinned by `csharp/tests/ElementRowTests.cs`.

| id | AC | test | status |
|----|----|------|--------|
| ER-1 | AC-1 | `Ac1_Pack_ArrayMemberOfRows_WritesTheListFormBytesAndRoundTrips` (0, 1, 3 rows; `Fields<T>` and static `Field`) | Covered |
| ER-2 | AC-1 | `Ac1_Pack_IListMemberOfRows_WritesTheListFormBytesAndRoundTrips` (0, 1, 3 rows; both forms; unpack gives `List<Comment>`) | Covered |
| ER-3 | AC-1 | `Ac1_Pack_NullArrayMember_IsRefusedAsTheListFormRefusesIt` | Covered |
| ER-4 | AC-1b | `Ac1b_Pack_IDictionaryMemberOfRows_WritesTheDictFormBytesAndRoundTrips` (both forms) | Covered |
| ER-5 | AC-2 | `Ac2_Scheme_ListElementRowMembersOfAnotherRowType_AreRefusedWhenBuilt`, `Ac2_Scheme_DictElementRow...`, `Ac2_Scheme_ElementRowMemberOfAnotherRowTypeUnderAWhen...` (the first two fail on the loop 110 walk) | Covered |
| ER-6 | AC-2b | `Ac2b_Scheme_NestedRowMemberOfAnotherRowType_IsRefusedWhenBuilt` (fails on the loop 110 walk), `Ac2b_Pack_MembersDeclaredForABaseRowType_BuildAndRoundTrip`; `RowRoundTests.Ac2_Scheme_RoundFieldsDeclaredForAnotherRow_AreRefused` keeps its message | Covered |
| ER-7 | AC-3, AC-3b | `Ac3_Pack_WhenInsideAnElementRow_...` (`010200010700`), `Ac3b_Pack_TimesInsideAnElementRow_...` (`01020002050600`); the hex is what TypeScript writes (measured loop 111) | Covered |
| ER-8 | AC-4, AC-5 | whole C# suite 5,384 of 5,384 on `net10.0` and `netstandard2.0`; `scripts/loop-tests.sh` step 11 (loop record); README C# List section and refusal bullet | Covered |

Out of scope, AZ-4206 (`todo/`): a repeat inside a list or dict element, or a field after a repeat.
