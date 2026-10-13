# Blackbox Tests 15: Loop 22 parity rules and the memory bound (FT-X-66 to FT-X-74)

Part of the blackbox set; the index is [blackbox-tests.md](blackbox-tests.md). Loop 22 (`parity-rules-and-memory-bound`, AZ-2410 to AZ-2418) applied the owner decisions U11 to U17 of 2026-10-12: a count behind a clear `when` with no value is refused in six packages, a C# float list for an integer list is refused at build, Rust refuses per-name `repeat` lists without groups, Python packs a lone value and a `when` list in a `repeat`, Rust packs a short `times` list under `flags`, the default `maxSlots` is 1 048 576, C++ refuses an empty-`when` round body, and the hostile case file grew to 65 cases with a standing wrong-rule test in every loader. Hex, texts and row numbers come from `_docs/03_implementation/reference_loop22.md` (TypeScript is the reference), `batch_01_loop22_report.md` and `_docs/loops/loop22/{notes22,review22,assessment22}.md`. Decision U16 (Java counts a nested-row group as one slot; Go copies TypeScript) changed no code and has no scenario.

**Per-package error type** is as in [blackbox-tests-14](blackbox-tests-14-loop21-slot-rule-and-parity.md): the outcome and the numbers are equal, the type and the quoting differ; message parity is out of scope.

**Packages that skip a row, and why.** C++ has no slot budget and a typed row always holds its members, so it skips the three `pack_novalue_count_clear_when_*` cases (it refuses those rows anyway), both `pack_repeat_unequal_lists_*` cases, `pack_times_short_list_flags` and `pack_element_times_over_bytes_budget`. Rust skips both `pack_repeat_unequal_lists_*` cases (a `repeat` takes its rounds as `__repeat__` groups) and `pack_element_times_over_bytes_budget` (a list element cannot hold a `times`).

Package suites at the batch (commit `04a8cd9`, plus the loaders): TypeScript 917, Python 1099, Java 2252 checks, C# 1840 on net10.0 and netstandard2.0, Rust 489 lib and integration, C++ host and `gcc:16` green; arm embedded stage PASS at 8152 of 8192 B of flash and 456 of 512 B of stack. Loop 21 counts were 880, 1003, 2153, 1479 and 625.

### FT-X-66: A `bits`, `packed` or `sized` count above 0 behind a clear `when`, with no value, is refused in all six packages

**Summary**: `u8 mode; when mode==1 { u8 c }` then a `bits`, `packed` or `sized` member counted by `c`, in a split bit or a combined `flags`; the row `{mode: 0, c: 3}` with no value used to pack a clear bit `010000` and is refused now, as the same shape under `times` is (loop 22, AZ-2410, decision U11).
**Traces to**: AZ-2410 AC-1, AZ-2410 AC-2, AZ-2410 AC-3
**Category**: Errors

**Preconditions**:
- TypeScript, Python, Java, C# (dictionary rows) and Rust (map form) as built in loop 22; C++ already refuses every such row (a typed row has no "no value")

**Input data** (reference section 1, row 56 and its variants; hex is the whole packet):

| Row | Row value | Position | Expected |
|-----|-----------|----------|----------|
| 56 | `{mode:0, c:3}` (3 kinds) | split bit, combined `flags` | refused: `v: the count c is 3 in the row, but no field wrote it (the when that holds it is clear), so the member reads nothing; give the count 0, leave it out, or make the when hold`; no bytes |
| 56 | `{mode:0, c:4n}` (bigint) | split bit | refused with `4` |
| 56 | `{mode:0, c:3}` | plain | unchanged: `v: count c was not written` |
| 56a | `{mode:0, c:0}` | split bit, combined `flags` | packs `010000` |
| 56b | `{mode:0}` (count left out) | split bit, combined `flags` | packs `010000` |
| 56c | `{mode:1, c:3}` (holding `when`, no value) | split bit, combined `flags` | packs `01010300` |
| 56d | `packed` with bias -1: `c:1` / `c:3` | split bit | packs `010000` (1 minus 1 is 0) / refused as `3` |
| 53 to 55 | the same shapes with a value | plain, split bit, combined `flags` | unchanged: refused with `v: count c was not written` (53); packs `01010305` and `0101030105` (54, `bits`, `packed`); packs `010103010203` and `01010301010203` (55, `sized`) |

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack row 56 for the three kinds in both positions | an error naming the member and the count; no bytes. Only these six cells change from loop 21 (a 45-row probe grid) |
| 2 | pack rows 56a to 56d | the bytes above |
| 3 | pack rows 53 to 55 | the loop 21 outcomes |
| 4 | replay `pack_novalue_count_clear_when_bits`, `_packed`, `_sized` | `pack_error` in five packages; C++ skipped with its reason (`kPackSkips21`) |
| 5 | C++: pack the six split-bit and combined-`flags` schemes with count 3, 4, 1, 0 and with the count left out | all refused `BadValue` (a typed row cannot say "no value"; count 0 is refused too, where TypeScript packs `010000`) |

**Expected outcome**: all steps as above. Tests: TypeScript `loop22-novalue-count.test.ts` (`describe` "AZ-2410 U11 a bits count behind a clear when, no value", also `packed` and `sized`: "AC-1 a split bit and a combined flags refuse count 3, naming the member and the count, no bytes", "AC-1 a bigint count is refused too", "AC-2 count 0 and the count left out pack the clear bit as before", "AC-2 a holding when with no value still packs the clear bit", "AC-3 rows 53 to 55 are unchanged ...", "a plain member behind a clear when keeps its own refusal"; "AZ-2410 U11 packed with bias -1": "the count is looked at after the bias ..."), and `loop21-parity-probes.test.ts` (the row 56 pin now expects the refusal for count 3 and the clear bit for count 0); Python `test_loop22_parity.py` (`test_az2410_ac1_row56_a_count_above_zero_with_no_value_behind_a_clear_when_is_refused`, `test_az2410_ac2_rows56a_and_56b_count_zero_and_a_left_out_count_pack_a_clear_bit`, `test_az2410_row56c_a_holding_when_with_no_value_packs_a_count_and_no_items`, `test_az2410_ac3_row56_plain_position_is_unchanged`, `test_az2410_row56d_packed_compares_the_count_after_the_bias`, `test_az2410_a_count_a_field_wrote_before_the_member_is_not_refused`) and `test_az2387_row56_no_value_and_count_zero_behind_a_clear_when_pack_a_clear_bit`; Rust `loop22_parity_tests.rs` (`az2410_ac1_row_56_the_three_kinds_in_a_split_bit_and_a_combined_flags_are_refused`, `az2410_ac2_rows_56a_to_56c_count_zero_count_left_out_and_a_holding_when_pack_unchanged`, `az2410_row_56d_a_packed_count_is_compared_after_its_bias`, `az2410_ac3_the_plain_position_still_names_the_unwritten_count`) and `count_behind_clear_when_tests.rs::az2387_row_56_no_value_behind_a_clear_when_is_refused_since_az_2410`; C# `CountBehindClearWhenTests` (`Ac1_Pack_CountedMemberWithNoValueBehindAClearWhen_IsRefused`, `Ac1_Pack_WideCountBehindAClearWhenWithNoValue_IsRefusedWithTheCountAsGiven`, `Ac1_Pack_CountedMemberWithNoValueInPlainPosition_KeepsItsOwnRefusal`, `Ac2_Pack_CountedMemberWithNoValueAndCountZeroOrLeftOut_PacksAClearBit`, `Ac3_Pack_CountedMemberWithNoValueWhenTheWhenHolds_PacksAsBefore`, `Ac1_Pack_PackedCountIsComparedAfterTheBias`); Java `ClearBitProbesTest.u11NoValueCountBehindAClearWhen`; C++ `held_count_nested_late_host_tests.cpp` (`az2410_no_value_count_behind_a_clear_when`, `az2410_value_rows_are_unchanged`). Open (review22, notes22): the C++ `packed` with bias -1 is refused in every cell and is not traced; a TypeScript count above 2^53 packs the clear bit where Python, Rust, Java and C# refuse (no wire change).
**Max execution time**: 1s per package

### FT-X-67: A C# integer list bound to a `double`, `float` or `decimal` collection is refused when the scheme is built

**Summary**: `List<double>`, `List<float>`, `List<decimal>`, `double[]` and a dictionary of them for an integer `list` or `dict` built and unpacked but pack refused them; the scheme builder now refuses them, naming the member and the type, so a scheme builds if and only if it packs (loop 22, AZ-2411, decision U12; a breaking change for schemes that already failed at pack time).
**Traces to**: AZ-2411 AC-1, AZ-2411 AC-2, AZ-2411 AC-3
**Category**: Errors

**Preconditions**:
- C# on net10.0 and netstandard2.0; no other package changes

**Input data**: the member types of the AZ-2388/AZ-2373 binding matrix (`List<T>`, `T[]`, `IList<T>`, nullable and nested forms) against the integer kinds `U8` to `I64` and `U2`, and against `f32`/`f64` fields.

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | build a scheme whose integer list is bound to `List<double>`, `List<float>`, `List<decimal>`, `double[]`; also an integer dictionary with float values | `ArgumentException`: `'Doubles': ... holds Double elements, which pack refuses for the U32 elements of its field; use an integer element type (a float, double or decimal is for f32 and f64)` |
| 2 | build every member type of the matrix | a scheme builds if and only if a row packs and unpacks through it |
| 3 | build an `f32`/`f64` list bound to `List<float>`/`List<double>` | builds, packs and unpacks as before |
| 4 | pack an integer list bound to an integer member | the loop 21 bytes |

**Expected outcome**: as above. Tests: C# `IntegerListFloatMemberTests` (`Member_BuildsIfAndOnlyIfItPacksAndUnpacks`, `IntegerList_BoundToFloatMember_IsRefusedNamingMemberAndType`, `IntegerList_BoundToAnIntegerMemberThatHoldsTheKind_StillBuildsPacksAndUnpacks`, `FloatList_BoundToFloatMember_StillBuildsPacksAndUnpacks`, `IntegerList_BoundToAnIntegerMember_KeepsItsWireBytes`), `CollectionElementKindTests.Build_ListOfDoubleForAU2Element_Refused` and `CollectionMemberTests.Build_DoubleArrayForAnIntegerList_RefusedNamingMemberAndType` (two tests that built a `List<double>` now expect the refusal; no pin was weakened). Open (notes22 6): a `List<decimal>` for an `f32`/`f64` field is refused at build (existing).
**Max execution time**: 1s

### FT-X-68: Rust refuses per-name `repeat` lists given without `__repeat__` groups

**Summary**: In the Rust map form a `repeat` takes its rounds only from `__repeat__` groups; `repeat { u8 n; u8 x }` with `n = [1, 2]`, `x = [5, 6]` and no groups packed `01` and dropped the lists. It is refused now naming the member (loop 22, AZ-2412, decision U13).
**Traces to**: AZ-2412 AC-1, AZ-2412 AC-2
**Category**: Errors

**Preconditions**:
- Rust map form (`MapScheme`) as built in loop 22. The other five packages pack those lists as rounds (`01 01 05 02 06`, reference row C1), so no shared hostile case exists

**Input data**: `repeat(0, [u8 n, u8 x])`.

| Row | Row value | Expected |
|-----|-----------|----------|
| two lists | `{n:[1,2], x:[5,6]}` | `PackError::Type("repeat at id 0: 'n' is given without '__repeat__' groups; give the rounds of a repeat as '__repeat__' groups, one per round")` |
| one list, a lone value | `{x:[5]}`, `{n:7}` | refused naming that member |
| empty groups with a list | `{__repeat__: [], n:[1]}` | refused |
| under a clear `flags` bit, under a clear split bit | lists for a `repeat` member | refused |
| groups | `{__repeat__: [{n:1,x:5},{n:2,x:6}]}` | packs as at HEAD |
| nothing given, empty lists | `{}`, `{n:[], x:[]}` | packs `01` (no rounds), as at HEAD |

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the refused rows | the text above; no bytes |
| 2 | pack the rows with groups, with nothing, with empty lists | the HEAD bytes |

**Expected outcome**: as above. Tests: Rust `repeat_lists_without_groups_tests.rs` (`ac1_two_per_name_lists_without_groups_are_refused_naming_the_first_member`, `ac1_one_list_without_groups_is_refused_naming_that_member`, `ac1_a_lone_value_without_groups_is_refused`, `ac1_empty_groups_with_a_list_is_refused`, `ac1_lists_for_a_repeat_under_a_clear_flags_bit_are_refused`, `ac1_lists_for_a_repeat_under_a_clear_split_flag_bit_are_refused`, `ac2_groups_pack_as_at_head`, `ac2_groups_beside_the_same_lists_pack_the_groups`, `ac2_nothing_given_for_the_members_packs_no_rounds`, `ac2_empty_lists_and_empty_groups_pack_no_rounds`, `ac2_flags_and_split_bits_with_groups_or_nothing_pack_as_at_head`), `loop21_parity_probes_tests.rs::az2383_row_27_per_name_lists_without_groups_are_refused_naming_the_member`, and `loop22_parity_tests.rs::az2414_ac2_a_repeat_given_per_name_lists_is_still_refused`. Open (review22 5): the check misses names of a `times` or `repeat` nested in the repeat body (`repeat { u8 n; times(n) { u8 w } }` with `{w:[1]}` and no groups packs `01`), and lists given beside `__repeat__` groups are dropped without a word.
**Max execution time**: 1s

### FT-X-69: Python packs a lone value and a `when` list in a `repeat`; a short required list stays refused

**Summary**: Python demanded equal list lengths in a `repeat` (`repeat fields must have equal lengths`). That rule is gone: the round count is the longest list, a lone value goes to every round, and a list for a member that only some rounds reach may be shorter. A required member whose list has run out is refused naming the member, as TypeScript does (loop 22, AZ-2413, decision U14).
**Traces to**: AZ-2413 AC-1, AZ-2413 AC-2, AZ-2413 AC-3
**Category**: Errors

**Preconditions**:
- TypeScript, Java and C# as probes (no code change, the outcomes agree); Python changed; Rust takes `repeat` rounds as groups only (FT-X-68)

**Input data** (reference section 3b):

| Row | Scheme and row | Expected |
|-----|----------------|----------|
| R1a, R1b | `repeat { u8 k }`: `{k:7}`; `{k:[7]}`, `{k:[7,8]}` | `0107`; `0107`, `010708` |
| R2a, R2b | `repeat { u8 a; u8 b }`: `{a:[1,2], b:7}`; `{a:1, b:[5,6]}` | `0101070207`; `0101050106` |
| R2c | `{a:[1,2], b:[5,6]}` | `0101050206` |
| R2d to R2f | short or empty required list: `{a:[1,2,3], b:[5]}`; `{a:[1], b:[5,6,7]}`; `{a:[1,2], b:[]}` | refused: `missing b` / `missing a` / `missing b` (Python: `KeyError 'missing field b'`; Java `expected int, got null`; C# `'B' has no value`) |
| R3a to R3c | `repeat { u8 k; when k==1 { u8 v } }`: `{k:[1,2], v:[9]}`; `{k:[1,2], v:[9,8]}`; `{k:[1,1], v:[9,8]}` | `01010902`; `01010902`; `0101090108` |
| R3d | `{k:[1,1], v:[9]}` (a held `when` with too few entries) | refused naming `v` |
| R3e, R3f | `{k:[1,1], v:9}`; `{k:[2,2], v:[9]}` | `0101090109`; `010202` |

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack rows R1 to R3 in TypeScript, Python, Java, C# | equal bytes; the same refusals (Rust: `repeat` rows refused by FT-X-68) |
| 2 | unpack the Python bytes of the `when` and `times`-under-`flags` rows, pack the result again | one entry per round, `None` padding, the same bytes |
| 3 | pack `u8 n` rounds with a lone 60 000-character string, 65 535 rounds | refused by the bytes budget in Python, as before (the bound holds: `maxRounds`, `maxSlots` and `maxBytes` still charge every round) |
| 4 | replay `pack_repeat_unequal_lists_lone`, `pack_repeat_unequal_lists_when` | `0101070207`, `01010902` in four packages; Rust and C++ skipped with reasons |

**Expected outcome**: as above. Tests: Python `test_loop22_parity.py` (`test_az2413_ac2_rows_r1_to_r3_pack_to_the_bytes_of_the_other_packages`, `test_az2413_rows_r2d_to_r2f_a_short_required_list_is_refused_naming_the_member`, `test_az2413_row_r3d_a_held_when_with_too_few_entries_is_refused_naming_the_member`, `test_az2413_ac2_the_packed_rows_unpack_to_one_entry_per_round`), `test_repeat_short_optional.py` (`test_row30_a_lone_value_goes_to_every_round`, `test_row31_a_short_required_list_is_refused_naming_the_member`, `test_row38_a_short_list_under_a_when_outside_flags_packs`) and `test_round_lists.py::test_repeat_a_short_required_list_is_refused_naming_the_member` (replacing the three equal-length pins); the other packages are covered by the shared hostile cases. A lone dictionary or a lone `bytes` in a Python round is still refused.
**Max execution time**: 1s per package

### FT-X-70: Rust packs a short `times` list under `flags` to the bytes of TypeScript

**Summary**: A `times` whose body holds a `flags` and whose list is shorter than the count, empty or lone packs in Rust as in the other packages: the member is absent in the rounds the list does not reach. `repeat` still refuses a short list (AZ-2383). A `times` that is itself a `flags` member (shape B) is refused for a short list in both TypeScript and Rust (loop 22, AZ-2414, decision U15).
**Traces to**: AZ-2414 AC-1, AZ-2414 AC-2, AZ-2414 AC-3
**Category**: Errors

**Preconditions**:
- Rust map form as built in loop 22; the other packages already accept shape A

**Input data** (reference section 3a, shape A `u8 c; times(c) { flags { u8 v } }` unless named):

| Row | Row value | Expected |
|-----|-----------|----------|
| A1 | `{c:2, v:[5]}` | `0102010500` |
| A2, A3 | `{c:2, v:[]}`; `{c:2}` | `01020000` |
| A4 | `{c:2, v:[5,6]}` | `010201050106` |
| A6, A7 | `{c:2, v:5}`; `{c:0}` | `010201050105`; `0100` |
| A8 to A11 | with `u8 w` beside the `flags`: `{c:2,w:[1,2],v:[5]}`; `v:[]`; `v:[5,6]`; `{c:3,w:[1,2,3],v:[5]}` | `01020101050200`; `010201000200`; `0102010105020106`; `010301010502000300` |
| `repeat` | `repeat { u8 w; flags { u8 v } }`, `{w:[1,2], v:[5]}` | refused: `v: 1 items, repeat count 2; ...` (TypeScript text) |
| B1 to B6 | `times` as a `flags` member or flag bit, short list | refused `missing pt` (TypeScript); Rust refuses |
| longer | list longer than the count | refused (`has 3 items, count is 2`) |
| under a `when` | list for a member under a `when` inside a `times` | Rust refuses (`'v' is under a flags or when`), TypeScript packs: open row, see below |

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack rows A1 to A11 in Rust | the TypeScript hex (A5, a `null` entry, is not expressible in Rust) |
| 2 | pack the `repeat` row and shape B rows in Rust | refused |
| 3 | unpack the packed bytes in Rust and TypeScript, pack again | the same rounds |
| 4 | replay `pack_times_short_list_flags` | `0102010500` in five packages; C++ skipped (an `Array` with one item per round) |

**Expected outcome**: as above. Tests: Rust `loop22_parity_tests.rs` (`az2414_ac1_rows_a1_to_a7_a_short_empty_full_or_lone_list_packs_the_typescript_bytes`, `az2414_ac1_rows_a8_to_a11_a_required_member_beside_the_flags`, `az2414_two_members_under_one_flags_are_read_by_round_independently`, `az2414_a_list_longer_than_the_count_or_for_count_zero_is_refused_a_lone_value_for_zero_packs`, `az2414_a_list_for_a_member_under_a_when_is_still_refused`, `az2414_ac2_a_repeat_given_per_name_lists_is_still_refused`, `az2414_shape_b_a_times_that_is_a_flags_member_is_refused_for_a_short_list_as_in_typescript`, `az2414_ac3_the_packed_bytes_unpack_to_the_rounds_and_pack_again`, `az2414_a_group_under_the_flags_is_read_by_round_too`), `times_tests.rs::ac7_a_short_list_under_a_flags_member_leaves_it_absent_in_the_later_rounds` and `times_longer_tests.rs` (`ac7_a_list_longer_than_the_count_under_a_flags_member_is_refused`, `ac1_map_per_name_list_for_a_member_under_flags_is_read_one_item_per_round`, `ac1_map_single_value_for_a_member_under_flags_is_in_every_round`; three old "is refused" pins replaced by decision). Open (review22 1, 9): Rust unpack gives per-name lists with only the rounds that read the name, so repacking from them after dropping `__times_N` shifts values (`01030105010700`); repack from the `__times_N` groups. The Rust refusal of a list for a member under a `when` inside a `times` is a loop 23 owner row.
**Max execution time**: 1s

### FT-X-71: The default `maxSlots` is 1 048 576; the worst-case packet is refused and its memory is bounded

**Summary**: The default `maxSlots` is 1 048 576 in C#, TypeScript, Java, Rust and Python (4 194 304 before loop 22); `maxRounds` (65 535) and `maxBytes` (16 MiB) are unchanged; raising the limit on a scheme still works; C++ has no slot budget (loop 22, AZ-2415, decision U17, finding F10).
**Traces to**: AZ-2415 AC-1, AZ-2415 AC-2, AZ-2415 AC-3, AZ-2415 AC-4
**Category**: Resource limits

**Preconditions**:
- The five growable packages as built in loop 22

**Input data**: the F10 packet (4 259 778 bytes, 4 194 240 slots): `list items` of a group `{ u8 n; times(n) { 64 x u8 } }`, 65 535 items of `n` = 1 (reference section 2); and `pack_slots_over_limit` (`u32 n; times(n){ 65 x u8 }`, `n` = 65 535).

| Moved figure | Before (4 194 304) | After (1 048 576) |
|--------------|--------------------|-------------------|
| `pack_slots_over_limit`: first refused round, text | 64 528, `m0: the rounds would hold 4194320 slots, above the limit of 4194304 slots` | 16 132, `m0: the rounds would hold 1048580 slots, above the limit of 1048576 slots` |
| `pack_element_times_over_budget` (40 items) | refused by the bytes budget (16 777 223 bytes) | refused by the slots limit at item 17: `k: the rounds would hold 1048577 slots, above the limit of 1048576 slots` |
| F10 unpack | unpacks | refused at item 16 385 (TypeScript `field: "k0"`, `left` 3 194 814) |
| 1 MiB packet of one-byte rounds, 37-name body | refused at round 65 536 by `maxRounds` (`left` 983 041) | refused at round 28 340 by slots (`left` 1 020 237) |

**Memory ceiling** (F10 shape, peak resident set, fresh process, one run each; TypeScript three runs, spread under 2 percent; batch report):

| Package | Before (4 194 304) | After (1 048 576) | Share of old peak | Note |
|---------|--------------------|-------------------|-------------------|------|
| TypeScript | 1 070 MB | 353 MB | 33 % | Node 22 |
| Java | 960 MB | 317 MB | 33 % | `-Xmx4g`; 824 to 273 MB at `-Xmx1g` |
| C# | 733 MB | 235 MB | 32 % | typed unpack; dictionary read 731 to 232 MB |
| Python | 550 MB | 162 MB | 29 % | |
| Rust | 628 MB | 120 MB | 19 % | stand-in shape (64-wide `times`, 65 535 rounds): a list element cannot hold a `times` |

All under 400 MB. The slot count is exactly a quarter; the runtime floor and the packet do not shrink, so peak RSS is 19 to 33 % of the old peak (AC-2 read by the parent as the slot count, plus a ceiling under 400 MB).

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | read the defaults of a scheme built with no limits | 65 535 rounds, 1 048 576 slots (`DefaultMaxSlots`, `DEFAULT_MAX_SLOTS`) |
| 2 | unpack the F10 packet at the defaults | refused with the slots text naming 1 048 576; memory in the table |
| 3 | unpack it with `maxSlots` raised to 4 194 304 | unpacks (TypeScript, Java, C#; Python and Rust raise the limit in the pack tests) |
| 4 | pack the 16 items x 65 535 rounds of one lone 16-character `utf8` (1 048 560 slots, 18 874 147 bytes) | refused by the bytes budget; with `maxBytes` 33 554 432 packs and unpacks |
| 5 | run the package suites, the golden and hostile fixtures | green after the number updates |

**Expected outcome**: as above. At the new default a round body wider than 16 names can no longer run 65 535 rounds (1 048 576 is 16 x 65 535). Tests: TypeScript `loop22-max-slots.test.ts` ("AC-1 a scheme built with no limits reads 65 535 rounds and 1 048 576 slots", "AC-2 the F10 packet (4.3 MB, 4 194 240 slots) is refused at the default and peaks well under the old 1 070 MB", "AC-3 with maxSlots raised to 4 194 304 the same packet unpacks") with `support/unpack-memory.ts`, `round-limits.test.ts` (the constants; "refuses a 1 MiB packet of one-byte rounds with 36 names after 28,339 rounds, where maxSlots 1,048,576 is reached"), `pack-output-budget.test.ts`; Python `test_round_limits.py::test_ac1_defaults_and_surface` and `test_ac8_a_one_mebibyte_packet_is_refused_by_the_slot_limit_before_the_round_limit`, `test_loop22_parity.py::test_az2415_ac2_the_f10_packet_is_refused_by_the_slots_at_the_default_limit`, `test_pack_output_budget.py` (`test_ac2_row2_an_element_that_holds_a_times_is_refused_by_the_slots_at_the_default_limit`, `test_ac2_row3_an_element_row_under_the_slots_is_refused_by_the_bytes_budget`, `test_ac2_row3_a_raised_bytes_budget_packs_the_element_row_that_the_slots_allow`); Rust `loop22_parity_tests.rs` (`az2415_ac1_the_default_is_a_quarter_of_the_old_one`, `az2415_ac2_a_4_2_mb_packet_of_64_slot_rounds_is_refused_at_the_slot_limit`) and `round_limits_tests.rs`; Java `RoundLimitsTest.defaultSlotsBoundTheWorstCasePacket` (with `UnpackMemory.java`) and `PackBudgetTest.rows2And3AnElementThatHoldsATimesUnderTheSlotsLimit`; C# `RoundLimitTests.Ac1_DefaultsAndConstants`, `PackSlotBudgetTests` (`Ac2_Unpack_CheapestBodyPacketAtTheDefault_IsRefusedAtTheSlotLimit`, `Ac3_Unpack_CheapestBodyPacketWithTheLimitRaised_Unpacks`) and `PackOutputBudgetTests`. The TypeScript test asserts peak RSS under 535 MB (`peakMB < 535`, half of the old 1 070 MB; measured 353 to 355 MB), loosened in commit `1dceae6` after review22 7 so platform and GC variance cannot flake it; the 400 MB ceiling is the measured figure in the table, not the assertion.
**Max execution time**: 5s per package

### FT-X-72: A C++ `repeat` or `times` whose body is only an empty `when` or group is refused at construction

**Summary**: `check_shape` looked at the direct children of a round, so `times(1, 0, when(...))` with no child built. `has_member` in `cpp/include/packbin/order.hpp` looks through `when` and groups as the D8 rule does in the other five packages; a body of only empty `when`s and groups is `SchemeInvalid`; a zero-width `bytes`, a flag byte, a member-less `flags` and a `when` that holds a member still build (loop 22, AZ-2416, gap G1).
**Traces to**: AZ-2416 AC-1, AZ-2416 AC-2, AZ-2416 AC-3
**Category**: Errors

**Preconditions**:
- The C++ core as built in loop 22; the check is a `constexpr` helper, so a compile-time scheme fails to compile

**Input data**: bodies built with `eq(-1, ...)` (no source) because a `when` in a round cannot name a field outside it and `eq(0, 1)` is refused for its source first.

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | validate a `times` and a `repeat` whose body is an empty `when`; a `when` of an empty `when`; an empty group; a group of an empty `when`; a group of a group of an empty `when` | `SchemeInvalid` at the round's field id |
| 2 | validate bodies with a `when` holding a `u8`, a `when` of a `when` with a `u8`, a group holding a `when` with a zero-width `bytes`, a group with a `u8`, a zero-width `bytes`, a member-less `flags`, a flag byte | build |
| 3 | run the arm embedded stage | flash 8152 of 8192 B (margin 40 B), stack 456 of 512 B (margin 56 B), unchanged from loop 21 |
| 4 | replay `construct_empty_when_times_body`, `construct_empty_when_repeat_body`, `construct_empty_nested_when_body` | `scheme_error` in six packages (see FT-X-73 for which rule fires first) |

**Expected outcome**: as above. Tests: C++ `times_count_zero_host_tests.cpp` (`az2416_empty_when_round_body_is_refused`, `az2416_member_round_body_builds`) and `hostile_host_tests.cpp`. Open (review22 6, notes22 2): the AZ-2416 tests reach the rule with `eq(-1, ...)`, a shape C++ builds without error (the `when` never holds, its member is dropped on pack, unpack of the same packet fails); a negative `eq` field id should be `SchemeInvalid` (loop 23 spec, flash check). Through public builders in Python, Java, C# and Rust the rule is unreachable on its own: any in-scope `when` source is a body member.
**Max execution time**: 1s

### FT-X-73: The hostile case file holds 65 cases; six loaders replay the ten new ones

**Summary**: Ten cases were added at the end of `fixtures/hostile/cases.txt` (7 `pack`, 3 `construct`) from the loop 22 reference; the text of the cases that carry the default `maxSlots` was updated (loop 22, AZ-2417; `check-cases.sh` ok: 65).
**Traces to**: AZ-2417 AC-1, AZ-2417 AC-2
**Category**: Errors

**Preconditions**:
- The fixtures of loop 22 and the six loaders; the loaders were the first run of the new cases in the other packages

**Input data**:

| Case | Stage and expected | Scheme and row (README section of the id) | Run by | Not run by |
|------|--------------------|-------------------------------------------|--------|------------|
| `pack_novalue_count_clear_when_bits` | `pack_error` | `u8 mode; when mode==1 { u8 c }`; split bit { `bits v` count `c` }; `mode` 0, `c` 3, no `v` | TypeScript, Python, Java, C# (dictionary rows), Rust (map form) | C++ (a typed row has no "no value") |
| `pack_novalue_count_clear_when_packed` | `pack_error` | same with `packed` width 1 | as above | C++ |
| `pack_novalue_count_clear_when_sized` | `pack_error` | same with `sized` | as above | C++ |
| `pack_repeat_unequal_lists_lone` | `bytes` `0101070207` | `repeat { u8 a; u8 b }`; `a` [1,2], `b` 7 | TypeScript, Python, Java, C# (dictionary rows) | Rust (rounds as groups only), C++ (a typed `Array` of round items) |
| `pack_repeat_unequal_lists_when` | `bytes` `01010902` | `repeat { u8 k; when k==1 { u8 v } }`; `k` [1,2], `v` [9] | as above | Rust, C++ |
| `pack_times_short_list_flags` | `bytes` `0102010500` | `u8 c; times(c){ flags { u8 v } }`; `c` 2, `v` [5] | TypeScript, Python, Java, C# (dictionary rows), Rust (map form) | C++ (an `Array` with one item per round) |
| `pack_element_times_over_bytes_budget` | `pack_error` | `list items of group { u32 n; times(n){ utf8 s } }`; 16 items of `n` 65 535, `s` 16 x `a` (18 874 147 bytes, 1 048 560 slots, refused by `maxBytes` 16 777 216 in item 15 at round 14 575) | TypeScript, Python, Java, C# (dictionary rows) | Rust (a list element cannot hold a `times`), C++ (no output budget) |
| `construct_empty_when_times_body` | `scheme_error` | `times` whose body is an empty `when` | six packages | none |
| `construct_empty_when_repeat_body` | `scheme_error` | `repeat` whose body is an empty `when` | six packages | none |
| `construct_empty_nested_when_body` | `scheme_error` | `times` whose body is a `when` of an empty `when` | six packages | none |

Updated texts: `pack_slots_over_limit` (refused at round 16 132 with 1 048 580 slots), `pack_element_times_over_budget` (now refused by the slots limit; the bytes route is the new `pack_element_times_over_bytes_budget`), and the Limit lines of `repeat_rounds_over_limit` and `times_rounds_over_limit` (default 1 048 576). AZ-2412 has no case: a case has one outcome and five packages pack the lists.

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | run `fixtures/hostile/check-cases.sh` and `cases.test.sh` | `hostile cases ok: 65`; the corrupted copies still fail |
| 2 | replay the ten cases and the 55 older ones in each loader | every case matches its rule-table entry; the 55 older cases are unchanged except the numbers above |
| 3 | read which rule refuses each `construct_empty_*when*` case | the README shape names the `when` source outside the round, so the scope rule refuses it first in Python, Java, C#, Rust and C++ (by its source check); only TypeScript reaches the empty-body rule through the public builder. Each package pins the empty-body rule in its own tests |

**Expected outcome**: 65 cases; the loaders skip as in the header. Loaders: TypeScript `hostile.test.ts` with `support/hostile-pack.ts` and `support/hostile-cases.ts`; Python `test_hostile_vectors.py` with `hostile_loop22_support.py` and `hostile_refusals.py` (`test_loop22_construct_scheme_is_refused_by_scheme_too`); Java `HostileVectorTest` with `HostileLoop22` and `HostileRefusals`; C# `HostilePackVectorTests.PackCase_ReturnsTheBytesOrRefuses`, `HostileVectorTests.ConstructCase_FailsSchemeConstruction`; Rust `hostile_tests.rs` with `hostile_tests/pack_cases.rs` and `hostile_tests/refusals.rs`; C++ `hostile_host_tests.cpp` with `hostile_pack_loop21.hpp`. Open (review22 2): the three `construct_empty_*when*` cases pass for a different rule in five packages; the case asserts `scheme_error` only. A case shape that reaches the empty-body rule is a loop 23 question (notes22 4).
**Max execution time**: 5s

### FT-X-74: Each loader fails when one rule-table entry is wrong; the `row4_packed_*` widths agree

**Summary**: A loader that checks the rule of every refused case now has a standing test that feeds it one deliberately wrong entry (built in the test, nothing on disk changes) and expects a failure naming the case; the loop 21 assessment found the check had been shown only by a temporary edit (loop 22, AZ-2418).
**Traces to**: AZ-2418 AC-1, AZ-2418 AC-2
**Category**: Errors

**Preconditions**:
- The six loaders as built in loop 22

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | run each loader with the real tables | passes (control) |
| 2 | run each loader with one entry changed to another rule, another message, another exception type, or missing | the loader fails naming that case |
| 3 | compare the `row4_packed_*` schemes with the fixture README | nothing to correct: the case exists only in the TypeScript `SPEC` table; the README "width 1" lines belong to the `pack_*_count_clear_when` cases, which TypeScript already builds with width 1 |

**Expected outcome**: all steps as above. Tests: TypeScript `hostile.test.ts` ("a construct case with a wrong rule entry fails naming that case", "a pack case with a wrong rule entry fails naming that case"); Python `test_hostile_vectors.py` (`test_loader_fails_naming_the_case_when_a_pack_rule_entry_is_wrong`, `test_loader_fails_naming_the_case_when_a_construct_rule_entry_is_wrong`, `test_loader_passes_the_same_cases_with_the_right_entries`); Java `HostileRuleTableTest` (control, wrong pack message, wrong pack exception type, missing pack entry, and the three construct forms); Rust `hostile_tests.rs` (`a_wrong_pack_rule_entry_fails_the_loader_naming_the_case`, `a_wrong_construct_rule_entry_fails_the_loader_naming_the_case`, `a_rule_entry_for_a_case_that_is_not_refused_fails_the_loader`, `a_refused_case_without_a_rule_entry_fails_the_loader`); C# `HostilePackVectorTests.WrongRuleEntry_FailsTheLoaderNamingTheCase`, `WrongBytes_FailTheLoader`, `HostileVectorTests.WrongRuleEntry_FailsTheConstructLoaderNamingTheCase`; C++ `hostile_rule_check_host_tests.cpp::wrong_rule_entry_fails_the_loader` (with `hostile_rule_check.hpp`; split out of `hostile_host_tests.cpp`, which review22 found over the 500-line cap).
**Max execution time**: 1s per package

## Loop 22 loop-level acceptance criteria mapped to scenarios

| Loop-level criterion | Scenario |
|----------------------|----------|
| U11 a no-value count behind a clear `when` is refused in six packages | FT-X-66 |
| U12 a C# float, double or decimal collection for an integer list is refused at build | FT-X-67 |
| U13 Rust refuses per-name `repeat` lists without groups | FT-X-68 |
| U14 Python packs a lone value and a `when` list in a `repeat`; a short required list stays refused | FT-X-69 |
| U15 Rust accepts a short `times` list under `flags`; shape B stays refused | FT-X-70 |
| U17 default `maxSlots` 1 048 576 and a memory ceiling under 400 MB | FT-X-71, [resource-limit-tests.md](resource-limit-tests.md) |
| G1 C++ empty-`when` round body refused | FT-X-72 |
| 65 hostile cases replayed by six loaders | FT-X-73 |
| Standing wrong-rule loader tests; `row4_packed_*` widths | FT-X-74 |
| U16 Java counts a nested-row group as one slot (README exception, no code) | no scenario |
