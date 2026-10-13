# Blackbox Tests 16: Loop 23 parity rows U19 to U23 and gaps G1 to G3 (FT-X-75 to FT-X-82)

Part of the blackbox set; the index is [blackbox-tests.md](blackbox-tests.md). Loop 23 (`parity-rows-u19-to-u23`, AZ-2431 to AZ-2437) applied the owner decisions of 2026-10-13 (U18 B, U19 to U23 A) and closed the loop 22 assessment gaps G1 to G3: C++ refuses a `when` whose `eq` names an id outside 0..32 767, the C++ empty-body rule is pinned without that spelling, the C++ `packed` bias -1 refusal is traced to the typed row, Rust refuses `repeat` values it used to drop, TypeScript refuses a bigint count above 2^53 in the U11 shape, Python and Rust pin a raised `maxSlots`, the U11 refusal is pinned in six nested positions, and Python packs a short count list in a round whose missing entry sits behind a clear `when` (AZ-2437, found in the batch). Sources: the specs in `_docs/02_tasks/done/` (AZ-2433 AC-1 and AZ-2436 AC-2 as amended), `_docs/03_implementation/batch_01_loop23_report.md`, `_docs/loops/loop23/{review23,assessment23}.md`; review fixes in commit `807e718` (assessment G4 to G6). Decision U18 B (the Rust map form takes a member under a `when` inside a `times` as rounds only) and U21 A (which rule refuses each `construct_empty_*when*` case) are README text with no scenario of their own; the hostile set stays at 65 cases (no new case: U19, U20, U22 and U23 are single-package alignments).

**Per-package error type** is as in [blackbox-tests-14](blackbox-tests-14-loop21-slot-rule-and-parity.md): the outcome and the numbers are equal, the type and the quoting differ; message parity is out of scope.

Package suites at the batch (commit `3c602ff`) and after the review fixes (`807e718`): TypeScript 967, Python 1476, Java 2540 checks, C# 1978 (net10.0), Rust 670 then 673, C++ host, `gcc:16` and s390x (241 of 241) green; arm embedded stage 8152 of 8192 B of flash and 456 of 512 B of stack, unchanged (the U19 check folds at compile time). Loop 22 counts were 917, 1099, 2252, 1840 and 489.

### FT-X-75: C++ refuses a `when` whose `eq` names an id outside 0..32 767; valid ids unchanged

**Summary**: `when(id, eq(-1, v), ...)` built in C++: the `when` never held, its member was dropped on pack and unpack of the same packet failed. The `when()` builder (`cpp/include/packbin/fields.hpp`) now marks a source id below 0 or above 32 767 Invalid (the `int` is compared before the int16 cast, so `eq(32768)`, `eq(65535)` and `eq(65536)`, which the table used to wrap, are refused too); `check_shape` reports `SchemeInvalid` at the `when`'s own id (loop 23, AZ-2431, decision U19, security F36). The other five packages name `when` sources by field name and have no such spelling.
**Traces to**: AZ-2431 AC-1, AZ-2431 AC-2, AZ-2431 AC-4
**Category**: Errors

**Preconditions**:
- The C++ core as built in loop 23; a `constexpr` scheme with such an id fails to compile

**Input data**:

| Scheme | Position of the `when` | Expected |
|--------|------------------------|----------|
| `u8 n; when(1, eq(-1, 1)) { u8 c }` | top level | `SchemeInvalid` at 1 |
| `u8 n; group(1) { u8 c; when(2, eq(-1, 1)) { u8 } }` | in a group | `SchemeInvalid` at 2 |
| `times(1, 0) { u8 pt; when(2, eq(-1, 1)) { u8 } }` | `times` round body | `SchemeInvalid` at 2 |
| `repeat(0) { u8 pt; when(1, eq(-1, 1)) { u8 } }` | `repeat` round body | `SchemeInvalid` at 1 |
| `eq(-7, 1)`, `eq(32768, 1)`, `eq(65535, 1)`, `eq(-1, 1)` with no child | top level | `SchemeInvalid` at 1 |
| `eq(0, 1)` and every other non-negative id in the suite | any | builds, packs and unpacks as at `b8b2809` (`eq(0, 1)` packs `010105`) |

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | validate the refused schemes | `SchemeInvalid` at the `when`'s id |
| 2 | pack and unpack with a refused scheme | both return `SchemeInvalid` at the `when`'s id; no bytes, no row |
| 3 | run the whole C++ suite (host, `gcc:16`, s390x) | green; every `eq` with a valid id gives the HEAD bytes |
| 4 | run the arm embedded stage | flash 8152 of 8192 B, stack 456 of 512 B (unchanged) |

**Expected outcome**: as above. Tests: C++ `empty_body_rule_host_tests.cpp` (`u19_negative_eq_source_is_refused_at_the_when`, `u19_any_id_out_of_range_is_refused`, `u19_pack_and_unpack_refuse_the_scheme`) and the whole C++ suite. Three loop 22 builds that used `eq(-1, ...)` (`AZ-2416 AC-2` when with a `u8`, when of a when with a `u8`, group of a when with a zero-width `bytes`) now refuse: that is the U19 rule; the tests moved to FT-X-76 with `eq(0, ...)`. Open (review23 Low 2, assessment23 U25): count ids (`times`, `bits`, `packed`, `sized`) and a field's own id are still cast to int16 without a check: `bits(1, 65536)` builds and binds field 0, a count id of -1 builds and then fails every pack and unpack with `BadValue`.
**Max execution time**: 1s

### FT-X-76: The C++ empty-body rule is pinned on its own, without a source-less `when`

**Summary**: The AZ-2416 tests reached the empty-body rule (`has_member` in `check_shape`, `cpp/include/packbin/order.hpp`) only through `eq(-1, ...)`, which FT-X-75 now refuses at the same id. The rule is pinned by direct `check_shape`/`has_member` calls on the round's table and by `eq(0, ...)` spellings. C++ runs `check_shape` before `resolve` (the scope rule), so the three hostile `construct_empty_*when*` cases reach the body rule first in C++. An id assertion alone cannot separate the two rules: a round's id is its first child's id (loop 23, AZ-2431, gap G2).
**Traces to**: AZ-2431 AC-3
**Category**: Errors

**Preconditions**:
- The C++ core as built in loop 23

**Input data**: round bodies (`times` and `repeat`): an empty `when(1, eq(0, 1))`; a `when` of an empty `when`; an empty group; a group of an empty `when`; a group of a group of an empty `when`. Member bodies: a zero-width `bytes`, a flag byte, a member-less `flags`, a `when` with a `u8`, a `when` of a `when` with a `u8`, a group of a `when` with a zero-width `bytes`, a group with a `u8`.

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | run `check_shape` on the five empty bodies | refused by the body rule |
| 2 | run `check_shape` on the seven member bodies | the body rule passes them |
| 3 | build a round whose body is only a zero-width `bytes`, a flag byte, a member-less `flags` or a group with a `u8` | builds |
| 4 | build a round whose only member is a `when` holding a `u8` | refused by the scope rule (its source must sit in the round before it, and that source is itself a member; batch discovery 5) |
| 5 | build the three `construct_empty_*when*` hostile shapes and call `check_shape` | refused by the body rule at the round's id (2, 1, 2); `scheme_error` in the loader |

**Expected outcome**: as above. Tests: C++ `empty_body_rule_host_tests.cpp` (`g2_empty_shapes_are_refused_by_the_body_rule`, `g2_member_shapes_pass_the_body_rule`, `g2_hostile_empty_when_vectors_reach_the_body_rule`) and `hostile_host_tests.cpp` (the three cases; the `eq(-1)` helper `empty_when_vectors_reach_the_empty_body_rule` was removed). The loop 22 tests `az2416_empty_when_round_body_is_refused` and `az2416_member_round_body_builds` (`times_count_zero_host_tests.cpp`) moved into this file. In Python, Java, C# and Rust the rule is still unreachable on its own through public builders (any in-scope `when` source is a body member); each pins it in its own tests (FT-X-72).
**Max execution time**: 1s

### FT-X-77: C++ `packed` with bias -1 behind a clear `when`: a bound member is the typed row, an unbound member packs the five's bytes

**Summary**: In the loop 22 U11 grid C++ refused `packed` with bias -1 in every cell. Traced: a member bound to an `Array` is always present (`present`, `cpp/src/core/values.cpp:89-90`), so its bit is set and `pack_small` returns `BadValue` at the member when `ref_value` finds the count's `when` clear (`cpp/src/core/pack.cpp:141-142`), before the bias is added (`:144-145`); bias 0 refuses the same cells. Written unbound (`packed(1, 2, 1, -1)`, no member pointer) the member is never present, and C++ packs `010000` for row 56d as the five do. No source change; README exception (loop 23, AZ-2432, decision U20).
**Traces to**: AZ-2432 AC-1, AZ-2432 AC-2, AZ-2432 AC-3, AZ-2432 AC-4
**Category**: Errors

**Preconditions**:
- C++ as built in loop 23; scheme `u8 mode; when(mode == 1) { u8 c }; <bit> { packed(width 1, count c, bias -1) }`, the bit a split flag byte bit or a combined `flags`

**Input data** (reference_loop22.md rows 56 to 56d):

| Member | Row (`mode`, count, items) | Expected |
|--------|----------------------------|----------|
| bound | clear, empty, count 0 / 1 / 3 / left out | `BadValue` at the member (field 2, offset 3) |
| bound | clear, count 3 with 2 items (row 53) | `BadValue` at the member |
| bound | holding, count 1, no items; count 3, 2 items | `01010101`; `0101030103` |
| bound | holding, count 0; count 3, no items | `BadValue` at offset 4 |
| bound, bias 0 | clear, count 0 / 1 / 3 / left out | `BadValue` at the member (the refusal comes before the bias) |
| unbound | clear, count 1 (56d) / 0 (56a) / left out (56b) | `010000` (as the five) |
| unbound | holding, count 3 (56c) / count 1 | `01010300` / `01010100` |
| unbound | clear, count 3 (row 56) | `010000` where the five refuse (observed, open U24) |

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the bound rows in both bit forms | the outcomes above |
| 2 | pack the unbound rows in both bit forms | the bytes above |
| 3 | run the arm embedded stage | unchanged (no source change) |

**Expected outcome**: as above. Tests: C++ `packed_bias_novalue_host_tests.cpp` (`u20_bound_packed_bias_minus_one_is_the_typed_row`, `u20_unbound_packed_bias_minus_one_is_no_value`). The C++ hostile skip reasons of the three `pack_novalue_count_clear_when_*` cases (`hostile_pack_loop21.hpp`) and the fixture README "Not run by: C++" lines give this trace and point to U24 (assessment23 G4, commit `807e718`). Open (review23 Low 3, assessment23 U24): an unbound `bits`, `packed` or `sized` with count 3 behind a clear `when` packs the clear bit in C++ where the five refuse (owner row, loop 24).
**Max execution time**: 1s

### FT-X-78: Rust refuses `repeat` values it used to drop

**Summary**: AZ-2412 (U13) refused per-name `repeat` lists given without `__repeat__` groups, but the Rust map form still dropped values in two shapes: a value kept beside the groups, and a name of a `times` nested in the repeat body. `repeat` now reuses the `times` list check (`lists_agree`, `rust/src/walk/times.rs`): a value kept beside `__repeat__` groups must be what the rounds hold, else `repeat at id N: list for 'x' disagrees with its rounds`; without groups, a nested name is refused with the U13 text. The review fix (assessment23 G5, G6) adds a `flags` own name in the body and the `__times_<anchor>` key of a nested `times` (`collect_below`, `times_keys`, `declares`) (loop 23, AZ-2433, decision U22, security F37).
**Traces to**: AZ-2433 AC-1, AZ-2433 AC-2, AZ-2433 AC-3, AZ-2433 AC-4
**Category**: Errors

**Preconditions**:
- Rust map form (`MapScheme`) as built at `807e718`. The other five packages take per-name lists as rounds, so no shared hostile case exists

**Input data** (`repeat(0, [u8 n, u8 x])` unless named; HEAD is `3c602ff`'s parent `b8b2809`):

| Row | Row value | Before | Expected |
|-----|-----------|--------|----------|
| kept list disagrees | `{__repeat__: [{n:1,x:5}], n:[2]}` | `010105` | `repeat at id 0: list for 'n' disagrees with its rounds` |
| shorter, lone, empty beside rounds | `x:[5]` beside two rounds; `x:6`; `x:[]` beside one round | packed, value dropped | refused naming `x` |
| under `flags` or a split bit | a kept list beside the groups of a `repeat` member | packed | refused at the `repeat`'s id |
| nested `times` name beside groups | `repeat { u8 n; times(n) { u8 w } }`, `w:[7]` beside groups | packed | `list for 'w' disagrees ...` |
| nested `times` name, no groups | `{w:[1]}`, `{w:1}` (also under a `when`, `flags`, split bit) | `01` | `repeat at id 0: 'w' is given without '__repeat__' groups; give the rounds of a repeat as '__repeat__' groups, one per round` |
| G5 `flags` own name | `repeat { u8 n; flags fl { u8 a } }`: `{fl:5}`, `{fl:[5]}`; in a split bit; `fl:5` beside a round | `01`, `01`, `0100`, `01010102` | U13 text naming `fl` (id 0, id 1 in the split bit); `list for 'fl' disagrees ...` beside groups |
| G6 nested `times` key | `{__times_1: [{w:9}]}` without groups (also under `flags`); beside groups that hold another value | `01`, `0100`, `010109` | U13 text naming `__times_1`; `list for '__times_1' disagrees ...` |
| agreeing values | `n:[1]` beside `[{n:1,x:5}]`; a `__times_1` key identical to the rounds' | `010105`; `010109` | unchanged |
| groups only, nothing, empty values | groups only; `{}`; `{fl:[]}`; `{__times_1: []}` | | unchanged |

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the refused rows | the text above; no bytes |
| 2 | pack the agreeing and groups-only rows | the HEAD bytes (checked against a HEAD copy) |
| 3 | run the `times` list tests (AZ-2414 short list under `flags` included) | green, unchanged |
| 4 | run `cargo test` with the hostile loader | 673 pass; 65 cases as before |

**Expected outcome**: as above. An already refused row may now report the kept-list disagreement before a missing round member (message order only; review23). Tests: Rust `repeat_dropped_values_tests.rs` (`ac1_a_list_beside_groups_that_disagrees_is_refused_naming_it`, `ac1_a_shorter_list_and_a_lone_value_beside_groups_are_refused`, `ac1_two_disagreeing_names_name_the_first_in_name_order`, `ac1_a_list_beside_groups_of_a_repeat_under_flags_or_a_split_bit_is_refused`, `ac1_a_name_of_a_nested_times_beside_groups_is_refused`, `ac2_a_name_of_a_nested_times_without_groups_is_refused_naming_it`, `ac2_a_nested_name_of_a_repeat_under_flags_or_a_split_bit_is_refused`, `ac3_values_beside_groups_that_agree_with_them_pack_the_groups`, `ac3_groups_only_and_nothing_given_pack_as_at_head`, `g5_a_flags_name_without_groups_or_beside_groups_is_refused`, `g6_a_nested_times_key_without_groups_or_beside_groups_is_refused`, `g5_g6_groups_only_empty_values_and_a_key_the_rounds_hold_pack_as_at_head`), `repeat_lists_without_groups_tests.rs`, `loop22_parity_tests.rs` (az2414 rows), `times_tests.rs`, `times_longer_tests.rs`. A `repeat` nested in a `repeat` or `times` cannot be built in Rust (construction panics), so it is not covered (AZ-2433 AC-2 as amended).
**Max execution time**: 1s

### FT-X-79: TypeScript refuses a bigint count above 2^53 in the U11 shape

**Summary**: `refuseUnwrittenCount` (`typescript/src/flag-bits.ts`) read the count through `validCount`, which returns null for a bigint above 2^53, so `{mode: 0, c: 2n**60n}` with a `bits`, `packed` or `sized` behind a clear `when` and no value packed `010000` where Python, Rust, Java and C# refuse. A bigint above `MAX_SAFE` (exported from `kinds.ts`, not from `index.ts`) is now refused with the U11 `RangeError` naming member and count; `validCount` and its other callers are unchanged (loop 23, AZ-2434, decision U23).
**Traces to**: AZ-2434 AC-1, AZ-2434 AC-2, AZ-2434 AC-3
**Category**: Errors

**Preconditions**:
- TypeScript as built in loop 23; scheme `u8 mode; when mode==1 { u8 c }`, then a split bit or a combined `flags` holding `bits`, `packed` (bias 0 and -1) or `sized` counted by `c`

**Input data**:

| Count `c` (row `mode` 0, no value) | Expected |
|------------------------------------|----------|
| `2n**60n`, `2n**53n + 1n`, `2n**53n` | `RangeError` `v: the count c is <n> in the row, but no field wrote it (the when that holds it is clear), so the member reads nothing; give the count 0, leave it out, or make the when hold` (the row's number) |
| `3n`, `3`, `2n**53n - 1n` | refused with the same text, as at HEAD |
| `0n`, `3.5`, `-1`, `"3"`, `NaN`, `true`, `null`, left out | `010000`, as at HEAD |
| `times` behind a clear `when` with a bigint count above 2^53 | packs its clear bit (the U6 split, unchanged) |

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the large-bigint rows for each kind in both positions | `RangeError` with the U11 text |
| 2 | pack the other rows | the HEAD outcome |
| 3 | pack the same 16 counts x 4 members x 2 positions (128 rows) in Python | the same refused/packed outcome and the same number in every message |
| 4 | run the hostile loader | 65 cases pass |

**Expected outcome**: as above. Tests: TypeScript `loop23-bigint-count.test.ts` (per kind, `describe` "AZ-2434 U23 a … count behind a clear when, no value": "AC-1 a bigint count above 2^53 is refused in the split bit and the combined flags, naming member and count", "AC-2 counts that are not above 0 or not a count pack the clear bit as at HEAD", "AC-2 safe counts above 0 keep their HEAD refusal (3n, 3, 2^53 - 1 as a bigint)"; "AZ-2434 U23 leaves the times split (U6) alone": "a times behind a clear when with a bigint count above 2^53 still packs its clear bit"); the Python parity grid is recorded in the test file header and the batch report. Not walked (assessment23): for `packed` bias -1 the message shows the raw count, not count plus bias. The new test files are outside the documented strict `tsc` check of `src/index.ts` (batch discovery 12).
**Max execution time**: 1s

### FT-X-80: Python and Rust unpack the old worst packet with `maxSlots` raised; the default refuses it

**Summary**: AZ-2415 AC-3 (a scheme with `maxSlots` raised to 4 194 304 still unpacks the old worst packet) had standing tests in TypeScript, Java and C# only. Python and Rust now pin it; test-only (loop 23, AZ-2435, gap G1).
**Traces to**: AZ-2435 AC-1, AZ-2435 AC-2
**Category**: Resource limits

**Preconditions**:
- Python and Rust as built in loop 23; no slow marker exists in either package, so the tests run in the default suites (4 to 6 s and a few hundred MB each)

**Input data**: Python, the F10 packet (`list items` of a group `{ u8 n; times(n) { 64 x u8 } }`, 65 535 items of `n` = 1, 4 194 240 slots); Rust, the stand-in `u32 n; times(n) { 64 x u8 }` with `n` = 65 535 (a list element cannot hold a `times`).

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | unpack with `max_slots=4_194_304` (Python) / `with_limits(65_535, 4_194_304)` (Rust) | unpacks; the rows are those at HEAD; Python packs the row back to the same packet at the raised limit |
| 2 | unpack at the default limits (1 048 576 slots) | refused at the slot limit: Python `ShortPacket` with `left` 3 194 814, Rust `Short` with `left` 3 145 664 |
| 3 | Python: one slot below the packet total | the last item is refused |

**Expected outcome**: as above. Tests: Python `test_raised_max_slots.py` (`test_az2435_ac1_with_max_slots_raised_to_4_194_304_the_f10_packet_unpacks_to_the_rows_at_head`, `test_az2435_ac1_the_unpacked_row_packs_back_to_the_same_packet_at_the_raised_limit`, `test_az2435_ac2_the_default_limit_refuses_the_f10_packet_by_the_slots`, `test_az2435_ac2_one_slot_below_the_packet_total_refuses_the_last_item`); Rust `raised_slot_limit_tests.rs` (`ac1_with_max_slots_raised_to_4_194_304_the_old_worst_packet_unpacks`, `ac2_the_default_limits_refuse_the_same_packet_at_the_slot_limit`). Review23 Low 6: the tests are heavy in the default suites; judged at the idle step 11 run, a marker only if they flake.
**Max execution time**: 10s per package

### FT-X-81: The U11 no-value count refusal holds in six nested positions

**Summary**: AZ-2410 (U11) refuses a `bits`, `packed` or `sized` with a count above 0 that no field wrote, behind a clear `when`, with no value. Loop 22 pinned it at the top level only (reference row 56). It is now pinned in six positions x three kinds x split bit and combined `flags` in TypeScript, Python, Java, C# and Rust; C++ pins its own outcome (loop 23, AZ-2436, gap G3; tests only, no source change).
**Traces to**: AZ-2436 AC-1, AZ-2436 AC-2, AZ-2436 AC-3, AZ-2436 AC-4
**Category**: Errors

**Preconditions**:
- The six packages as built in loop 23; the row 56 body is `u8 mode; when mode==1 { u8 c }; <bit> { member(count c) }`

**Input data**:

| Position | AC | Refused row (count 3, no value) | Unchanged rows (count 0, left out, holding inner `when`) |
|----------|----|---------------------------------|----------------------------------------------------------|
| the body inside a group | AC-1 | refused, U11 text | `010000`, `010000`, `01010300` |
| a bit that holds a group holding the member | AC-1 | refused | as above |
| the body inside an outer holding `when` | AC-2 | refused | `01010000`, `01010000`, `0101010300` |
| a bit that holds a holding `when` around the member | AC-2 | refused | as above |
| a `times` round body (round 1 of one, round 2 of two) | AC-3 | refused | `01020100000000`, `01010000`, `0101010300` |
| a `repeat` round body | AC-3 | refused | `010100000000`, `010000`, `01010300` |
| amended AC-2: the member inside the clear inner `when` itself (`when(o holds) { u8 mode; when(mode clear) { u8 c; <bit> { member } } }`) | AC-2 | the existing silent skip, not U11: packs `010100` with and without a value (observed) | — |

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack each refused row in TypeScript, Python, Java, C#, Rust | the U11 `v: the count c is 3 in the row, but no field wrote it ...` text, member and count named; no bytes |
| 2 | pack the unchanged rows | the TypeScript hex as at `b8b2809`; a holding inner `when` with a value packs its items |
| 3 | pack the silent-skip shape | `010100` in six packages |
| 4 | Java and C#: build a nested-row group (`group(get, set, ...)`) whose member counts by a field of the row around it | refused at construction (a nested row has its own id scope; that position is not spellable, pinned as observed) |
| 5 | C++: pack each position with a bound member and with an unbound member | bound: `BadValue` at the member for every row, refused and unchanged alike (the typed row, FT-X-77); unbound: count 3 packs the clear bit (observed, open U24), the unchanged rows give the TypeScript bytes |

**Expected outcome**: as above. Tests: TypeScript `loop23-novalue-nested.test.ts` (`describe` "AZ-2436 U11 no-value count in …" per position: "AC-n a … with count 3 and no value is refused, naming member and count (split bit and combined flags)", "AC-4 a … with count 0, the count left out or a holding inner when packs as at HEAD"; "AZ-2436 a member inside the clear inner when itself is a silent skip, not U11": "packs only the outer bytes for every kind and bit"); Python `test_no_value_count_nested.py` (`test_az2436_ac1_to_ac3_a_no_value_count_above_zero_is_refused_in_nested_positions`, `test_az2436_ac4_count_zero_left_out_and_a_holding_when_pack_as_at_head`, `test_az2436_ac4_a_holding_when_with_a_value_packs_as_at_head`, `test_az2436_a_member_under_a_clear_when_inside_the_bit_is_not_reached_and_packs`, `test_az2436_ac2_observed_a_member_inside_the_clear_inner_when_is_a_silent_skip`); Java `NoValueCountNestedTest` (`refusedNamingMemberAndCount`, `unchangedPacksAsAtHead`, `nestedRowCannotCountByTheRowAround`, `memberInsideTheClearWhenIsASilentSkip`; run from `PackbinTest`); C# `NoValueCountNestedTests` (`Ac1To3_Pack_CountAboveZeroWithNoValueInANestedPosition_IsRefusedNamingMemberAndCount`, `Ac4_Pack_CountZeroLeftOutOrAHoldingWhenInANestedPosition_PacksAsAtHead`, `Ac2_Pack_MemberInsideTheClearInnerWhenItself_IsASilentSkipAsObserved`, `Ac1_Build_NestedRowGroupNamingACountOutsideItsRow_IsRefusedSoThatPositionIsNotSpellable`); Rust `no_value_count_nested_tests.rs` (`ac1_to_ac3_count_3_and_no_value_is_refused_in_every_nested_position`, `ac4_count_zero_count_left_out_and_a_holding_when_pack_as_at_head`, `observed_a_member_inside_a_clear_when_is_skipped_without_a_word`); C++ `novalue_nested_host_tests.cpp` (`az2436_no_value_count_below_the_top_level`, `az2436_member_inside_the_clear_when_is_a_silent_skip`). Open (assessment23 U26): a C# dictionary row reads a nested-row group's names from the outer row, so an inner name shared with the outer row packs the outer value; a nested dictionary under the group's name is not read.
**Max execution time**: 1s per package

### FT-X-82: Python packs a short count list in a round whose missing entry sits behind a clear `when`

**Summary**: In a `times` or `repeat` round body with the row 56 shape, a count list shorter than the rounds, where the round with no entry has its `when` clear, was refused by Python's U11 check (`_at_round` raised past the end of the list): `times {n:2, mode:[1,0], c:[3]}` gave `ValueError: 2: 1 items, times count is 2`, `repeat {mode:[1,0], c:[3]}` gave `KeyError: missing field c`. TypeScript, Java and C# pack them. `_RoundValues.unwritten_count` (`python/src/packbin/_pack_rounds.py`), read by `_refuse_unwritten_count` (`_pack.py`), reads a missing round entry as an absent count. The `times` row packed at `88c063f` (a loop 22 regression from AZ-2410); the `repeat` row was refused there by the old equal-length rule (loop 23, AZ-2437, found by the AZ-2436 Python worker).
**Traces to**: AZ-2437 AC-1, AZ-2437 AC-2, AZ-2437 AC-3
**Category**: Errors

**Preconditions**:
- Python as built in loop 23; scheme `times(n) { u8 mode; when(mode == 1) { u8 c }; <bit> { member(count c) } }` or the same body in a `repeat`, member `bits`, `packed` or `sized`, the bit a split bit or a combined `flags`

**Input data**:

| Row | Expected |
|-----|----------|
| `times {n:2, mode:[1,0], c:[3]}` | `01020103000000` (as TypeScript) |
| `repeat {mode:[1,0], c:[3]}` | `010103000000` |
| the AZ-2410 and AZ-2436 refusal rows | refused, same text |
| a round whose `when` holds and that has no count entry | refused as at HEAD |

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the short-list rows for 3 kinds x 2 bit forms x `times`/`repeat` | the TypeScript hex |
| 2 | pack the U11 rows | refused as before |
| 3 | pack the holding round with no entry | refused as at HEAD |
| 4 | C#: pack the same rows | the TypeScript hex (parity pin) |

**Expected outcome**: as above. A 54 880-row Python grid (review23) changed no bytes and refused no new row; 344 rows newly pack and none has a holding round without a count entry. Tests: Python `test_no_value_count_nested.py` (`test_az2437_ac1_a_short_count_list_whose_missing_round_is_clear_packs`, `test_az2437_ac3_a_holding_round_with_no_count_entry_is_refused_as_at_head`) and the AZ-2410/AZ-2436 tests (AC-2); C# `NoValueCountNestedTests.Ac3_Pack_CountListShorterThanTheRoundsWhereTheMissingRoundIsClear_PacksAsTypeScript`. Rust refuses those per-name lists by its own rules (U18 for `times`, U13 for `repeat`) and packs the same hex from groups. Open (review23 Low 1): a value given for a `bits`, `packed` or `sized` whose count no field wrote raises `RuntimeError` (`3: count 2 is missing`) in Python where TypeScript raises `RangeError` (`v: count c was not written`); pre-existing, AZ-2437 moves one more row (`times {n:2, mode:[0,0], c:[], v:[None, V]}`) onto that path; no wire change.
**Max execution time**: 1s

## Loop 23 loop-level acceptance criteria mapped to scenarios

| Loop-level criterion | Scenario |
|----------------------|----------|
| U19 C++ refuses a `when` `eq` id outside 0..32 767 (F36) | FT-X-75 |
| G2 the C++ empty-body rule is pinned without `eq(-1, ...)` | FT-X-76 |
| U20 C++ `packed` bias -1 traced; README exception | FT-X-77 |
| U22 Rust refuses `repeat` values it dropped (F37); G5, G6 review fixes | FT-X-78 |
| U23 TypeScript refuses a bigint count above 2^53 in the U11 shape | FT-X-79 |
| G1 Python and Rust raised `maxSlots` unpack | FT-X-80, [resource-limit-tests.md](resource-limit-tests.md) |
| G3 U11 in six nested positions | FT-X-81 |
| AZ-2437 Python short count list in a round | FT-X-82 |
| L1 bytes of rows accepted at `b8b2809` unchanged; L4 every new refusal names the field | FT-X-75 to FT-X-82 (HEAD-hex pins in each) |
| L2 package suites green, 65 hostile cases in six loaders; L3 arm budget | FT-X-75, FT-X-78, FT-X-79 (suite counts in the header) |
| U18 B Rust `when` inside a `times` (README exception), U21 A which rule fires first (fixture README) | no scenario (text only) |
