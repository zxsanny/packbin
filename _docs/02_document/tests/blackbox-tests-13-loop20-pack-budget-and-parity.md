# Blackbox Tests 13: Loop 20 pack output budget and parity (FT-X-38 to FT-X-52)

Part of the blackbox set; the index is [blackbox-tests.md](blackbox-tests.md). Loop 20 (`pack-output-budget-and-parity`, AZ-2354 to AZ-2367) gave `pack` one output budget (`maxBytes`), charged `maxSlots` on pack, capped a `repeat` list, and aligned the split-form and combined-`flags` count rules across the six packages. The exact bytes, hex and messages below come from `_docs/03_implementation/reference_loop20_budget.md` (TypeScript is the reference, 28 AZ-2354 rows and 10 AZ-2355 rows) and were checked against the test files by grep. Test names are the real ones; hostile ids are in `fixtures/hostile/cases.txt` (40 cases after this loop, see FT-X-01 and FT-X-10 in [blackbox-tests-07-hostile-case-file.md](blackbox-tests-07-hostile-case-file.md)). Reviewed-and-fixed rows (review A1, A2, A4, A8, B1, B3, C1, C2, C3) are regression scenarios inside the scenario of the spec they changed; the matrix lists them as `Review20 <id>` rows.

**Per-package error type** (the outcome and the numbers are equal; the type and the way a member is quoted differ): TypeScript `RangeError`, Python `ValueError`, Java `IllegalArgumentException`, C# `ArgumentException` (members quoted: `'S'`), Rust `PackError`, C++ `BadValue`. A package whose message differs in a way the tests pin is named in the scenario.

**Packages that skip a row, and why** (one place for all scenarios): **C++** has no output budget, no slot budget and no repeat cap (pack writes into a caller buffer and its rounds live in a fixed `Array` of at most 65 535 items), so AZ-2354 and AZ-2355 have no C++ row; **Rust** has no `times` or `repeat` inside a list or dict element (construction refuses it), so every row that needs a list element is skipped in Rust (reference AZ-2354 rows 2, 3, 22, 23 and AZ-2355 row 10); C# AZ-2358, Java AZ-2361, Python AZ-2362 and TypeScript AZ-2363 are single-package specs.

Package suites after the fix pass (worker runs, review20 and batch 04): C# 1118 (net10.0 and netstandard2.0), Rust 569, Python 846, TypeScript 765 (758 plus the 7 hostile `pack` loader rows), Java `PackbinTest` 1952 checks, C++ gcc:16 and host green, arm embedded stage 0 failed.

### FT-X-38: A lone string under a capped `times` is refused by the byte budget in under a second

**Summary**: `u32 n; times(n){ utf8 s }` with `n` = 65 535 and one 65 535-character string is refused naming `s` at the round whose append would pass `maxBytes` (16 777 216), with no bytes, in under 1 s and under 256 MB; HEAD built a 4.29 GB packet or failed with no member (loop 20, AZ-2354, owner decision 1).
**Traces to**: AZ-2354 AC-1
**Category**: Errors

**Preconditions**:
- TypeScript, Python, Java, C# and Rust as built in loop 20; C++ skipped (caller buffer, fixed `Array`)

**Input data**: `u32 n; times(count n){ utf8 s }`; row `{n: 65535, s: "a" x 65535}` at the default limits (the count passes `maxRounds`; each round is 2 + 65 535 = 65 537 bytes)

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the row in each of the five packages | an error `s: the packet would be 16777477 bytes, above the limit of 16777216 bytes` (C#: `'S': ...`); no bytes. Written before the refusal: 5 + 255 x 65 537 = 16 711 940 bytes; the 256th `utf8` append is the one refused (reference row 1) |
| 2 | measure the call | TypeScript 8 to 14 ms, 135 to 145 MB peak RSS (node + import alone 88 MB); Python 4 ms, 42.8 MB; Java 47 ms, 99.5 MB (96 MB heap child JVM); C# 12 ms pack, 88 MB; Rust 4 ms, 35.5 MB. HEAD: TypeScript `RangeError: Invalid array length` with no member, 1.55 s, 1 679 MB; Python 7.3 GB; C# `OverflowException`, 1.26 s, 2 214 MB; Java OOM at 1 GB heap; Rust 2.19 s, 5.5 GB |
| 3 | replay `pack_lone_utf8_under_times_over_budget` (hostile `pack` stage) | `pack_error` in five packages; C++ skipped with its reason |

**Expected outcome**: step 1 is an error naming `s` in five packages, under 1 s, no bytes. The memory bound is asserted differently: TypeScript and Python run a child process and assert peak RSS under 256 MiB; Java runs a child JVM with a small heap (`LoneUtf8Budget.expectRefusedInASmallHeap`); C# asserts under 256 MB of managed allocation on the pack thread (the 255 rounds of text, about 17 MB; RSS 88 MB measured by the worker); Rust asserts time only (35.5 MB measured by the worker with `/usr/bin/time -l`). Tests: TypeScript `pack-output-budget.test.ts` ("AC-1 a lone string under a capped times is refused naming it, in under 1 s and 256 MB") with `support/lone-utf8-budget.ts`; Python `test_pack_output_budget.py::test_ac1_row1_a_lone_utf8_under_a_capped_times_is_refused_naming_the_member`, `test_ac1_row1_pack_takes_under_a_second_and_under_256_mb`; Java `PackBudgetTest.row1LoneUtf8UnderACappedTimes`; C# `PackOutputBudgetTests.Ac1_Pack_LoneUtf8UnderACappedTimes_IsRefusedNamingTheMember` (typed and dictionary rows) and `..._IsRefusedFastAndWithoutGrowingTheBufferPastTheBudget`; Rust `pack_output_budget_tests.rs::ac1_row1_a_lone_utf8_under_a_capped_times_is_refused_at_once_naming_the_member`. Upgrade note: a row above 16 MiB that packed before is refused after the upgrade; `maxBytes` raises the budget.
**Max execution time**: 1s per package (the child-process variants 30s)

### FT-X-39: An element that holds a `times` is refused at the default budget and packs when the budget is raised

**Summary**: 40 list items of `{n: 65535, k: 5}` over a `u64` body (about 21 MB, 2 621 400 slots, under `maxSlots`) are refused naming `k` at the default `maxBytes`; with `maxBytes` 33 554 432 the same row packs and unpacks to 40 items (loop 20, AZ-2354).
**Traces to**: AZ-2354 AC-2
**Category**: Errors

**Preconditions**:
- TypeScript, Python, Java and C# (dictionary and typed rows); Rust and C++ skipped (see the header)

**Input data**: `list items of group { u32 n; times(n){ u64 k } }`; 40 x `{n: 65535, k: 5}`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack at the default limits | `k: the packet would be 16777223 bytes, above the limit of 16777216 bytes` (C#: `'K'`); the refusal is in item 32 at round 15 (3 + 32 x 524 284 + 4 + 15 x 8 = 16 777 215 bytes written); no bytes (reference row 2) |
| 2 | pack with `maxBytes` 33 554 432; unpack the result | 20 971 363 bytes, first 16 `012800ffff0000050000000000000005`, last 16 `05000000000000000500000000000000`; unpack returns 40 items, each `n` 65 535, each `k` a list of 65 535 `5` (reference row 3) |
| 3 | replay `pack_element_times_over_budget` | `pack_error` in four packages; Rust and C++ skipped with their reasons |

**Expected outcome**: step 1 is an error naming `k` in four packages; step 2 packs and round-trips. Tests: TypeScript `pack-output-budget.test.ts` ("AC-2 an element that holds a times is refused at the default budget naming its member", "AC-2 with maxBytes raised to 32 MiB the same row packs and unpacks to it"); Python `test_ac2_row2_an_element_that_holds_a_times_is_refused_at_the_default_budget`, `test_ac2_row3_a_raised_budget_packs_the_element_row`; Java `PackBudgetTest.rows2And3AnElementThatHoldsATimes`; C# `PackOutputBudgetTests.Ac2_Pack_ElementsThatEachHoldATimes_AreRefusedAtTheDefaultAndPackWithARaisedBudget`, `Ac2_Pack_ElementsOfTypedRows_AreRefusedAtTheDefault`. Rust: no equivalent (construction refuses a `times` in a list element, reason recorded in the hostile loader `PACK_NOT_RUN`).
**Max execution time**: 10s (Python 7.1 s, kept at spec size)

### FT-X-40: The byte boundary is exact and the budget names the member being written

**Summary**: A packet of exactly `maxBytes` (type byte included) packs; one byte more is refused before the append, naming the member, with no bytes; every append kind names its own member (loop 20, AZ-2354; decision D2: the type byte counts).
**Traces to**: AZ-2354 AC-3
**Category**: Bytes

**Preconditions**:
- TypeScript, Python, Java, C# and Rust; C++ skipped

**Input data**: reference rows 4 to 13 (hex is the whole packet):

| Row | Scheme and limit | Row value | Expected |
|-----|------------------|-----------|----------|
| 4 | `utf8 s`, `maxBytes` 64 | `s` = 61 x `a` | packs 64 bytes: `013d00` + `61` x 61 |
| 5 | same | `s` = 62 x `a` | `s: the packet would be 65 bytes, above the limit of 64 bytes` |
| 6 | `repeat{ u8 k }`, 64 | `k` = 63 x 7 | packs 64 bytes: `01` + `07` x 63 |
| 7 | same | `k` = 64 x 7 | `k: the packet would be 65 bytes, above the limit of 64 bytes` (at the 64th round) |
| 8 | no fields, `maxBytes` 1 | `{}` | packs `01` (the type byte counts) |
| 9 | `u8 a`, 1 | `a` = 1 | `a: the packet would be 2 bytes, above the limit of 1 bytes` |
| 10 | split byte `m` + bit { `u8 c` }, 1 | `c` = 1 | `m: the packet would be 2 bytes, above the limit of 1 bytes` (Java: `flag_byte: ...`) |
| 11 | `flags { u8 c }`, 1 | `c` = 1 | `c: the packet would be 2 bytes, ...` (the first member the combined byte declares) |
| 12 | `u8 n; flags { times(n){ u8 k } }`, 2 | `n` = 1, `k` = 3 | `k: the packet would be 3 bytes, above the limit of 2 bytes` (named through the `times`) |
| 13 | `list xs of u8`, 2 | `xs` = `[]` | `xs: the packet would be 3 bytes, above the limit of 2 bytes` (the count prefix) |

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack each row in the five packages | the outcome of the column above; refused rows return no bytes |
| 2 | pack a dict key, a `bytes`, a `sized`, a `bits`, a `packed` and a `u2` over the budget | each names its own member (a `u2` its first slot, a dict key the dict) |

**Expected outcome**: rows 4, 6 and 8 pack; rows 5, 7, 9 to 13 are refused, with the member and the numbers above. Tests: TypeScript `pack-output-budget.test.ts` ("AC-3 a packet of exactly maxBytes packs; one byte more is refused", "AC-3 the boundary holds round by round: 63 rounds pack in 64 bytes, a 64th is refused", "AC-3 the type byte counts, and a flag byte or a list length is named by its member"); Python `test_ac3_row4_*` to `test_ac3_row13_*`; Java `PackBudgetTest.rows4To13TheBoundaryIsExact`; C# `PackOutputBudgetTests.Ac3_*` (including `Ac3_Pack_DictCountPrefixAndKeyOverTheBudget_NameTheDict`, `Ac3_Pack_BytesSizedBitsAndPackedOverTheBudget_NameTheField`); Rust `ac3_rows4_5_*`, `ac3_rows6_7_*`, `ac3_rows8_9_the_type_byte_counts`, `ac3_rows10_11_12_*`, `ac3_row13_*`, `ac3_a_u2_is_named_by_its_first_slot`. Naming differences: Rust, Python, C# and Java have no flag-byte name in their API and name a split byte `flag_byte` or by the first member its bits declare (parent ruling, batch 02).
**Max execution time**: 1s

### FT-X-41: Slots are charged on pack per round, with the width unpack charges

**Summary**: Pack charges `maxSlots` as each round starts, before any byte of that round, with the same width unpack charges; a 65-name round at count 65 535 (4 259 775 slots, above the default) is refused naming the first member and packs with a raised limit (figures below are loop 20, default 4 194 304; since loop 22 the default is 1 048 576 and the row is refused at round 16 132 with `m0: the rounds would hold 1048580 slots, above the limit of 1048576 slots`, see FT-X-71); slots are checked before the bytes of a round (loop 20, AZ-2354).
**Traces to**: AZ-2354 AC-4
**Category**: Errors

**Preconditions**:
- TypeScript, Python, Java, C# and Rust; C++ skipped; Rust's width counts the group, `flags` and flag-byte names as its own unpack does (loop 21 parity item)

**Input data**: `u32 n; times(n){ u8 m0 ... u8 m64 }`, row `n` = 65 535 and every `m` = 1; reference rows 14 to 25

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack at the default limits of loop 20, 4 194 304 (row 14) | `m0: the rounds would hold 4194320 slots, above the limit of 4194304 slots` at round 64 527 (64 527 x 65 = 4 194 255 charged; 4 194 260 bytes written) |
| 2 | pack with `maxSlots` 4 259 775 (still valid after loop 22: it is above the new default, so the row is raised explicitly); unpack with the same scheme (row 15) | 4 259 780 bytes, first 16 `01ffff00000101010101010101010101`, last 16 `01` x 16; unpack ok, every `m` a list of 65 535 |
| 3 | unpack that packet with the default scheme (row 16) | TypeScript `{ok: false, field: "m0", needed: 0, left: 65520}`; Python `ShortPacket(field='1', needed=0, left=66040)` (Python unpack surcharge, review B3) |
| 4 | order rows 17 to 21: `u32 n; times(n){ u8 k }` at `maxSlots` 3 and `maxBytes` 8 | `{n: 3, k: 7}` packs `0103000000070707`; `{n: 10}` with `maxBytes` 8: `k: the rounds would hold 4 slots, above the limit of 3 slots`; with `maxBytes` 7: `k: the packet would be 8 bytes, above the limit of 7 bytes`; with `maxRounds` 5: `k: the times count is 10, above the limit of 5 rounds`; with `maxBytes` 4: `n: the packet would be 5 bytes, above the limit of 4 bytes` |
| 5 | scope and width rows 22 to 25 | two elements `{n: 3, k: 1}`, `{n: 3, k: 2}` at `maxSlots` 5: `k: the rounds would hold 6 slots, above the limit of 5 slots`; `{n: 3}`, `{n: 2}` packs `01020003010101020202`; `repeat{ u8 a; group g{ u8 b } }` width is 2 (`g` not counted): 2 rounds pack `0101030204`, 3 rounds `a: the rounds would hold 6 slots, above the limit of 5 slots` |
| 6 | replay `pack_slots_over_limit` | `pack_error` in five packages, same text, width 65 in all five; C++ skipped |

**Expected outcome**: the refused rows give the messages above, the accepted rows the hex above; when one round would pass both limits the slot error is raised. Tests: TypeScript `pack-output-budget.test.ts` ("AC-4 a 65-member round counted 65 535 times is refused naming the member", "AC-4 with maxSlots raised to 4 259 775 it packs and unpacks; the default unpack refuses that packet", "slots are charged before the round's bytes and across the whole call", "a round charges the width unpack charges: a non-empty group's own name is not a slot", "the round cap fires before any round, and a count field before the round cap"); Python `test_ac4_row14_*` to `test_ac4_row16_*`, `test_order_row17_*` to `row21_*`, `test_scope_row22_*`, `row23_*`, `test_width_row24_*`, `row25_*`; Java `PackBudgetTest.rows14To16SlotsAreChargedOnPack`, `rows17To21TheOrderOfTheChecks`, `rows22To25ScopeAndWidth`; C# `PackSlotBudgetTests.Ac4_*`, `Order_*`, `Scope_*`, `Width_*`; Rust `ac4_row14_*`, `ac4_rows15_16_*`, `row17_*`, `order_rows18_to_21_*`, `width_a_round_is_charged_what_unpack_charges_and_pack_refuses_where_unpack_would`, `scope_one_slot_counter_is_shared_by_a_repeat_round_and_the_times_inside_it`. Slow: Rust debug AC-4 rows 8 to 18 s (0.8 s in release), Python about 3 to 4 s per row; kept at spec size (review A9, handoff).
**Max execution time**: 20s

### FT-X-42: The limits API carries `maxBytes`; accepted rows keep their bytes

**Summary**: `maxBytes` defaults to 16 777 216 and is carried by each package's limits call; a value below 1 or not an integer is refused like the other limits; a limit left out of a call takes the default; existing call forms compile and every accepted row keeps its bytes (loop 20, AZ-2354, decision D3).
**Traces to**: AZ-2354 AC-5, AZ-2354 AC-6
**Category**: Bytes

**Preconditions**:
- The five growable packages; call forms: TypeScript `withLimits({ maxBytes })`, Python `with_limits(max_bytes=...)`, C# optional `maxBytes`, Rust `with_max_bytes`, Java `withMaxBytes`

**Input data**: `u8 a`; `new Scheme(1, [], { maxBytes: v })` with `v` in 0, -1, 1.5, NaN, 2^53 (rows 26 to 28); the golden, route and ring fixtures

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | read `maxBytes` of a default scheme; of `withLimits({ maxRounds: 9 })`; of `withLimits({ maxBytes: 64 }).withLimits({ maxSlots: 9 })` | 16 777 216 each (a member left out of a call takes the default, as `maxRounds`/`maxSlots` did since loop 19) |
| 2 | build with each invalid `maxBytes` | TypeScript `maxBytes: expected a positive integer up to 9007199254740991` from the constructor and `withLimits`; the other packages refuse 0, negative and fractional values with their own validator text (Python and C# have no 2^53 bound) |
| 3 | `u32 n; times(n){ u8 k }` with `.withLimits({ maxRounds: 3, maxSlots: 3 })`, `{n: 3, k: 7}`; run the golden, route and ring fixtures | `0103000000070707`; every accepted row of the suites packs to the hex of loop 19 |

**Expected outcome**: steps 1 and 2 as above; step 3 unchanged bytes. Tests: TypeScript `pack-output-budget.test.ts` ("AC-5 defaults to 16 MiB, and withLimits keeps resetting a member left out", "AC-5 a maxBytes below 1 or not an integer is refused like the other limits", "AC-5 and AC-6 existing limit calls compile and pack the same bytes"); Python `test_ac5_row26_*`, `test_ac5_row27_an_invalid_max_bytes_is_refused_like_the_other_limits` (parametrized), `test_ac5_row28_the_existing_call_forms_still_work`; Java `PackBudgetTest.rows26To28TheLimitsApi` (Java `withLimits(int, long)` resets `maxBytes`, reference row 26); C# `Ac5_Limits_MaxBytesDefaultsAndIsKeptByTheOtherLimitCalls`, `Ac5_Limits_MaxBytesBelowOne_IsRefusedLikeTheOtherLimits`, `Ac5_Limits_MaxBytesIsCheckedBeyondTheIntRange`, `Ac6_Pack_LimitsRaisedByTheExistingCallForms_KeepTheBytes`, `PackSlotBudgetTests.Ac6_Pack_RowsUnderBothLimits_KeepTheirBytes`; Rust `ac5_rows26_28_limits_api`, `ac5_row27_a_zero_max_bytes_is_refused` (and the typed scheme), `ac5_a_typed_scheme_carries_max_bytes`, `ac6_a_when_and_flags_row_under_the_budget_keeps_its_bytes`. AC-6 for all packages is also the unchanged golden, route and ring replay (FT-P-01, FT-C-04). Upgrade note: C# `WithLimits(int, long)` became `(int, long, long)`, source compatible, binary breaking (review A7).
**Max execution time**: 1s

### FT-X-43: Pack refuses a `repeat` list longer than `maxRounds`

**Summary**: A `repeat` whose first over-long list passes `maxRounds` is refused before any round, naming that list's member; `maxRounds` entries pack and round-trip; a raised limit packs a longer list (loop 20, AZ-2355, owner decision 2; HEAD packed 65 537 bytes that its own unpack refuses).
**Traces to**: AZ-2355 AC-1, AZ-2355 AC-2, AZ-2355 AC-3
**Category**: Errors

**Preconditions**:
- TypeScript, Python, Java, C# and Rust; C++ skipped (fixed `Array`); Rust has no `repeat` in a list element (reference row 10)

**Input data**: `repeat{ u8 k }` (reference rows 1 to 10 of the AZ-2355 table)

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack `k` = 65 536 x 7 | `k: the repeat count is 65536, above the limit of 65535 rounds` (C#: `'K'`); no bytes |
| 2 | pack `k` = 65 535 x 7; unpack; repack | 65 536 bytes, first 16 `01070707070707070707070707070707`, last 16 `07` x 16; unpack ok; repack gives the same bytes |
| 3 | pack 70 000 entries with `maxRounds` 70 000 | 70 001 bytes, first 16 `01` + `07` x 15 |
| 4 | `maxRounds` 3: `[1,2,3,4]` and `[1,2,3]`; `repeat{ u8 a; u8 b }` with `a` = 1, `b` = `[1,2,3,4]` | `k: the repeat count is 4, above the limit of 3 rounds`; `01010203`; `b: the repeat count is 4, ...` (the long list, not the first member) |
| 5 | the same cap in `flags`, a split bit, a `when` and a list element, `maxRounds` 3 | the step 4 text for `k` in each place |
| 6 | replay `pack_repeat_over_limit` | `pack_error` in five packages; C++ skipped |

**Expected outcome**: as listed. Tests: TypeScript `pack-repeat-round-cap.test.ts` ("AC-1 maxRounds + 1 entries are refused naming the member", "AC-1 the member named is the one whose list passes the limit", "AC-1 the cap holds in flags, a split bit, a when and a list element", "AC-2 maxRounds entries pack in maxRounds + 1 bytes and round-trip", "AC-3 with maxRounds raised to 70 000, 70 000 entries pack"); Python `test_pack_repeat_round_cap.py::test_ac1_row1_*`, `test_ac2_row2_*`, `test_ac3_row3_*`, `test_row4_*` to `test_row10_*`; Java `RepeatRoundCapTest.rows1To3TheDefaultLimit`, `rows4To6TheMemberNamed`, `rows7To10EveryPlaceARepeatSits`; C# `PackRepeatRoundCapTests.Ac1_*`, `Ac2_*`, `Ac3_*`, `Pack_RepeatWithTwoMembers_NamesTheLongListNotTheFirstMember`, `Pack_RepeatInCombinedFlags_IsRefused`, `Pack_RepeatInASplitFlagBit_IsRefused`, `Pack_RepeatUnderAWhen_IsRefused`, `Pack_RepeatInAListElement_IsRefused`; Rust `pack_repeat_cap_tests.rs::ac1_row1_*`, `ac2_row2_*`, `ac3_row3_*`, `rows4_5_*`, `row6_*`, `rows7_8_9_*`. Not specified (loop 21): C# `repeat` with a lone `byte[]` counts it as rounds with other text (review A6); a `times` count above `int.MaxValue` keeps the older C# text (A5).
**Max execution time**: 2s

### FT-X-44: In the split form, count 0 written after the flag byte: a list is refused, a lone scalar packs zero rounds

**Summary**: A split flag bit whose `times` count is written after the byte and equals 0 is refused naming the member when the row gives a list, and packs zero rounds when it gives a lone scalar or nothing, in all six packages (loop 20, AZ-2356, owner decision 3; Python and Rust were refusing the scalar and are fixed).
**Traces to**: AZ-2356 AC-1, AZ-2356 AC-2
**Category**: Errors

**Preconditions**:
- The six packages as built in loop 20; C++ holds an `Array`, so its scalar case is the row without values

**Input data**: `flag_byte; u8 n; bit 0 { times(count n){ u8 pt } }`; rows `n` = 0 with `pt` = `[5, 6]`; `n` = 0 with `pt` = 5; `n` = 0 with no `pt`; `n` = 2 with `pt` = `[5, 6]` (still refused); `n` = 2, no values (`010002`)

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the list row in each package | an error naming the member: TypeScript `pt: 2 items, times count 0`; Python `1: 2 items, times count is 0` (field id); Java `1: list has 2 entries for a count of 0` (field id); C# message contains `'Pt'`; Rust message contains `'pt'`; C++ `BadValue` on field 1 |
| 2 | pack the lone-scalar row | `010000` in TypeScript, Python, C# and Rust (Python also for `pt` = `[]` and for no `pt`); Java `0100005a00` (scheme with a `heading` field, value 90); C++ `010000` for a scalar-less row |
| 3 | replay `pack_split_count_zero_after_byte_list` and `pack_split_count_zero_after_byte_scalar` | list: `pack_error` in six; scalar: `bytes` `010000` in five, C++ skipped (typed row holds an `Array`) |

**Expected outcome**: step 1 is an error in six packages, step 2 the bytes above. Tests: TypeScript `loop20-parity-pins.test.ts` (group "AZ-2356 a split count of 0 written after the byte": "AC-1 with a list of values is refused naming the member", "AC-2 with a lone scalar packs zero rounds"); Python `test_loop20_parity_pins.py::test_az2356_ac1_*`, `test_az2356_ac2_*`, `test_az2356_a_split_count_above_zero_after_the_byte_with_values_is_still_refused`, `test_az2356_a_split_count_above_zero_after_the_byte_with_no_values_leaves_the_bit_clear`; Java `ParityPinsTest.az2356CountZeroAfterTheByte`; C# `FlagsSkippedCountTests.Ac1_Pack_SplitCountZeroAfterTheByteWithAList_IsRefusedNamingTheMember`, `Ac2_Pack_SplitCountZeroAfterTheByteWithALoneScalar_PacksZeroRounds`; Rust `loop20_parity_pins_tests.rs::az2356_ac1_*`, `az2356_ac2_*`, `review20_a4_the_split_form_keeps_count_zero_after_the_byte`; C++ `times_count_zero_host_tests.cpp::az2356_split_count_zero_after_the_byte`. C++ note: its AZ-2356 pin and the hostile list case are refused by the late rule, not the count-0 rule (review C4, loop 21).
**Max execution time**: 1s

### FT-X-45: A combined `flags` `times` whose count is skipped, with values given, is refused naming the member

**Summary**: In a combined `flags`, a `times` whose count is not written (its bit is clear) and a row that gives values for its body (a list, or a lone scalar) is refused naming the first held member, with the same text in all six packages; no values (or `[]`) still packs `0100` (loop 20, AZ-2360, owner decision 9; review A3 and A4).
**Traces to**: AZ-2360 AC-1, AZ-2360 AC-2
**Category**: Errors

**Preconditions**:
- The six packages as built in loop 20; Python's older text named `times 1` and changed to name `pt`

**Input data**: `flags { u8 n; times(count n){ u8 pt } }`; rows `{pt: [5, 6]}`, `{pt: 5}`, `{}`, `{pt: []}`, `{n: 2, pt: [5, 6]}`; a `times` under a taken `when` inside `flags`; Rust review A4 shape `m = 0` with a stale `n: 0` and `pt: 5`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack `{pt: [5, 6]}` and `{pt: 5}` in each package | `pt: a value is given, but the count of its times is not written, so its bit is clear; write the count before the times` (C#: `'Pt': ...`); C++ `BadValue` for the two-value row (field 1); no bytes |
| 2 | pack `{}`, `{pt: []}` and `{n: 2, pt: [5, 6]}` | `0100`, `0100`, `0103020506` |
| 3 | pack the shape under a taken `when` inside `flags`; a false `when` | refused with the same text; a false `when` packs `010000` |
| 4 | Rust review A4: skipped count with a stale `n: 0`, `n: 3` or no `n`, and a value | `pt: <text above>` in all four rows; with no value and `n: 0` it packs `010000` |
| 5 | replay `pack_flags_skipped_count_with_values` | `pack_error` in six packages |

**Expected outcome**: step 1 is an error in six, steps 2 and 3 the hex above, step 4 the Rust parity with TypeScript and C# (HEAD packed `[1, 0, 0]` silently, `zero_given` leaked from the split form). Tests: TypeScript `loop20-parity-pins.test.ts` (group "AZ-2360 a combined flags times whose count is skipped": "AC-1 with values is refused naming the member", "AC-1 a lone scalar is a value too", "AC-2 with no values, or an empty list, the bit packs clear as before", "a times under a when inside combined flags is refused the same way; a false when stays silent"), `split-form-loud-pack.test.ts`; Python `test_loop20_parity_pins.py::test_az2360_ac1_combined_flags_skipped_count_with_values_is_refused_naming_the_member`, `test_az2360_ac2_*`; Java `ParityPinsTest.az2360SkippedCountWithValuesIsLoud`; C# `FlagsSkippedCountTests.Ac1_Pack_SkippedCountWithAListOfValues_IsRefusedNamingTheMember`, `Ac1_Pack_SkippedCountWithALoneScalar_IsRefusedToo`, `Ac2_Pack_SkippedCountWithNoValuesOrAnEmptyList_PacksTheBitClear`, `Ac1_Pack_TimesUnderAWhenInsideFlags_IsRefusedAndAFalseWhenStaysSilent`; Rust `loop20_parity_pins_tests.rs::az2360_ac1_*`, `az2360_ac2_*`, `review20_a4_a_skipped_count_with_a_stale_zero_is_refused_under_flags_naming_the_member`, `review20_a4_a_skipped_count_with_a_stale_zero_and_no_value_packs_the_bit_clear`; C++ `split_form_loud_host_tests.cpp::flags_skipped_count_with_values`, `ac2_count_never_written`. Upgrade note (review A3, accepted): a C# typed non-nullable member always counts as given, so a typed row that packed `0100` is now refused.
**Max execution time**: 1s

### FT-X-46: Python empty `repeat` under `flags` and TypeScript `times` in a `when` in a split bit

**Summary**: Python packs a `repeat` with `[]` as a `flags` member without a bare `IndexError`, matching the TypeScript outcome; a required leaf with an empty list raises a named error (review B1); TypeScript refuses a `times` inside a `when` inside a split bit when its count is never written (already refused since loop 19 review B2; pinned in loop 20) (AZ-2362, AZ-2363).
**Traces to**: AZ-2362 AC-1, AZ-2363 AC-1
**Category**: Errors

**Preconditions**:
- Python and TypeScript as built in loop 20

**Input data**: Python `u8 mode; flags { repeat { u8 k } }` with `k` = `[]`, `[5]`, absent; `u8 mode; flags { u8 h; repeat { u8 k } }`; `repeat { u8 w; flags { u8 v } }` with `w` = `[1, 2]`, `v` = `[]`; the review B1 shapes `w` = `[]`, `v` = `[3]` and `repeat { u8 a; u8 b }` with one empty list; TypeScript `u8 mode; when(mode == 9){ u8 n }; flag_byte; bit { when(mode == 1){ times(count n){ u8 pt } } }`, `mode` 1, `pt` `[5, 6]`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | Python: pack the three `k` rows with `mode` 1 | `010100`, `01010105`, `010100` |
| 2 | Python: the `h` shape with `k` `[]`, `[5]` and `h` 3 | `01010103`, `0101030305` |
| 3 | Python: `w` = `[1, 2]`, `v` = `[]` | `0101000200` (as TypeScript) |
| 4 | Python review B1: `w` = `[]` with `v` = `[3]`; `a` = `[1, 2]` with `b` = `[]`; both lists empty | `KeyError 'missing field w'` (TypeScript `missing w`); `KeyError 'missing field b'`; `01` (no rounds) |
| 5 | TypeScript: pack the G3 row; the same with the `when` condition written after the byte | `pt: a value is given, but the condition or count of its when or times is not written before the flag byte, so its bit is clear; write that field before the flag byte`; in the second layout, with no values `010001`, with a false condition (`mode` 2) `010002` |

**Expected outcome**: as listed; no bare `IndexError` in Python. Tests: Python `test_loop20_parity_pins.py::test_az2362_a_repeat_with_an_empty_list_as_a_flags_member_leaves_the_bit_clear`, `test_az2362_a_repeat_next_to_a_value_in_flags_packs_the_value_alone_when_the_list_is_empty`, `test_az2362_a_flags_member_of_a_repeat_round_with_an_empty_list_is_absent_in_every_round`, `test_review_b1_a_required_leaf_with_an_empty_list_beside_a_flags_member_is_missing_not_an_index_error`, `test_review_b1_a_repeat_with_one_empty_required_list_beside_a_longer_one_names_the_member`, `test_review_b1_a_repeat_with_every_list_empty_still_packs_no_rounds`; TypeScript `loop20-parity-pins.test.ts` (group "AZ-2363 a times inside a when inside a split bit, its count never written": "AC-1 with values is refused naming the member", "AC-1 the same with the when condition written after the byte"). Not specified (loop 21): TypeScript packs a short list in an optional flags position (`{w:[1,2], v:[5]}` gives `010101050200`) where Python refuses it.
**Max execution time**: 1s

### FT-X-47: C++ refuses rounds whose count sits behind a clear `when`, and every late member of a bit

**Summary**: C++ pack returns `BadValue` naming the member for a `times` (and, after review C2, a `bits`, `packed` or `sized`) whose count is set in the row but sits behind a clear `when`, and for any later `when` or `times` of a split bit whose source is written after the byte; the five other packages already refused. Accepted rows keep their bytes; the arm stage stays inside the budgets (loop 20, AZ-2357, AZ-2364; review C1, C2, C3).
**Traces to**: AZ-2357 AC-1, AZ-2357 AC-2, AZ-2364 AC-1, AZ-2364 AC-2
**Category**: Errors

**Preconditions**:
- C++ core as built in loop 20 (gcc:16 `make test`; the arm embedded stage `docker compose -f docker-compose.test.yml run --rm cpp-embedded`)

**Input data**: the loop 19 assessment U4 scheme (`u8 mode; when(mode == 1){ u8 c }; flag_byte; bit { times(count c){ u8 pt } }; bit { u16 heading }`); `bit(group(when(mode == 1) a, when(mode == 2) b))` with mode 2 and `b` given; nested and C2 shapes below

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the U4 row (`mode` 0, count 1 or 2, rounds given) | `BadValue` naming the `times` (HEAD packed `010003055a00`); count 0 behind a clear `when`: `0100025a00` (packs as before) |
| 2 | nested `when`s (outer reads `mode`, inner `speed`), one false; both true; no flag byte (plain `times`) | refused; both true `0101010103055a00`; plain `times` behind a clear `when` refused, behind a holding `when` `01010105` |
| 3 | two late `when`s, mode 2, `b` given; first late `when` with `a` given; no body given | `BadValue` naming `b` (HEAD `01010209`); `BadValue` for `a`; `010002` |
| 4 | review C2: `bits`, `packed`, `sized` count behind a clear `when` | `BadValue` for all three (`010005` packed before); true `when`: `01010305`, `01010339`, `010103756176`; count and member in the same `when`: `01010305` / `0100` |
| 5 | review C1: a late `when` or `times` nested in a `when` or `flags` inside the bit; review C3: a `times` in the same `when` that holds its count | refused; packs as before (no 255-entry limit) |
| 6 | link limits | a count more than 255 entries after its holding `when` and a link over 255 entries between late `when`s are `SchemeInvalid` at construction (limit 255 builds, 256 is refused) |
| 7 | arm embedded stage, Cortex-M4F | flash 8160 of 8192 B (margin 32 B, was 128 B before loop 20), stack 448 of 512 B unchanged; stage 0 failed (batch 01: M3 QEMU 241 of 241, s390x PASS, M0+ PASS) |

**Expected outcome**: steps 1 to 6 as listed; step 7 within budget. One accepted row changes: a plain `times` (no flag byte), count 0, no rounds, count behind a clear `when` packed `0100` and is now refused (upgrade note). Tests: C++ `split_form_loud_host_tests.cpp::count_set_behind_a_clear_when`; `late_source_host_tests.cpp::az2364_every_late_when_of_a_bit_is_refused`, `az2364_link_over_255_is_refused_at_construction`, `az2357_hold_over_255_is_refused_at_construction`; `held_count_nested_late_host_tests.cpp::c2_count_behind_a_clear_when_is_refused`, `c2_count_behind_a_true_when_is_unchanged`, `c2_count_and_member_in_the_same_when_pack`, `c2_count_behind_a_nested_clear_when_is_refused`, `c1_late_when_in_a_when_is_refused`, `c1_late_when_in_flags_is_refused`, `c1_late_times_in_a_when_is_refused`, `c3_times_inside_the_holding_when_has_no_limit`; budgets by FT-E-05 in the embedded stage. The flash margin is exhausted: any further edit to `cpp/src/core` or `cpp/include` needs a saving first. Not specified (loop 21): a count behind a clear `when` for `bits`/`packed`/`sized` is not probed in C#, Python, Java and Rust; Python packs the U4 row with count 1 and no rounds (`0100025a00`) where C++ refuses; a direct late `when` in a bit body is refused even when another non-late child sets the bit (TypeScript packs it).
**Max execution time**: 60s host, about 180s arm stage

### FT-X-48: C# whole-number floats and enum values in slots are pinned

**Summary**: C# refuses `Eq(u8, 5.0)` at construction and a whole float in a `u2`, `bits` or `packed` slot at pack, in typed and dictionary rows, while an `f32`/`f64` field still packs `5.0`; plain integer fields (u8 to i64) still accept `5.0` by owner decision (AZ-2373, loop 21). The enum rule per package is pinned: Python (`IntEnum`) and TypeScript (numeric enum) pack the integer, C#, Java and Rust refuse (loop 20, AZ-2358, AZ-2359).
**Traces to**: AZ-2358 AC-1, AZ-2358 AC-2, AZ-2359 AC-1
**Category**: Errors

**Preconditions**:
- C#, and the enum rule in TypeScript, Python, Java, Rust (the order below)

**Input data**: `Eq(u8, 5.0)` and the whole floats `5.0f`, `5m`, `255.0`, `-128.0` (i8), `65 535.0` (u16); `u2` slot `3.0`, `0.0`, `2.0f`, `3m`; `bits` 1.0; `packed` `1.0`, `1m`, `3.0`; `f64` field 5.0 and `f32` 5.0; an integer enum member in a `u8` slot (`Level.High` = 200), a `u2` slot, an `f64` field

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | C#: build a scheme with each whole-float `Eq` value | `ArgumentException` starting `when 1 tests <kind> field 0 ('` and containing `not a float, double or decimal` |
| 2 | C#: pack each whole float in a `u2`, `bits` or `packed` slot | `ArgumentException` naming the member |
| 3 | C#: pack `D` = 5.0 (`f64`) and `S` = 5.0 (`f32`) | `01` + `0000000000001440` + `0000a040` |
| 4 | the enum member `High` (200) in a `u8` slot | TypeScript `01c8` (a numeric enum is a number; a string enum is refused: `level: expected a number for u8, got string`); Python `IntEnum` `01c8` (also `01c8000000` in a `u32` slot), a plain `Enum`: `TypeError: 0: expected int, got Plain`; C#: `A: expected a number for u8, got Level`, `S: expected 2-bit int`, `D: expected a number for f64, got Wide`, the enum's number `(byte)Level.High` packs `01c8`; Java `0: expected int, got Level` (u8), `0: expected 2-bit int` (u2), its ordinal `0101`; Rust only takes an integer `Value` (`01c8`; a text or `U16` value is `PackError::Type("int")`), a typed row packs the converted integer |

**Expected outcome**: steps 1 and 2 are errors, step 3 packs; step 4 as listed (the Python, TypeScript pack-the-integer and C#, Java, Rust refuse split follows the probe). Tests: C# `EqValueConstructionTests.Construct_EqWholeFloatForAnIntegerSource_IsRefusedNamingTheWhenAndTheMember` and `StrictSlotTests.Ac2_Pack_WholeFloatInASlot_ThrowsNamingTheMember`, `Ac2_Pack_WholeFloatInAFloatField_StillPacks`, `EnumSlotValuesTests.Pack_ByteEnumInAU8Slot_IsRefusedNamingTheField`, `Pack_IntEnumInAU2Slot_IsRefusedNamingTheField`, `Pack_EnumInAFloatField_IsRefusedNamingTheField`, `Pack_TheEnumsNumber_PacksAsAnInteger`; TypeScript `loop20-parity-pins.test.ts` (group "AZ-2359 a numeric enum member in a u8 slot": "AC-1 packs the integer's byte: a TypeScript numeric enum is a plain number at runtime", "AC-1 a string enum member is not a number and is refused naming the field"); Python `test_az2359_ac1_an_int_enum_member_packs_as_its_integer`, `..._packs_in_a_wider_slot_too`, `..._a_plain_enum_member_is_not_a_number_and_is_refused_naming_the_field`; Java `ParityPinsTest.az2359AnEnumIsNotANumber`; Rust `az2359_ac1_a_u8_slot_takes_only_an_integer_value`, `az2359_ac1_the_typed_scheme_packs_the_converted_integer`. Gap: AZ-2358 AC-2 says typed and dictionary rows, and `StrictSlotTests` builds dictionary rows only; no test packs a whole float through a typed row. AZ-2373 (C# exact integer types from unpack, whole floats refused for u8 to i64) is the loop 21 fix and has no test yet. Upgrade note: `Eq(u8, 5.0)` that built before is refused.
**Max execution time**: 1s

### FT-X-49: Java refuses fractions in slots and u64 counts above the int range; `ByteSink` growth cannot overflow

**Summary**: Java refuses `BigDecimal` 1.5 in a `u2` slot, a `bits` item and a `packed` item (and values that were silently cut: `Long` 2^32 + 1, `BigInteger` 2^32 + 1, `BigDecimal` 0.1), while a whole `BigDecimal` packs; refuses a u64 count above the int range in `sized` and `bits`; and `ByteSink` growth stops at the array limit with a typed refusal (loop 20, AZ-2361; findings G1, F29, F30).
**Traces to**: AZ-2361 AC-1, AZ-2361 AC-2, AZ-2361 AC-3
**Category**: Errors

**Preconditions**:
- Java as built in loop 20

**Input data**: `u2` slot, `bits` and `packed` items holding `BigDecimal` 1.5, 0.1, 1, 1.0; `u64 n; sized(n) b` and `u64 n; bits(n) b` with `n` = 4 294 967 299 and 3 items; `n` = 3; `ByteSink.grown(current, needed, cap)` near the array limit

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the fractions and cut values | `0: expected 2-bit int` (u2), `1: expected 0 or 1` (bits), `1: expected 0..3` (packed) |
| 2 | pack `BigDecimal` 1 and 1.0 | `0101` (u2), `010101` (bits and packed) |
| 3 | pack `n` = 4 294 967 299 with 3 bytes or 3 items | `1: count 4294967299 is above the limit of 2147483647 items`, no 12-byte packet |
| 4 | pack `n` = 3 | `010300000000000000000000` (sized), `01030000000000000005` (bits) |
| 5 | grow a sink | `grown(2^29, 2^29 + 1, max)` is 2^30; `grown(2^30, 2^30 + 1, max)` is the array limit; one past the limit and a 5 000 000 000 append return -1 (refused); budget 100 caps 64 to 100; 32 doubles to 64 |

**Expected outcome**: as listed, no overflow. Tests: Java `CountsFractionsSinkTest.ac1AFractionIsRefused`, `ac2AU64CountAboveIntRange`, `ac3TheSinkGrowsWithoutOverflow`, and `PackBudgetTest.growthStaysInsideTheArrayLimit`. Upgrade note: the exact conversion also refuses values that were cut silently before.
**Max execution time**: 1s

### FT-X-50: C# typed unpack of a round returns an error result; a scalar-element collection in a round is refused at construction

**Summary**: Typed `Unpack` of `03 01 02` for `Repeat(0, U8 V)` (also a `Times` and a `Repeat(Flags(U8 V))` round) returns a `ShortPacket` naming `V`, no exception; a `List<int>` or `List<long>` member inside a `Repeat` or `Times` round is refused at construction naming the member, while `List<List<object?>>`, `List<object?>`, `IList`, `IList<object?>`, `object[]` and `object` members build and bind as before (loop 20, AZ-2366; AC-2 corrected by review A1; review A2).
**Traces to**: AZ-2366 AC-1, AZ-2366 AC-2
**Category**: Errors

**Preconditions**:
- C# as built in loop 20, both target frameworks

**Input data**: `Repeat(0, U8 V)` with packet `03 01 02`; `U8 N; Times(1, 0, U8 V)` with `03 02 01 02`; `Repeat(Flags(U8 V))` with `03 01 02`; `Repeat(0)` with packet `03`; a `List<int>` and `List<long>` of `U32` in a `Repeat`/`Times`; 23 member types x `U8`/`U32` x `Repeat`/`Times` (review A1/A2 grid)

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | typed unpack of each round row | `ShortPacket` with `Field` `V`; the handler is not called; no exception; an empty round (`03`) binds the row |
| 2 | build a scheme with a `List<int>` or `List<long>` in a round | `ArgumentException` containing `'Ids'` and `one list per round` |
| 3 | build the 23-member grid | a member builds if and only if typed unpack binds it: `List<List<object?>>`, `List<object?>`, `IList`, `IList<object?>`, `object[]`, `object`, `ICollection<object?>`, `IEnumerable`, `IReadOnlyList<object?>`, `List<IList>`, `List<object>`, `IList[]` build and bind `[[10],[11]]`; every other member of the grid (`List<int>`, `List<long>`, `int[]`, `List<List<int>>`, `int[][]`, `object[,]`, `string`, `byte`, `IList<int>`, and the dictionary members in a row of lists) does not build; a dict member in a round builds and unpack returns `ShortPacket` naming `Ids` when it cannot hold the rounds, and binds `[{a:10},{a:11}]` when it can |

**Expected outcome**: steps 1 to 3 as listed; HEAD built `List<long>` for a `U32` list but every packet with a round returned `ShortPacket` (review A1, a pinned unusable scheme), and an `object[]` member that bound before returned `ShortPacket` (A2). Tests: C# `TypedRoundUnpackTests.Ac1_Unpack_RepeatRoundIntoAByteMember_ReturnsAnErrorNamingTheField`, `Ac1_Unpack_TimesRoundIntoAByteMember_ReturnsAnErrorNamingTheField`, `Ac1_Unpack_FlagsMemberRoundIntoAByteMember_ReturnsAnErrorNamingTheField`, `Ac1_Unpack_RepeatWithNoRounds_StillBindsTheRow`, `Ac2_Scheme_ListOfNarrowIdsInARepeat_IsRefusedAtConstructionNamingTheMember`, `Ac2_Scheme_ListOfNarrowIdsInATimes_IsRefusedAtConstructionNamingTheMember`, `Ac2_Scheme_ListOfLongIdsInARepeat_IsRefusedAtConstructionNamingTheMember`, `Ac2_Scheme_ListOfLongIdsInATimes_IsRefusedAtConstructionNamingTheMember`; `RoundCollectionMemberTests.ListInARound_BuildsIfAndOnlyIfTypedUnpackBindsIt` (92 theory rows), `ListOfScalarsInARound_IsRefusedNamingTheMember`, `ObjectArrayInARound_BindsAsBefore`, `DictInARound_BindsOrReturnsTheErrorResultAndNeverThrows`, `ListInARound_OneRound_BindsAListOfOneList`. Upgrade note: a pack-only list member in a round that built before (`List<List<int>>`, `IList<int>`) is refused at construction. Not specified (loop 21): typed scalars in a round never bind to a scalar member (D5).
**Max execution time**: 1s

### FT-X-51: A C# packet buffer past the array limit refuses with the member name (review A8)

**Summary**: With `maxBytes` above about 2^31 - 57, `Count + size` could overflow an `int` instead of refusing; `PackOut` now uses long arithmetic and an effective cap of `min(maxBytes, 0x7FFFFFC7)` and refuses naming the member (loop 20 review A8 on AZ-2354).
**Traces to**: AZ-2354 AC-3, AZ-2354 AC-5
**Category**: Errors

**Preconditions**:
- C# as built in the fix pass

**Input data**: `maxBytes` 1, 1 000 000, 0x7FFFFFC7, 0x7FFFFFC8, `int.MaxValue`, `long.MaxValue`; a `PackOut` with one byte written and a reserve of `int.MaxValue` for member `Blob`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | read the effective cap | 1, 1 000 000, 0x7FFFFFC7, then 0x7FFFFFC7 for the three larger values |
| 2 | reserve `int.MaxValue` bytes at `maxBytes` `long.MaxValue`, `int.MaxValue + 1` or `0x7FFFFFC8` | `'Blob': the packet would be 2147483647 bytes, above the limit of 2147483591 bytes` |
| 3 | after 1 byte is written, reserve `int.MaxValue` at `long.MaxValue` | the message says `would be 2147483648 bytes` (long arithmetic) |
| 4 | pack a one-field row with `maxBytes` `long.MaxValue` | packs as before |

**Expected outcome**: as listed. Tests: C# `PackOutCapTests.EffectiveCap_IsTheSmallerOfMaxBytesAndTheArrayLimit`, `Reserve_PastTheArrayLimit_RefusesNamingTheMemberWithTheBudgetMessage`, `Reserve_AfterBytesWritten_CountsThemInLongArithmetic`, `Pack_WithAHugeMaxBytes_StillPacksASmallPacket`; limits validation in `PackOutputBudgetTests.Ac5_Limits_MaxBytesIsCheckedBeyondTheIntRange`.
**Max execution time**: 1s

### FT-X-52: Files near the cap are split and the hostile cases are replayed by six loaders

**Summary**: `csharp/tests/LayoutTests.cs` (517 lines) and `rust/src/scheme/bound.rs` (514) are split by responsibility, every resulting file is under 500 lines and the suites keep their counts; the seven new hostile `pack` cases are replayed by all six loaders (loop 20, AZ-2365, AZ-2367).
**Traces to**: AZ-2365 AC-1, AZ-2367 AC-1
**Category**: Errors

**Preconditions**:
- The six packages as built in loop 20; the file and its README pass FT-X-01

**Input data**: the line counts of the split files; `fixtures/hostile/cases.txt` (40 cases: 10 `unpack`, 9 `construct`, 2 `limit`, 19 `pack`)

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | count lines of the split files | `csharp/tests/LayoutTests.cs` 201 and `LayoutCountedTests.cs` 323; `rust/src/scheme/bound.rs` 357 and `bound_collections.rs` 164; the largest loop 20 Rust test files are `hostile_tests.rs` 491 and `pack_output_budget_tests.rs` 411 |
| 2 | run `fixtures/hostile/check-cases.sh` and `cases.test.sh` | `hostile cases ok: 40`; the 26 corrupted copies still exit non-zero |
| 3 | each package replays the seven new cases | the outcomes in FT-X-10 (hostile case file): 30 of 40 cases run in C++ and 10 are skipped with a reason; the other five run all 40 except the Rust skip of `pack_element_times_over_budget` |
| 4 | suite counts | no per-split count was recorded; batch 02 reports C# 913 to 994 and Rust lib 436 to 469 across the whole wave, new tests included |

**Expected outcome**: step 1 under 500; step 2 `hostile cases ok: 40`; step 3 as in FT-X-10. Loader tests: TypeScript `hostile.test.ts` (`PACK_REFUSAL` table pins the rule that fired) with `support/hostile-pack.ts`; Python `hostile_support.py` (`PACK_CASES`); Java `HostileVectorTest.replayPack`; C# `HostilePackVectorTests.PackCase_ReturnsTheBytesOrRefuses` (the member table pins `'S'`, `'K'`, `'M0'`, `'Pt'`); Rust `hostile_tests.rs` (`pack_case`, `PACK_NOT_RUN`); C++ `hostile_pack_cases.hpp` (`kPackSkips`). Not specified (loop 21): the Python, Java, Rust and C++ loaders assert refusal only, not which rule fired (reviews B4, C5); the slow cases (Python element 7.1 s, Python slots 3.3 to 4.2 s, Rust debug slots 8.1 s, TypeScript slots 1.45 s) are kept at spec size.
**Max execution time**: 10s

## Loop 20 interaction risks mapped to tests

`_docs/02_document/interaction-risks.md` has no loop 20 rows at the time of this sync (another agent is updating it, and its rows have no ids), so the rows are referenced by the first words of their Risk column. If loop 20 rows are added there, map them to the same ACs.

| Interaction risk (row of `interaction-risks.md`) | Loop 20 AC and scenario | Test exists |
|---|---|---|
| "A `times` count in the billions with one lone value makes pack write gigabytes (security F21)" (loop 19, now bounded by bytes and slots as well as by `maxRounds`) | AZ-2354 AC-1 to AC-4, AZ-2355 AC-1 to AC-3; FT-X-38 to FT-X-43 | yes in five packages; C++ holds its rounds in a fixed `Array` |
| "A split flag bit is decided before the field its `when` or `times` reads is written, so a given value is dropped without a word" | AZ-2356 AC-1 and AC-2, AZ-2357 AC-1, AZ-2360 AC-1 and AC-2, AZ-2363 AC-1, AZ-2364 AC-1; FT-X-44 to FT-X-47 | yes |
| "The six languages write different bytes for the same list" (AC-3, AC-14) | AZ-2354 AC-6 (accepted rows keep their bytes), AZ-2367 AC-1 (six loaders replay the seven new `pack` cases); FT-X-42, FT-X-52 | yes: golden, route and ring unchanged; the ring replay of the new limits is not run (assessment "Not walked") |
| A packet pack writes is refused by the same scheme's unpack (no interaction-risk row yet; assessment S3) | AZ-2354 AC-4 (row 16 unpack at the default limit), AZ-2355 AC-1 | yes in TypeScript, Python, C# and Rust (an unpack of the raised-limit packet at the default limit; Java's row 16 test is in `rows14To16SlotsAreChargedOnPack`); Python unpack surcharge and the slot width differences are open (loop 21 U1, U2) |
