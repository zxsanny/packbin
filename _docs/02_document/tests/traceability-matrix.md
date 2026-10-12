# Traceability Matrix

## Acceptance Criteria Coverage

| AC ID | Acceptance Criterion | Test IDs | Coverage |
|-------|---------------------|----------|----------|
| AC-1 | Position pack is the 13-byte hex | FT-P-01, SM-01, NFT-RES-01 | Covered |
| AC-2 | Unpack returns those fields and 0 motion fields | FT-P-02, SM-02 | Covered |
| AC-3 | All six languages' bytes match | FT-P-03 | Covered |
| AC-4 | Clear bit adds 0 bytes; flags 0x20 adds 2 | FT-P-04 | Covered |
| AC-5 | A stored 0 is written | FT-P-05 | Covered |
| AC-6 | Conditional group adds 0 bytes or its width | FT-P-06 | Covered |
| AC-7 | Repeat yields one value per group; 1 leftover byte is an error | FT-P-07, FT-N-02 | Covered |
| AC-8 | Short field names field, needed, left, and returns 0 values | FT-N-01, NFT-RES-01, NFT-SEC-02 | Covered |
| AC-9 | Trailing bytes are an error and 0 values | FT-N-02 | Covered |
| AC-10 | 100000 round trips ≤ 1 second on one core | NFT-PERF-01, NFT-RES-LIM-01 | Covered |
| AC-11 | Tests run on every push and pull request | FT-P-09 | Covered |
| AC-12 | A matching tag publishes one package per language present | FT-P-08 | Covered |
| AC-13 | The first tag publishes exactly six packages | FT-P-08, FT-P-10 | Covered |
| AC-14 | A golden mismatch publishes 0 packages | FT-N-03 | Covered |
| AC-15 | A missing language publishes 0 packages | FT-N-04 | Covered |
| AC-16 | Published packages declare MIT | FT-P-08 | Covered |
| AZ-1938 AC-1 | `zxsanny` packs to `07007a7873616e6e79` | FT-U-01 | Covered |
| AZ-1938 AC-2 | An empty string is `0000` | FT-U-02 | Covered |
| AZ-1938 AC-3 | 65536 UTF-8 bytes writes 0 bytes | FT-U-03 | Covered |
| AZ-1938 AC-4 | A short string names needed 7 and left 2 | FT-U-04 | Covered |
| AZ-1939 AC-1 | A list of 1 and 2 is `020001000200` | FT-L-01 | Covered |
| AZ-1939 AC-2 | One big-endian 1 is `01000001` | FT-L-02 | Covered |
| AZ-1939 AC-3 | A list leaves the next field as `01000102` | FT-L-03 | Covered |
| AZ-1939 AC-4 | An empty list is `0000`; 65536 elements write 0 bytes | FT-L-04 | Covered |
| AZ-1940 AC-1 | The user value is the 103-byte hex | FT-D-01 | Covered |
| AZ-1940 AC-2 | Insert order does not change the hex | FT-D-02 | Covered |
| AZ-1940 AC-3 | Unpack returns the username, roles, and access lists | FT-D-03 | Covered |
| AZ-1940 AC-4 | Empty string, list, and dictionary are `000000000000` | FT-D-04 | Covered |
| AZ-1940 AC-5 | A repeated key returns 0 values | FT-D-05 | Covered |
| AZ-1941 AC-1 | Six handoffs unpack the user value | FT-H-01 | Covered |
| AZ-1941 AC-2 | Six handoffs unpack the 58-byte nested dictionary | FT-H-02 | Covered |
| AZ-1941 AC-3 | The position record stays 13 bytes | FT-H-03 | Covered |
| AZ-1945 AC-1 | Constant type byte is not a row value | FT-S-01 | Covered |
| AZ-1945 AC-2 | Unpack drops the constant | FT-S-02 | Covered |
| AZ-1945 AC-3 | Wrong type byte | FT-S-03 | Covered |
| AZ-1945 AC-4 | Absent type number keeps the golden position | FT-S-04 | Covered |
| AZ-1945 AC-5 | Illegal type placement fails at scheme build | FT-S-05 | Covered |
| AZ-1945 AC-6 | Six languages | FT-S-07 | Covered |
| AZ-1946 AC-1 | Pack takes the scheme | FT-S-01 | Covered |
| AZ-1946 AC-2 | Unpack takes the same scheme | FT-S-02 | Covered |
| AZ-1946 AC-3 | The scheme argument is required | FT-S-05 | Covered |
| AZ-1946 AC-4 | Wrong type byte | FT-S-03 | Covered |
| AZ-1946 AC-5 | Untyped path stays the golden position | FT-S-04 | Covered |
| AZ-1946 AC-6 | The row stays data | FT-S-05 | Covered |
| AZ-1946 AC-7 | Six languages | FT-S-07 | Covered |
| AZ-1949 AC-1 | Scheme replaces Packet | FT-S-06 | Covered |
| AZ-1949 AC-2 | The row has no type member | FT-S-04 | Covered |
| AZ-1949 AC-3 | Known scheme checks the leading byte | FT-S-03 | Covered |
| AZ-1949 AC-4 | Unknown buffer calls the matching handler | FT-S-06 | Covered |
| AZ-1949 AC-5 | Unknown type number | FT-S-06 | Covered |
| AZ-1949 AC-6 | Type numbers in one call are unique | FT-S-06 | Covered |
| AZ-1949 AC-7 | Six languages | FT-S-07 | Covered |
| AZ-1950 AC-1 | Member names are not the wire names | FT-B-01 | Covered |
| AZ-1950 AC-2 | Sibling references use the order | FT-B-02 | Covered |
| AZ-1950 AC-3 | Flags use child accessors | FT-B-03 | Covered |
| AZ-1950 AC-4 | Nested row type has its own ids | FT-B-04 | Covered |
| AZ-1950 AC-5 | Order must match the number | FT-B-05 | Covered |
| AZ-1950 AC-6 | Six languages | FT-S-07, FT-B-01 | Covered |
| 04_borrowed_count AC-1 | Width-2 list borrows the count | FT-C-01 | Covered |
| 04_borrowed_count AC-2 | Width-1 list uses count minus one | FT-C-02 | Covered |
| 04_borrowed_count AC-3 | The group stops, then the next field is read | FT-C-03 | Covered |
| 04_borrowed_count AC-4 | One route scheme round-trips | FT-C-04 | Covered |
| 04_borrowed_count AC-5 | Length and short tail fail closed | FT-C-05 | Covered |
| scheme-field-order AC-1 | Value fields are numbered in list order | FT-O-01 | Covered |
| scheme-field-order AC-2 | A continuing group shows the next value id | FT-O-02 | Covered |
| scheme-field-order AC-3 | A nested list starts at 0 | FT-O-03 | Covered |
| scheme-field-order AC-4 | Every Rust scheme build runs the check | FT-O-04 | Covered |
| scheme-field-order AC-5 | The failure rule is written next to the order sentence | FT-O-05 | Covered |
| scheme-field-order AC-6 | Existing packets keep their bytes | FT-O-06 | Covered |
| pack-session AC-1 | Clear pack is unchanged | FT-P-01 | Covered |
| pack-session AC-2 | One connection round-trips | FT-K-02 | Covered |
| pack-session AC-3 | The waiter can send | FT-K-03 | Covered |
| pack-session AC-4 | A second packet round-trips | FT-K-04 | Covered |
| pack-session AC-5 | Two clients do not share a stream | FT-K-05 | Covered |
| pack-session AC-6 | A bad setup creates nothing | FT-K-06 | Covered |
| pack-session AC-7 | Pack before the connection is open fails | FT-K-07 | Covered |
| pack-session AC-8 | The README shows both ways | FT-K-08 | Covered |
| AZ-2019 AC-1 | Clear pack is unchanged | FT-P-01 | Covered |
| AZ-2019 AC-2 | The opener and the waiter round-trip | FT-K-02 | Covered |
| AZ-2019 AC-3 | The waiter sends | FT-K-03 | Covered |
| AZ-2019 AC-4 | A second packet round-trips | FT-K-04 | Covered |
| AZ-2019 AC-5 | Two sessions stay apart | FT-K-05 | Covered |
| AZ-2019 AC-6 | Bad lengths create nothing | FT-K-06 | Covered |
| AZ-2019 AC-7 | Pack before open fails | FT-K-07 | Covered |
| AZ-2020 AC-1 | The ciphertext matches C# | FT-K-09 | Covered |
| AZ-2020 AC-2 | The waiter recovers the row | FT-K-02 | Covered |
| AZ-2020 AC-3 | Clear pack is unchanged | FT-P-01 | Covered |
| AZ-2020 AC-4 | Bad lengths create nothing | FT-K-06 | Covered |
| AZ-2021 AC-1 | The ciphertext matches C# | FT-K-09 | Covered |
| AZ-2021 AC-2 | The waiter recovers the row | FT-K-02 | Covered |
| AZ-2021 AC-3 | Clear pack is unchanged | FT-P-01 | Covered |
| AZ-2021 AC-4 | Bad lengths create nothing | FT-K-06 | Covered |
| AZ-2022 AC-1 | The ciphertext matches C# | FT-K-09 | Covered |
| AZ-2022 AC-2 | The waiter recovers the row | FT-K-02 | Covered |
| AZ-2022 AC-3 | Clear pack is unchanged | FT-P-01 | Covered |
| AZ-2022 AC-4 | Bad lengths create nothing | FT-K-06 | Covered |
| AZ-2023 AC-1 | The ciphertext matches C# | FT-K-09 | Covered |
| AZ-2023 AC-2 | The waiter recovers the row | FT-K-02 | Covered |
| AZ-2023 AC-3 | Clear pack is unchanged | FT-P-01 | Covered |
| AZ-2023 AC-4 | Bad lengths create nothing | FT-K-06 | Covered |
| AZ-2024 AC-1 | The ciphertext matches C# | FT-K-09 | Covered |
| AZ-2024 AC-2 | The waiter recovers the row | FT-K-02 | Covered |
| AZ-2024 AC-3 | Clear pack is unchanged | FT-P-01 | Covered |
| AZ-2024 AC-4 | Bad lengths create nothing | FT-K-06 | Covered |
| AZ-2025 AC-1 | One ciphertext | FT-K-09 | Covered |
| AZ-2025 AC-2 | A peer unpacks it | FT-K-09 | Covered |
| cpp-microcontroller AC-1 | The core builds the embedded way | FT-E-01 | Covered |
| cpp-microcontroller AC-2 | No heap and no exceptions in a firmware image | FT-E-02 | Covered |
| cpp-microcontroller AC-3 | The same bytes on the target CPU | FT-E-03 | Covered |
| cpp-microcontroller AC-4 | The same bytes on a big-endian CPU | FT-E-04 | Covered |
| cpp-microcontroller AC-5 | Flash and stack budget | FT-E-05 | Covered |
| cpp-microcontroller AC-6 | Errors are values | FT-E-06 | Covered |
| cpp-microcontroller AC-7 | Scheme order is checked without throwing | FT-E-07 | Covered |
| cpp-microcontroller AC-8 | Strings and bytes are borrowed | FT-E-08 | Covered |
| cpp-microcontroller AC-9 | `f64` needs an 8-byte double | FT-E-09 | Covered |
| cpp-microcontroller AC-10 | The session runs on the board | FT-E-10 | Covered |
| cpp-microcontroller AC-11 | Host programs use the core API | FT-E-11 | Covered |
| cpp-microcontroller AC-12 | Installable from the embedded registries | FT-E-12 | Covered |
| cpp-microcontroller AC-13 | Every target runs in CI | FT-E-13 | Covered |
| AZ-2070 AC-1 | Every listed hostile case is present and well formed | FT-X-01 | Covered |
| AZ-2070 AC-2 | A malformed line fails the check | FT-X-01 | Covered |
| AZ-2070 AC-3 | Each case is described | FT-X-01 | Covered |
| AZ-2070 AC-4 | CI runs the check | FT-X-01 | Covered |
| AZ-2078 AC-1 | A reused flag-byte number round-trips | FT-X-02 | Covered |
| AZ-2078 AC-2 | Inner bits still read their own byte | FT-X-02 | Covered |
| AZ-2078 AC-3 | A zero-progress repeat ends | FT-X-03 | Covered |
| AZ-2078 AC-4 | Hostile vectors on the host | FT-X-04 | Covered |
| AZ-2078 AC-5 | Embedded profile and budgets hold | FT-E-05 | Covered |
| AZ-2081 AC-1 | A bool outside flags is refused | FT-X-05 | Covered |
| AZ-2081 AC-2 | An empty group outside flags is refused | FT-X-05 | Covered |
| AZ-2081 AC-3 | A bool inside flags is unchanged | FT-X-06 | Covered |
| AZ-2081 AC-4 | A u2 over 64 children is refused | FT-X-07 | Covered |
| AZ-2081 AC-5 | Embedded runner and budgets hold | FT-E-05 | Covered |
| AZ-2025 AC-3 | Clear pack still matches | FT-P-01 | Covered |
| AZ-2026 AC-1 | Both examples are in the README | FT-K-08 | Covered |
| AZ-2026 AC-2 | The session example matches the contract | FT-K-08 | Covered |
| AZ-2120 AC-1 | C# `When` under a combined `Flags`: `Mode=1, Speed=7, Heading=90` packs `01 01 03 07 5a00` and unpacks to the same row | FT-X-13; tests: C# `FlagsWhenMemberTests.Ac3_Typed_ConditionHoldsAndBodyPresent_WritesTheBodyAndRoundTrips`, `Ac3_Dictionary_ConditionHoldsAndBodyPresent_WritesTheBodyAndRoundTrips` | Covered |
| AZ-2120 AC-2 | The other five packages pack the same scheme to the C# bytes | FT-X-13; tests: C# `FlagsWhenMemberTests`, TypeScript `flags-when-member`, Python `test_flags_when_member`, Rust `flags_when_member_tests` + `flags_member_typed_tests`, Java `FlagsWhenMemberTest`, C++ `flags_when_member_host_tests` | Covered |
| AZ-2120 AC-3 | `when` under `flags`, all six: `01 01 03 07 5a00`; `Mode=0` leaves the bit clear and round-trips | FT-X-13; tests: C# `FlagsWhenMemberTests`, TypeScript `flags-when-member`, Python `test_flags_when_member`, Rust `flags_when_member_tests` + `flags_member_typed_tests`, Java `FlagsWhenMemberTest`, C++ `flags_when_member_host_tests` | Covered |
| AZ-2120 AC-4 | `times` and `repeat` under `flags`, all six: the bit is on exactly when a round is written; same bytes in every package | FT-X-13; tests: C# `FlagsRoundMemberTests`, TypeScript `flags-times-repeat-member`, Python `test_flags_round_member`, Rust `flags_round_member_tests` + `flags_zero_rounds_tests`, Java `FlagsRoundMemberTest`, C++ `flags_times_repeat_member_host_tests` | Covered |
| AZ-2120 AC-5 | Packets of AC-3 and AC-4 written by one package unpack to equal rows in every other (each package pins the hex) | FT-X-13; tests: Python `test_ac5_old_and_new_when_under_flags_packets_unpack`, `test_ac5_old_and_new_times_under_flags_packets_unpack`, `test_ac5_old_and_new_repeat_under_flags_packets_unpack`, Java `ac5TimesPacketsUnpack`, `ac5RepeatPacketsUnpack`, and the `*_unpack` rows of the member tests above | Covered |
| AZ-2120 AC-6 | Nothing else changes: golden, route and every packet not using the shape keep their bytes | FT-X-14, FT-P-01, FT-C-04; tests: TypeScript `AC-6 a row that does not use the shape is unchanged`, the six package suites | Covered |
| AZ-2126 AC-1 | `eq(bool, false)` is a scheme error naming the `when` and field 0, in every package | FT-X-08, FT-X-09; tests: C# `EqBoolTrueOnlyTests.Ac1_*`, TypeScript `eq-source-kinds`, Python `test_when_count_sources`, Rust `eq_bool_true_tests`, Java `EqBoolTrueOnlyTest`, C++ `source_kinds_host_tests` + compile-fail `when_eq_bool_false` | Covered |
| AZ-2126 AC-2 | `eq(bool, true)` packs `010105` and round-trips `{on: true, v: 5}` in every package | FT-X-08; tests: C# `EqBoolTrueOnlyTests.Ac2_*`, TypeScript `eq-source-kinds` (AC-2), Python `test_az_2126_ac2_*`, Rust `ac2_eq_bool_true_*`, Java `EqBoolTrueOnlyTest`, C++ `eq_on_a_bool_with_true_round_trips` | Covered |
| AZ-2126 AC-3 | The construct vector `eq_bool_false` gives `scheme_error` in every package | FT-X-08, FT-X-01, FT-X-04; tests: the `construct` replay of each package's hostile vector test (`HostileVectorTests`, `hostile.test.ts`, `test_hostile_vectors`, `hostile_tests`, `HostileVectorTest`, `hostile_host_tests`) | Covered |
| AZ-2128 AC-1 | Each presence probe sets the group's bit and round-trips; loop 18 adds `when`, `times` and `repeat` members and C++ `u2`, nested `flags` and `flag_bit` heads | FT-X-13; tests: the member tests of AZ-2120 AC-4, C++ `group_with_only_a_u2_value` | Covered |
| AZ-2128 AC-2 | A set group or member with a missing required value fails pack naming that value | FT-X-14; tests: C# `Ac3_SetWhenWithAMissingBodyValue_FailsNamingTheValue`, `Ac4_Times_CountAboveZeroButTooFewValues_FailsNamingTheValue`, Python `test_ac3_a_set_when_member_missing_a_value_fails_pack_naming_it`, Rust `flags_zero_rounds_tests`, Java `ac3TwoValueBodyAndMissingValues`, `ac4TimesErrors` | Covered |
| AZ-2128 AC-3 | Golden and route fixtures unchanged | FT-X-14, FT-P-01, FT-C-04 | Covered |
| AZ-2135 AC-1 | TypeScript, C# and Java number split bits by field order and give the Rust bytes `010105`, `010209`, `01000109`; a shared handle builds both schemes | FT-X-16; tests: TypeScript `split-bits-field-order`, C# `SplitBitOrderTests`, Java `SplitBitOrderTest`, Python `test_split_bits_field_order` | Covered |
| AZ-2135 AC-2 | C++ packs `01000106` and `010101010506` for `{k:0, b:6}` and `{k:1, a:5, b:6}`; no outer byte gives `SchemeInvalid` naming `b` | FT-X-16, FT-X-15; tests: C++ `grouped_tests` (AC-2 hex), `flag_scope_host_tests` | Covered |
| AZ-2135 AC-3 | Golden, route and motion examples unchanged | FT-X-16, FT-P-01, FT-C-04 | Covered |
| AZ-2194 AC-1 | `check-cases.sh` accepts `pack bytes <hex>` and `pack pack_error -` lines (the committed file reports `hostile cases ok: 25`; the spec text said 22 before `eq_bool_false` and the two `limit` cases were counted) | FT-X-01; tests: `fixtures/hostile/cases.test.sh` | Covered |
| AZ-2194 AC-2 | The check rejects a malformed pack line and names it | FT-X-01; tests: `cases.test.sh` corruptions `pack_bytes_dash_hex`, `pack_error_with_hex`, `pack_odd_hex`, `pack_hex_not_01`, `pack_unpack_term`, `unpack_uses_bytes`, `unpack_uses_pack_error`, `construct_uses_pack_error`, `pack_duplicate_id` | Covered |
| AZ-2194 AC-3 | Each pack case needs a README section with Scheme, Row, `Run by` and `Not run by` naming each of the six packages exactly once | FT-X-01; tests: `cases.test.sh` README corruptions `pack_no_section`, `pack_package_in_neither`, `pack_package_twice`, `pack_no_not_run_list`, `pack_readme_packet_differs`, `pack_readme_expected_differs`, `pack_no_row_line` | Covered |
| AZ-2194 AC-4 | `u8 a`, `a = 300` is `pack_error` in TypeScript, Python, Java, C# (dictionary rows), Rust (map form); C++ skipped with its reason | FT-X-10; tests: `pack_out_of_range_integer` replay in the six hostile vector tests (C#: `HostilePackVectorTests.PackCase_ReturnsTheBytesOrRefuses`) | Covered |
| AZ-2194 AC-5 | `u8 a; u8 b` with `{a: 1}` is `pack_error` in all six | FT-X-10; tests: `pack_missing_required_value` replay in the six hostile vector tests | Covered |
| AZ-2194 AC-6 | `times` list too long and too short is `pack_error` in all six | FT-X-10; tests: `pack_times_list_too_long`, `pack_times_list_too_short` replay in the six hostile vector tests | Covered |
| AZ-2194 AC-7 | The aligned round row packs `01030102020303` in all six | FT-X-10; tests: `pack_aligned_round_row` replay in the six hostile vector tests | Covered |
| AZ-2194 AC-8 | Every package's vector test handles the stage: run where listed, skipped with a reason where not | FT-X-10, FT-X-04; tests: `EveryPackCase_HasACSharpScheme`, `test_every_pack_vector_has_a_declared_scheme`, `pack_cases` (C++), `replayPack` (Java), `hostile.test.ts` pack cases, `hostile_tests` (Rust) | Covered |
| AZ-2194 AC-9 | The scaffold job runs the check and the self-test with the new count and the corruptions | FT-X-01; tests: the `hostile case file` step of the `scaffold` job (`cases.test.sh`, 26 corruptions) | Covered |
| AZ-2304 AC-1 | A flag byte inside a `flags` member is invisible to a later bit; building fails with `SchemeInvalid` naming `b` | FT-X-15; tests: C++ `byte_inside_a_flags_member_is_not_seen_after_it`, compile-fail `flag_byte_in_flags_member` | Covered |
| AZ-2304 AC-2 | A flag byte inside a flag-bit child is invisible to a later bit | FT-X-15; tests: C++ `byte_inside_a_flag_bit_child_is_not_seen_after_it`, compile-fail `flag_byte_in_flag_bit_child` | Covered |
| AZ-2304 AC-3 | A byte read before the container keeps working: Rust bytes `01010007`, `010101030007`, `01010103010507`, both directions | FT-X-15; tests: C++ `outer_byte_serves_a_bit_after_a_flags_member`, `outer_byte_serves_a_bit_after_a_flag_bit_child` | Covered |
| AZ-2304 AC-4 | Golden, route and motion unchanged; embedded flash within budget | FT-X-15, FT-E-05; tests: C++ `make -C cpp test`; the flash of `unpack_scoped` is measured in the embedded stages of the total run | Covered |
| AZ-2305 AC-1 | A narrower element type (`List<int>`, `int[]`, `Dictionary<string,int>` for `u32`; `List<byte>` for `u16`) is refused naming the member | FT-X-17; tests: C# `CollectionMemberTests.Build_ListOfIntForU32_RefusedNamingMemberAndElement`, `Build_ArrayOfIntForU32_*`, `Build_DictOfIntForU32_*`, `Build_ListOfByteForU16_*`, `Build_EveryIntegerPair_AcceptedOnlyWhenTheMemberHoldsTheFieldRange` | Covered |
| AZ-2305 AC-2 | `Stack<int>`, `HashSet<int>`, `IEnumerable<int>` for a list field are refused naming the member | FT-X-17; tests: C# `CollectionMemberTests.Build_StackForAList_*`, `Build_HashSetForAList_*`, `Build_IEnumerableForAList_*` | Covered |
| AZ-2305 AC-3 | The 7-byte packet no longer throws out of `Unpack` | NFT-SEC-03; tests: C# `CollectionMemberTests.Unpack_F25Packet_AgainstWideEnoughScheme_ReturnsValueNotException` | Covered |
| AZ-2305 AC-4 | Matching members unchanged on net10.0 and netstandard2.0 | FT-X-17, FT-P-01, FT-C-04; tests: C# `CollectionMemberTests.Build_MatchingAndWiderMembers_Accepted`, the C# suite | Covered |
| AZ-2306 AC-1 | A non-null nested row with all members null sets the group bit and pack fails naming the first missing member | FT-X-18; tests: C# `EmptyNestedRowTests.Pack_AllNullObjectUnderFlags_*`, `Pack_AllNullObjectAtDepthTwo_*`, `Pack_FilledMidWithAllNullInnerObject_*` | Covered |
| AZ-2306 AC-2 | A null nested row stays absent (`0100`) | FT-X-18; tests: C# `EmptyNestedRowTests.Pack_NullNestedRow_BitClearAndBytesUnchanged` | Covered |
| AZ-2306 AC-3 | A filled object packs and unpacks as before (`01010406`) | FT-X-18, FT-P-01, FT-C-04; tests: C# `EmptyNestedRowTests.Pack_FilledObject_BytesAndRoundTripUnchanged` | Covered |
| AZ-2307 AC-1 | A `Flags` list or dict element packs and unpacks in C# dictionary and typed mode with the TypeScript bytes | FT-X-19; tests: C# `FlagsElementTests.Ac1_Pack_ListOfFlagsInDictionaryMode_WritesTheTypeScriptBytes`, `Ac1_Pack_DictOfFlagsInDictionaryMode_*`, `Ac1_Pack_ListOfFlagsTyped_*`, `Ac1_Pack_DictOfFlagsTyped_*`, `Ac1_Read_*` | Covered |
| AZ-2307 AC-2 | The `listgroup` and `dictgroup` rings include C#; the wiring test fails when a handoff line is missing | FT-X-19; tests: `language-pair.sh` rings (run in the total test run), `ring-wiring.test.sh` (C# lines) | Covered |
| AZ-2307 AC-3 | The `listflags` ring includes C# in both directions | FT-X-19; tests: `language-pair.sh` `listflags` ring (run in the total test run), `ring-wiring.test.sh` | Covered |
| AZ-2307 AC-4 | Golden, route and the C# suite unchanged on net10.0 and netstandard2.0 | FT-X-19, FT-P-01, FT-C-04; tests: the C# suite | Covered |
| AZ-2308 AC-1 | A probe table of the result per package for a lone dictionary in a `times` | FT-X-11; evidence: the probe table in `batch_01_loop18_report.md` and the before/after table of FT-X-11 | Covered |
| AZ-2308 AC-2 | A lone dictionary for a `Dict` name in a round is refused naming the member in C#, TypeScript, Python, Java, Rust | FT-X-11; tests: C# `LoneDictRoundTests.Ac2_*`, TypeScript `lone-dict-in-round` + `dict-non-plain-object`, Python `test_lone_dict_in_round`, Java `LoneDictRoundTest`, Rust `times_lone_value_tests` (dict case) | Covered |
| AZ-2308 AC-3 | A list with one dictionary per round packs as before | FT-X-11; tests: C# `LoneDictRoundTests.Ac3_*`, TypeScript `AC-3 a list with one dictionary per round packs`, Python `test_az_2308_ac3_*`, Java `listOfDictsPerRoundStillPacks` | Covered |
| AZ-2309 AC-1 | A fraction in a `u2` slot, `bits` item or `packed` item is refused naming the member | FT-X-20; tests: C# `StrictSlotTests.Ac1_Pack_FractionInASlot_ThrowsNamingTheMember`, `Ac1_Pack_FractionInsideFlagsRepeatAndListElement_IsRefused` | Covered |
| AZ-2309 AC-2 | A value that does not fit the slot is refused naming the member | FT-X-20; tests: C# `StrictSlotTests.Ac2_Pack_ValueThatDoesNotFit_ThrowsNamingTheMember` | Covered |
| AZ-2309 AC-3 | bool, string, char, enum, object and null are refused in slots | FT-X-20; tests: C# `StrictSlotTests.Ac3_Pack_BoolStringCharEnumObjectOrNull_ThrowsNamingTheMember` | Covered |
| AZ-2309 AC-4 | Valid values and whole numbers held as `double` or `long` keep their bytes; golden and route unchanged | FT-X-20, NFT-PERF-01; tests: C# `StrictSlotTests.Ac4_Pack_RangeEdgesAndWholeNumbers_KeepTheirBytes`, `Ac4_Pack_WholeNumbersAsDoubleOrLong_EqualTheIntegerBytes`, `Ac4_Pack_TypedRowOfInts_KeepsItsBytes` | Covered |
| AZ-2310 AC-1 | The rows `Read` returns for a list or dict of group elements pack to the original bytes | FT-X-21; tests: C# `DictRepackTests.Ac1_Pack_ReadOfAListOfGroups_GivesTheOriginalBytes`, `Ac1_Pack_ReadOfADictOfGroups_*`, `Ac1_Pack_ReadOfGroupsHoldingAStringAndFlags_*` | Covered |
| AZ-2310 AC-2 | Random packets repack to the original or fail as the unpack failed | FT-X-21; tests: C# `DictRepackTests.Ac2_Pack_RepackOfEveryUnpackedRandomPacket_EqualsItOrFailsAsTheUnpackDid` | Covered |
| AZ-2310 AC-3 | An `int` for a `Bytes` or `Sized` name is an `ArgumentException` naming the member, in and outside a round | FT-X-21; tests: C# `DictRepackTests.Ac3_Pack_IntForBytesOrSized_ThrowsArgumentExceptionNamingTheMember` | Covered |
| AZ-2310 AC-4 | Unchanged paths on net10.0 and netstandard2.0 | FT-X-21; tests: C# `DictRepackTests.Ac4_Pack_ByteArraysForBytesAndSized_KeepTheirBytes`, the C# suite | Covered |
| AZ-2311 AC-1 | The bytes Rust gives for a lone scalar are recorded beside the other packages' bytes | FT-X-12; evidence: `batch_01_loop18_report.md` and the TypeScript bytes in the AZ-2311 result | Covered |
| AZ-2311 AC-2 | Every round carries a lone scalar: `010201040105`, `0103010401050106`, `010201040104` | FT-X-12; tests: Rust `times_lone_value_tests::az2311_ac2_*` | Covered |
| AZ-2311 AC-3 | Per-round lists and the Rust suite unchanged; a short list is still `Missing` | FT-X-12; tests: Rust `az2311_ac3_one_round_and_per_round_lists_keep_their_bytes`, `az2311_ac3_a_list_shorter_than_the_count_is_still_missing` | Covered |
| AZ-2088 AC-1 | A missing required value throws `ArgumentException` naming the member | FT-X-22; tests: C# `LoudPackTests.Pack_RequiredValueMissing_ThrowsNamingTheMemberAndItsId`, `Pack_RequiredValueMissingInADictionary_Throws`, `Pack_RequiredValueSetToNull_Throws` | Covered |
| AZ-2088 AC-2 | A flag-bit absence is still allowed; the golden row is unchanged | FT-X-22, FT-P-01; tests: C# `LoudPackTests.Pack_FlagBitChildMissing_StaysABitClear`, `Pack_FieldInsideAFalseWhen_IsNotWalked` | Covered |
| AZ-2088 AC-3 | `repeat` and `times` list lengths are checked | FT-X-22; tests: C# `LoudPackTests.Pack_RepeatListsOfUnequalLength_ThrowsNamingTheShortList`, `Pack_TimesListShorterThanTheCount_ThrowsNamingTheShortList`, `Pack_TimesListLongerThanTheCount_ThrowsNamingTheLongList` | Covered |
| AZ-2088 AC-4 | An absent list, dict or sized member names the field, not `KeyNotFoundException` | FT-X-22; tests: C# `LoudPackTests.Pack_AbsentListDictOrSized_ThrowsArgumentExceptionNamingTheField`, `Pack_AbsentListInADictionary_ThrowsArgumentException`, `Pack_AbsentBytesUtf8OrNullableScalar_ThrowsArgumentExceptionNamingTheField` | Covered |
| AZ-2088 AC-5 | A field declared for another row type fails construction naming both types | FT-X-22; tests: C# `SchemeOwnershipTests.Construct_FieldDeclaredForAnotherRowType_ThrowsNamingBothTypes`, `Construct_ForeignFieldAtAnyDepth_Throws`, `Construct_ForeignFieldBuildsNoScheme_AndTheFieldsStayReusable` | Covered |
| AZ-2088 AC-6 | A float `when` never throws (superseded in loop 18: a float source for a `when` is refused at construction, AZ-2126) | FT-X-22, FT-X-09; tests: C# `FloatConditionValueTests.Construct_IntegerSourceWithAFloatConditionThatIsNotAWholeNumberInRange_IsRefused`, `PackAndUnpack_IntegerSourceWithAFloatCondition_MatchesOnTheSameNumber`; the AZ-2126 tests of FT-X-09 | Covered |
| AZ-2088 AC-7 | The scheme owns its fields: a replaced array element changes nothing | FT-X-22; tests: C# `SchemeOwnershipTests.Scheme_CopiesItsFieldList_SoALaterReplacementChangesNothing` | Covered |
| AZ-2088 AC-8 | A shared condition and field are not re-bound by a second scheme | FT-X-22; tests: C# `SchemeOwnershipTests.Scheme_SharedConditionAcrossTwoSchemes_IsNotReBound`, `Scheme_SharedConditionAcrossTwoSchemes_UnpacksEachWithItsOwnTarget`, `Scheme_SharedCountedFieldAcrossTwoSchemes_KeepsItsOwnCount`, `Schemes_SharingAConditionAndAField_PackAndUnpackTheirOwnBytesFromManyThreads` | Covered |
| AZ-2088 AC-9 | Existing bytes unchanged (golden and route) | FT-X-22, FT-P-01, FT-C-04; tests: the C# suite | Covered |
| AZ-2088 AC-10 | The type check runs at construction and the 100000 round trips stay within 1 s | NFT-PERF-01, FT-X-22 | Covered |
| AZ-2191 AC-1 | An integer that does not fit is refused naming the member and the kind | FT-X-22; tests: C# `StrictNumberTests.Pack_IntegerThatDoesNotFit_ThrowsNamingMemberAndKind` | Covered |
| AZ-2191 AC-2 | A fraction, bool or string for an integer is refused | FT-X-22; tests: C# `StrictNumberTests.Pack_FractionBoolOrStringForAnInteger_ThrowsNamingTheMember` | Covered |
| AZ-2191 AC-3 | Floats accept only numbers; f32 overflow is refused; infinities and NaN are written | FT-X-22; tests: C# `StrictNumberTests.Pack_StringBoolOrOverflowForAFloat_ThrowsNamingTheMember`, `Pack_F32Infinity_IsWritten`, `Pack_Nan_IsWritten`, `Pack_AnyNumericTypeForF64_Packs` | Covered |
| AZ-2191 AC-4 | Range edges, whole numbers held as `double` or `long`, golden and route keep their bytes | FT-X-22, FT-P-01, FT-C-04; tests: C# `StrictNumberTests.Pack_NumberThatFits_PacksAsBefore`, `Pack_BigEndianFieldWithAValueThatDoesNotFit_Throws`, `Pack_ValueInsideFlagsRepeatAndListElement_IsChecked` | Covered |
| AZ-2191 AC-5 | A row from unpack packs again to the original packet | FT-X-22; tests: C# `StrictNumberTests.Pack_RowReadByUnpack_PacksAgainToTheSameBytes` | Covered |
| AZ-2216 AC-1 to AC-11 | C# unpack round limits: defaults, `repeat` and `times` refused at round `maxRounds + 1`, slot limit and its per-call total, a refused 1 MiB packet bounded, limits belong to the scheme, invalid limits, nothing else changes | FT-X-23, NFT-RES-LIM-02; tests: C# `RoundLimitTests.Ac1_DefaultsAndConstants`, `Ac2_Repeat_DefaultLimit_*`, `Ac3_Repeat_RefusedWhenTheNextRoundWouldStart`, `Ac4_Times_RefusedWhenTheNextRoundWouldStart`, `Ac5_Times_DefaultLimit_U32Count`, `Ac6_SlotLimit_*`, `Ac7_SlotTotalIsSharedByEveryFieldOfOneCall`, `Ac8_RefusedOneMiBPacket_AllocationIsBoundedByTheLimits`, `Ac9_LimitsBelongToTheScheme`, `Ac10_InvalidLimits_AreRefusedAtConstruction`, `Ac11_ExistingCallShapes_CompileAndBehaveUnchanged` | Covered |
| AZ-2217 AC-1 to AC-11 | The same rules in TypeScript | FT-X-23, NFT-RES-LIM-02; tests: TypeScript `round-limits.test.ts` (describe blocks "scheme limits surface" for AC-1 and AC-11, "repeat limits" AC-2 and AC-3, "times limits" AC-4, "times at the default limit" AC-5, "slot limit" AC-6 and AC-7, "limits of a large packet" AC-8, "limits belong to the scheme" AC-9, "invalid limits" AC-10) | Covered |
| AZ-2218 AC-1 to AC-11 | The same rules in Java, with the slot total across list elements | FT-X-23, NFT-RES-LIM-02; tests: Java `RoundLimitsTest` (`defaultsAndSurface`, `repeatAtTheDefaultLimit`, `repeatRefusedAtTheNextRound`, `timesRefusedAtTheNextRound`, `timesAtTheDefaultLimit`, `slotLimit`, `slotTotalSpansFieldsAndElements`, `refusedMegabyteIsBoundedByTheLimits`, `limitsBelongToTheScheme`, `invalidLimitsAreRefused`, `existingCallSitesAreUnchanged`) | Covered |
| AZ-2219 AC-1 to AC-13 | The same rules in Rust, with a `times` inside a `repeat` and typed `times` rows | FT-X-23, NFT-RES-LIM-02; tests: Rust `round_limits_tests.rs` (`ac1_*` to `ac12_*`; AC-13 is the rest of the Rust suite) | Covered |
| AZ-2220 AC-1 | The format check accepts the `limit` stage | FT-X-23, FT-X-01; tests: `fixtures/hostile/check-cases.sh`, `cases.test.sh` | Covered |
| AZ-2220 AC-2 | The check rejects a malformed `limit` line | FT-X-23, FT-X-01; tests: `cases.test.sh` corruptions `limit_dash_hex`, `limit_odd_hex`, `limit_unknown_term` and the others on `limit` lines | Covered |
| AZ-2220 AC-3 | Both cases are documented and the README names the stage | FT-X-23, FT-X-01; tests: `check-cases.sh` README section check | Covered |
| AZ-2220 AC-4 | The packages replay `repeat_rounds_over_limit` and `times_rounds_over_limit` | FT-X-23; tests: the `limit` replay of `HostileVectorTests`, `hostile.test.ts`, `HostileVectorTest.replayLimit`, `hostile_tests` (Rust `limit_scheme_for`), Python `hostile_support.py` | Covered |
| AZ-2220 AC-5 | The existing vectors, including `oversize_count_times`, are unchanged | FT-X-23, FT-X-04; tests: the unpack replay of the six hostile vector tests | Covered |
| AZ-2220 AC-6 | C++ skips the `limit` stage and records why | FT-X-04, FT-X-23; tests: `hostile_host_tests.cpp` stage filter | Covered |
| AZ-2220 AC-7 | The size tests of the four package tasks exist | FT-X-23; tests: `RoundLimitTests.cs`, `round-limits.test.ts`, `RoundLimitsTest.java`, `rust/tests/round_limits_tests.rs` | Covered |
| AZ-2220 AC-8 | The README "Untrusted input" section states the new rule | FT-X-23; evidence: `README.md:1133` (the upgrade note, with Python added in loop 16) and the Untrusted input bullets | Covered |
| AZ-2220 AC-9 | The security docs record the outcome | FT-X-23; the security docs are owned by the security step, and `owasp_review.md` lines 16 and 35 now summarize loop 15 (the "Loop 15 status block" the spec names was replaced by later summaries) | BLOCKED — not verified (documentation AC, outside this folder) |
| AZ-2329 AC-1 | Pack refuses a count of `maxRounds + 1` and above, naming the first body member, with no bytes and no allocation for the count | FT-X-24, NFT-RES-LIM-03; tests: C# `PackRoundCapTests.Ac1_*`, TypeScript `pack-round-count-cap.test.ts` (AC-1 cases), Python `test_pack_round_count_cap.py::test_ac1_*`, Java `RoundLimitsTest.packRefusesACountAboveTheLimit` (incl. loop 19 B1 u64 cases), Rust `pack_round_cap_tests.rs::ac1_*`; hostile `pack_times_count_over_limit` (C++ skipped: capacity-bound) | Covered |
| AZ-2329 AC-2 | A count at the limit packs and round-trips | FT-X-24; tests: C# `PackRoundCapTests.Ac2_*`, TypeScript `AC-2 a count at the limit packs and round-trips`, Python `test_ac2_count_at_the_limit_packs_and_round_trips`, Java `RoundLimitsTest` ("AZ-2329 AC-2"), Rust `ac2_*` | Covered |
| AZ-2329 AC-3 | A scheme that raised `maxRounds` to 70 000 packs a count of 70 000 | FT-X-24; tests: C# `PackRoundCapTests.Ac3_Pack_SchemeThatRaisedTheLimit_PacksALargerCount`, TypeScript `AC-3 a scheme that raised maxRounds packs a larger count`, Python `test_ac3_a_scheme_that_raised_the_limit_packs_a_larger_count`, Java ("AZ-2329 AC-3"), Rust `ac3_a_scheme_with_a_raised_limit_packs_a_larger_count` | Covered |
| AZ-2330 AC-1 | Python packs the T1 shape like TypeScript (equivalent scheme, `010201050700`) | FT-X-25; tests: Python `test_round_fresh_scope.py::test_ac1_times_round_does_not_see_a_value_an_earlier_round_wrote`, `test_ac1_repeat_round_does_not_see_a_value_an_earlier_round_wrote`, `test_ac1_a_stale_value_in_the_skipped_slot_is_not_written` | Covered |
| AZ-2330 AC-2 | Unpack mirrors it | FT-X-25; tests: Python `test_ac2_unpack_times_round_starts_with_a_fresh_scope`, `test_ac2_unpack_leaves_the_byte_a_stale_when_would_have_read_as_trailing`, `test_ac2_unpack_repeat_round_starts_with_a_fresh_scope` | Covered |
| AZ-2330 AC-3 | Golden, route and ring fixtures unchanged | FT-X-25, FT-P-01, FT-C-04; tests: the Python suite (777) and the ring | Covered |
| AZ-2331 AC-1 | A `when` source or `times` count written after the split byte, body given, fails naming the member | FT-X-26; tests: C# `SplitFormDroppedBodyTests.Ac1_*`, TypeScript `split-form-loud-pack.test.ts` (AC-1), Python `test_split_form_pack_fails_loudly.py::test_ac1_*`, Java `SplitFormLoudPackTest.ac1ConditionWrittenAfterTheByte`, Rust `split_form_loud_tests.rs::ac1_*`, C++ `split_form_loud_host_tests.cpp::ac1_*`; hostile `pack_split_when_source_after_byte`, `pack_split_times_count_after_byte` | Covered |
| AZ-2331 AC-2 | A `times` bit whose count was skipped, values given, fails naming the member | FT-X-26; tests: C# `SplitFormDroppedBodyTests.Ac2_*`, TypeScript (AC-2), Python `test_ac2_*`, Java `ac2CountWrittenAfterTheByteOrNeverWritten`, Rust `ac2_*`, C++ `ac2_count_never_written`; hostile `pack_split_times_count_skipped`. Gaps: the combined `flags` form is silent in TypeScript and Java and C++ lets rounds through behind a clear `when` (loop 20) | Covered |
| AZ-2331 AC-3 | A false condition with a body given packs without the body and without an error (owner option A, 2026-10-11) | FT-X-26; tests: C# `Ac3_*`, TypeScript `AC-3 unchanged:*`, Python `test_ac3_*`, Java `ac3ConditionFalseOnWrittenValuesStillDropsTheBody`, Rust `ac3_*`; hostile `pack_split_false_condition_silent` (`0100025a00`) in all six | Covered |
| AZ-2331 AC-4 | The reference rows with the source before the byte keep their bytes | FT-X-26, FT-X-13; tests: C# `Ac4_Pack_SourceBeforeTheByte_BytesAreUnchanged`, TypeScript `AC-4 the reference rows*`, Python `test_ac4_*`, Java `ac4SourceBeforeTheByteIsUnchanged`, Rust `ac4_*`, C++ `ac4_source_before_the_byte_packs_as_before` | Covered |
| AZ-2332 AC-1 | A lone byte buffer for a `Bytes` or `Sized` name in a round is refused naming the member | FT-X-27; tests: TypeScript `lone-bytes-in-round.test.ts` (AC-1), Python `test_lone_bytes_in_round_refused.py::test_ac1_*`, Java `LoneBytesInRoundTest.ac1LoneBufferIsRefused`, Rust `lone_bytes_in_round_tests.rs::ac1_*`, C# `LoneRoundValueTests.Pack_LoneCollectionInARound_ThrowsNamingTheField`; hostile `pack_lone_bytes_in_round` (C++ skipped: typed `Array` of `Array`) | Covered |
| AZ-2332 AC-2 | A list with one buffer per round packs as before | FT-X-27; tests: TypeScript (AC-2), Python `test_ac2_*`, Java `ac2OneBufferPerRoundPacks`, Rust `ac2_*`, C# `LoneRoundValueTests.Pack_PerRoundBytes_PacksReadsAndRepacksTheSameBytes` | Covered |
| AZ-2333 AC-1 | Sibling `flags` members each have their own flag-byte scope; Rust bytes equal TypeScript (S1) | FT-X-28; tests: Rust `flags_member_scope_tests.rs::ac1_sibling_members_each_have_their_own_byte_scope`, `ac1_a_bit_in_a_sibling_member_cannot_use_the_byte_of_the_member_before`, `ac1_a_byte_that_is_itself_a_flags_member_is_not_seen_by_the_next_member` | Covered |
| AZ-2333 AC-2 | A single member is unchanged | FT-X-28, FT-X-13; tests: Rust `flags_member_scope_tests.rs::ac2_*` | Covered |
| AZ-2334 AC-1 | `eq(emptyGroup, true)` is accepted as a `when` source in C++ with the Rust bytes | FT-X-29; tests: C++ `source_kinds_host_tests.cpp::eq_on_an_empty_group_builds_and_round_trips`, `eq_on_an_empty_group_other_than_true_is_refused`, `a_field_with_the_id_of_an_empty_group_stays_the_source`; `late_source_host_tests.cpp::c8_*`; the arm stage stack 448 of 512 B | Covered |
| AZ-2335 AC-1 | Count 0 with a list of values is refused naming the member in all six | FT-X-30; tests: C# `TimesZeroWithValuesTests.Ac1_*`, TypeScript `times-count-zero-with-values.test.ts` (AC-1), Python `test_times_count_zero_with_values.py::test_ac1_*`, Java `TimesCountZeroTest.ac1CountZeroWithValuesIsRefused`, Rust `times_count_zero_tests.rs::ac1_*`, C++ `times_count_zero_host_tests.cpp::ac1_count_zero_with_a_value_is_refused`; hostile `pack_times_zero_with_values` | Covered |
| AZ-2335 AC-2 | Count 0 without values writes zero rounds | FT-X-30; tests: C# `Ac2_*`, TypeScript (AC-2), Python `test_ac2_*`, Java `ac2CountZeroWithoutValuesPacks`, Rust `ac2_count_zero_without_values_packs_no_round`, C++ `ac2_count_zero_without_values_packs` | Covered |
| AZ-2336 AC-1 | A short `times` list in Python outside `flags` is a named error, not `IndexError` | FT-X-31; tests: Python `test_times_longer_list.py::test_ac5_a_shorter_list_is_refused_naming_the_member`, `test_times_short_list.py::test_ac5_a_plain_member_refuses_a_short_list_naming_the_member`, `test_ac5_a_member_under_when_refuses_a_short_list_naming_the_member` (matched by content: no test cites AZ-2336) | Covered |
| AZ-2337 AC-1 | A C# group element ignores outer values and names a missing member | FT-X-32; tests: C# `GroupElementMembersOnlyTests.Ac1_*` | Covered |
| AZ-2337 AC-2 | Complete elements keep their bytes | FT-X-32; tests: C# `GroupElementMembersOnlyTests.Ac2_*`; the group rings | Covered |
| AZ-2338 AC-1 | `eq(u8, 300)` and other out-of-range values fail construction in six | FT-X-33; tests: C# `EqValueConstructionTests.Construct_EqValueTheSourceCannotHold_*`, TypeScript `eq-value-checked.test.ts` (AC-1..3), Python `test_eq_value_checked.py::test_ac1_*`, Java `EqValueCheckedTest.ac1OutOfRange` and `ReferenceScopeTest` (loop 19 B3), Rust `eq_range_tests.rs::ac1_*`, C++ `eq_value_checked_host_tests.cpp::ac1_*` and compile-fail `when_eq_out_of_range`; hostile `eq_out_of_range` | Covered |
| AZ-2338 AC-2 | A non-integer value (`"x"`, NaN) fails construction | FT-X-33; tests: Python `test_ac2_a_non_integer_value_is_refused_naming_the_member`, Java `ac2NotAnInteger`, Rust `ac2_*`, C#/TypeScript as AC-1. C++ builds `eq(u8, 1.5)`: out-of-range integers only | Covered |
| AZ-2338 AC-3 | A bool for an integer source fails construction (Python `True`) | FT-X-33; tests: Python `test_ac3_a_bool_for_an_integer_source_is_refused`, `test_ac3_a_bool_for_a_u2_slot_is_refused`, Java `ac3BoolForInteger`. Rust has no bool value; C++ builds `eq(u8, true)` | Covered |
| AZ-2338 AC-4 | `eq(u8, 5)` builds, packs and keeps its bytes | FT-X-33; tests: C# `EqValueConstructionTests.Construct_EqValueInTheSourceRange_Builds`, `Pack_EqValueInRange_BytesAreUnchanged`, Python `test_ac4_*`, Java `ac4ValidValueBuilds`, Rust `ac4_*`, C++ `ac4_*`, TypeScript `AC-4` | Covered |
| AZ-2339 AC-1 | A per-package table of the fraction rows in `u2`, `bits` and `packed` slots exists | FT-X-34; evidence: the Java table and the per-package notes in `_docs/03_implementation/batch_01_loop19_report.md` (no executable test: probe only) | Covered |
| AZ-2340 AC-1 | `flags(group(flag_byte(0), flag_bit(0,x)))` with only `x` packs `01010105` in C++ | FT-X-35; tests: C++ `flags_when_member_host_tests.cpp::lone_flag_bit_member_in_a_group_is_present` | Covered |
| AZ-2341 AC-1 | `run-suite.sh python` on a broken venv exits non-zero naming the venv, or rebuilds it | FT-X-36; tests: `.github/workflows/run-suite.test.sh` (5 checks), registered in the `scaffold` job of `test.yml` | Covered |
| AZ-2342 AC-1 | The five files (Rust 2, Java 1, C# 2) are split and each is below 400 lines | FT-X-37; evidence: line counts in `batch_01_loop19_report.md` (Java `Walker.java` 387, Rust 352 and 332, C# 210 and 299) | Covered |
| AZ-2342 AC-2 | Behavior unchanged: the same pass counts as before the split | FT-X-37, FT-P-01; evidence: C# 844 of 844, Rust 479 before and after, Java output identical | Covered |
| AZ-2354 AC-1 | A lone 65 535-character `utf8` under `times` 65 535 is refused naming `s` in under 1 s and 256 MB, no bytes: `s: the packet would be 16777477 bytes, above the limit of 16777216 bytes` | FT-X-38, FT-X-52; tests: TypeScript `pack-output-budget.test.ts` (AC-1, child process, RSS) with `support/lone-utf8-budget.ts`, Python `test_pack_output_budget.py::test_ac1_row1_*` (two tests, child process RSS), Java `PackBudgetTest.row1LoneUtf8UnderACappedTimes` (child JVM `LoneUtf8Budget`), C# `PackOutputBudgetTests.Ac1_*` (managed allocation under 256 MB, RSS 88 MB measured by the worker), Rust `pack_output_budget_tests.rs::ac1_row1_*` (time only; 35.5 MB measured by the worker); hostile `pack_lone_utf8_under_times_over_budget`; C++ skipped: caller buffer and fixed `Array`, no output budget | Covered |
| AZ-2354 AC-2 | 40 list items of `{n: 65535, k: 5}` are refused at the default (`k: ... 16777223 bytes ...`) and pack with `maxBytes` 33 554 432 (20 971 363 bytes) and unpack to the same row | FT-X-39; tests: TypeScript (AC-2, two tests), Python `test_ac2_row2_*`, `test_ac2_row3_*`, Java `PackBudgetTest.rows2And3AnElementThatHoldsATimes`, C# `PackOutputBudgetTests.Ac2_*` (dictionary and typed rows); hostile `pack_element_times_over_budget`; Rust skipped: a list element cannot hold a `times`; C++ skipped: no output budget | Covered |
| AZ-2354 AC-3 | A packet of exactly `maxBytes` packs (`013d00` + `61` x 61 at 64); one byte more is refused naming the member; the type byte counts (`maxBytes` 1 packs `01`) | FT-X-40, FT-X-51; tests: TypeScript (AC-3, three tests), Python `test_ac3_row4_*` to `test_ac3_row13_*`, Java `PackBudgetTest.rows4To13TheBoundaryIsExact`, C# `PackOutputBudgetTests.Ac3_*`, Rust `ac3_rows4_5_*` to `ac3_a_u2_is_named_by_its_first_slot`; C++ skipped: no output budget | Covered |
| AZ-2354 AC-4 | A 65-name round at count 65 535 (4 259 775 slots) is refused naming `m0` (`the rounds would hold 4194320 slots, above the limit of 4194304 slots`); packs and unpacks with `maxSlots` 4 259 775; slots are checked before bytes | FT-X-41; tests: TypeScript (AC-4, four tests), Python `test_ac4_row14_*` to `test_width_row25_*`, Java `PackBudgetTest.rows14To16SlotsAreChargedOnPack` to `rows22To25ScopeAndWidth`, C# `PackSlotBudgetTests.Ac4_*`, `Order_*`, `Scope_*`, `Width_*`, Rust `ac4_row14_*`, `ac4_rows15_16_*`, `order_rows18_to_21_*`; hostile `pack_slots_over_limit`; C++ skipped: fixed `Array`, no slot budget. Gap: the slot width differs between packages (Rust, Python empty group; loop 21 U2) and Python unpack surcharges 8 slots per name (loop 21 U1) | Covered |
| AZ-2354 AC-5 | `maxBytes` defaults to 16 777 216, a value below 1 or not an integer is refused like the other limits, existing calls compile unchanged | FT-X-42, FT-X-51; tests: TypeScript (AC-5, three tests), Python `test_ac5_row26_*` to `test_ac5_row28_*`, Java `PackBudgetTest.rows26To28TheLimitsApi`, C# `PackOutputBudgetTests.Ac5_Limits_*`, Rust `ac5_rows26_28_limits_api`, `ac5_row27_*`, `ac5_a_typed_scheme_carries_max_bytes` | Covered |
| AZ-2354 AC-6 | Golden, route and ring fixtures and every accepted row keep their bytes | FT-X-42, FT-P-01, FT-C-04; tests: TypeScript "AC-5 and AC-6 existing limit calls compile ...", C# `Ac6_Pack_LimitsRaisedByTheExistingCallForms_KeepTheBytes`, `PackSlotBudgetTests.Ac6_*`, Rust `ac6_a_when_and_flags_row_under_the_budget_keeps_its_bytes`, the golden and ring replay in every package suite. One accepted row is refused on purpose: a row above 16 MiB (raisable) | Covered |
| AZ-2355 AC-1 | A `repeat` list with `maxRounds + 1` entries is refused naming the member: `k: the repeat count is 65536, above the limit of 65535 rounds`; the member is the one whose list passes the limit | FT-X-43; tests: TypeScript `pack-repeat-round-cap.test.ts` (AC-1, three tests), Python `test_pack_repeat_round_cap.py::test_ac1_row1_*`, `test_row4_*` to `test_row10_*`, Java `RepeatRoundCapTest.rows1To3TheDefaultLimit`, `rows4To6TheMemberNamed`, `rows7To10EveryPlaceARepeatSits`, C# `PackRepeatRoundCapTests.Ac1_*` and the placement tests, Rust `pack_repeat_cap_tests.rs::ac1_row1_*`, `row6_*`, `rows7_8_9_*`; hostile `pack_repeat_over_limit`; Rust skips the list-element row; C++ skipped: fixed `Array` | Covered |
| AZ-2355 AC-2 | `maxRounds` entries pack in `maxRounds + 1` bytes (65 536) and round-trip | FT-X-43; tests: TypeScript (AC-2), Python `test_ac2_row2_*`, Java `rows1To3TheDefaultLimit`, C# `PackRepeatRoundCapTests.Ac2_*`, Rust `ac2_row2_*` | Covered |
| AZ-2355 AC-3 | With `maxRounds` 70 000, 70 000 entries pack (70 001 bytes) | FT-X-43; tests: TypeScript (AC-3), Python `test_ac3_row3_*`, Java `rows1To3TheDefaultLimit`, C# `Ac3_*`, Rust `ac3_row3_*` | Covered |
| AZ-2356 AC-1 | A split `times` whose count is written after the byte and is 0, with a list given, is refused naming the member in six | FT-X-44; tests: TypeScript `loop20-parity-pins.test.ts` (AZ-2356 AC-1), Python `test_loop20_parity_pins.py::test_az2356_ac1_*`, Java `ParityPinsTest.az2356CountZeroAfterTheByte`, C# `FlagsSkippedCountTests.Ac1_Pack_SplitCountZeroAfterTheByteWithAList_*`, Rust `loop20_parity_pins_tests.rs::az2356_ac1_*`, C++ `times_count_zero_host_tests.cpp::az2356_split_count_zero_after_the_byte`; hostile `pack_split_count_zero_after_byte_list`. Gap: Python and Java name the field by id; the C++ pin passes through the late rule (review C4) | Covered |
| AZ-2356 AC-2 | The same scheme with count 0 and a lone scalar packs zero rounds, `010000`, in six | FT-X-44; tests: as AC-1 (`az2356_ac2_*`, `Ac2_Pack_SplitCountZeroAfterTheByteWithALoneScalar_PacksZeroRounds`); hostile `pack_split_count_zero_after_byte_scalar` (`010000`); C++ checks the scalar-less row only (a typed row holds an `Array`); Python and Rust were fixed (they refused the scalar) | Covered |
| AZ-2357 AC-1 | C++ refuses the loop 19 U4 row (count set behind a clear `when`, packed `010003055a00`) with `BadValue` naming the `times` | FT-X-47; tests: C++ `split_form_loud_host_tests.cpp::count_set_behind_a_clear_when`, `late_source_host_tests.cpp::az2357_hold_over_255_is_refused_at_construction`; after review C2 also `bits`/`packed`/`sized` (`held_count_nested_late_host_tests.cpp::c2_*`). Gap: the same shape for `bits`/`packed`/`sized` is not probed in the other five (loop 21 U7); one accepted row now refused (plain `times`, count 0, no rounds) | Covered |
| AZ-2357 AC-2 | Arm stage: stack at most 512 B, flash at most 8 192 B, margins reported | FT-E-05, FT-X-47; evidence: `cpp-embedded` stage 0 failed, Cortex-M4F flash 8160 of 8192 B (margin 32 B) and stack 448 of 512 B (batch_01 and batch_04 reports). The flash margin is exhausted | Covered |
| AZ-2358 AC-1 | C# `Eq(u8, 5.0)` is refused at construction naming the `when` and the member | FT-X-48; tests: C# `EqValueConstructionTests.Construct_EqWholeFloatForAnIntegerSource_IsRefusedNamingTheWhenAndTheMember` | Covered |
| AZ-2358 AC-2 | Whole floats in `u2`/`bits`/`packed` slots are refused naming the member; `f64`/`f32` with 5.0 still pack. The plain integer fields part is AZ-2373 (loop 21) | FT-X-48; tests: C# `StrictSlotTests.Ac2_Pack_WholeFloatInASlot_ThrowsNamingTheMember`, `Ac2_Pack_WholeFloatInAFloatField_StillPacks` (`01` + `0000000000001440` + `0000a040`). Gap: the tests pack dictionary rows only; no test packs a whole float through a typed row | Covered |
| AZ-2359 AC-1 | The enum rule is pinned: Python `IntEnum` and TypeScript numeric enum pack the integer (`01c8`); C#, Java and Rust refuse (or take only the integer) | FT-X-48; tests: TypeScript `loop20-parity-pins.test.ts` (AZ-2359, two tests), Python `test_az2359_ac1_*` (three tests), Java `ParityPinsTest.az2359AnEnumIsNotANumber`, C# `EnumSlotValuesTests.*` (four tests), Rust `loop20_parity_pins_tests.rs::az2359_ac1_*` (two tests). README sentence is the docs agent's | Covered |
| AZ-2360 AC-1 | A combined `flags` with a skipped `times` count and values is refused naming `pt` with one text in six: `pt: a value is given, but the count of its times is not written, so its bit is clear; write the count before the times` | FT-X-45; tests: TypeScript `loop20-parity-pins.test.ts` (AZ-2360, four tests) and `split-form-loud-pack.test.ts`, Python `test_az2360_ac1_*`, Java `ParityPinsTest.az2360SkippedCountWithValuesIsLoud`, C# `FlagsSkippedCountTests.Ac1_*`, Rust `az2360_ac1_*` (four tests), C++ `split_form_loud_host_tests.cpp::flags_skipped_count_with_values`; hostile `pack_flags_skipped_count_with_values` | Covered |
| AZ-2360 AC-2 | No values (or `[]`) still packs `0100` | FT-X-45; tests: as AC-1 (`az2360_ac2_*`, `Ac2_Pack_SkippedCountWithNoValuesOrAnEmptyList_PacksTheBitClear`, C++ `flags_skipped_count_with_values`) | Covered |
| AZ-2361 AC-1 | Java refuses `BigDecimal` 1.5 in `u2`, `bits` and `packed` slots naming the field; `BigDecimal` 1 packs | FT-X-49; tests: Java `CountsFractionsSinkTest.ac1AFractionIsRefused` | Covered |
| AZ-2361 AC-2 | A u64 count above the int range in `sized` or `bits` is refused (no 12-byte packet) | FT-X-49; tests: Java `CountsFractionsSinkTest.ac2AU64CountAboveIntRange` | Covered |
| AZ-2361 AC-3 | `ByteSink` growth does not overflow; a typed refusal at the cap | FT-X-49; tests: Java `CountsFractionsSinkTest.ac3TheSinkGrowsWithoutOverflow`, `PackBudgetTest.growthStaysInsideTheArrayLimit` (the growth function is tested directly, not a 2 GiB sink) | Covered |
| AZ-2362 AC-1 | Python: a `repeat` with `[]` as a `flags` member packs like TypeScript, no bare `IndexError` | FT-X-46; tests: Python `test_loop20_parity_pins.py::test_az2362_*` (three tests) and the review B1 tests. Gap: TypeScript and Python differ on a short list in an optional flags position (loop 21 U3) | Covered |
| AZ-2363 AC-1 | TypeScript: a `times` in a `when` in a split bit with its count never written, with values, is refused naming the member | FT-X-46; tests: TypeScript `loop20-parity-pins.test.ts` (AZ-2363, two tests). Already refused since loop 19 review B2; closed as a pin | Covered |
| AZ-2364 AC-1 | C++: with two late `when`s in one bit, mode 2 and `b` given, pack returns `BadValue` naming `b` (HEAD `01010209`) | FT-X-47; tests: C++ `late_source_host_tests.cpp::az2364_every_late_when_of_a_bit_is_refused`, `az2364_link_over_255_is_refused_at_construction` | Covered |
| AZ-2364 AC-2 | Arm stage within the stack and flash budgets | FT-E-05, FT-X-47; evidence as AZ-2357 AC-2 (flash 8160 of 8192 B, stack 448 of 512 B) | Covered |
| AZ-2365 AC-1 | `LayoutTests.cs` (517) and `bound.rs` (514) are split under 500 lines; suites keep their counts | FT-X-52; evidence: `LayoutTests.cs` 201 + `LayoutCountedTests.cs` 323, `bound.rs` 357 + `bound_collections.rs` 164. Gap: no per-split pass count was recorded; the wave totals are in batch_02 | Covered |
| AZ-2366 AC-1 | C# typed unpack of `03 01 02` for `Repeat(0, U8 V)` (also `Times`, `Flags` member) returns a `ShortPacket` naming `V`, no exception | FT-X-50; tests: C# `TypedRoundUnpackTests.Ac1_*` (four tests) | Covered |
| AZ-2366 AC-2 | (corrected by review A1) A `List<int>` or `List<long>` in a `Repeat` or `Times` round is refused at construction naming the member; `List<List<object?>>`, `object[]`, `IList`, `object` build and bind | FT-X-50; tests: C# `TypedRoundUnpackTests.Ac2_*` (four tests), `RoundCollectionMemberTests.ListInARound_BuildsIfAndOnlyIfTypedUnpackBindsIt`, `ListOfScalarsInARound_IsRefusedNamingTheMember` | Covered |
| AZ-2367 AC-1 | The seven new hostile `pack` cases (file 33 to 40) are replayed by the six loaders with the expected outcome or a recorded skip | FT-X-52, FT-X-01, FT-X-04, FT-X-10; tests: `fixtures/hostile/check-cases.sh` (`hostile cases ok: 40`), `cases.test.sh`; loaders TypeScript `hostile.test.ts`, Python `hostile_support.py`, Java `HostileVectorTest.replayPack`, C# `HostilePackVectorTests.PackCase_ReturnsTheBytesOrRefuses`, Rust `hostile_tests.rs`, C++ `hostile_pack_cases.hpp`. Gap: four loaders assert refusal only (reviews B4, C5) | Covered |
| Review20 A1 | C# round collection check equals the unpack binding predicate (`List<int>`/`List<long>` refused, `List<List<object?>>` builds) | FT-X-50; tests: C# `RoundCollectionMemberTests.ListInARound_BuildsIfAndOnlyIfTypedUnpackBindsIt` (92 rows), `ListOfScalarsInARound_IsRefusedNamingTheMember`; 54 new rows fail on the HEAD sources | Covered |
| Review20 A2 | C# `object[]` and `IList` members in a round bind as before; a dict member in a round never throws | FT-X-50; tests: C# `RoundCollectionMemberTests.ObjectArrayInARound_BindsAsBefore`, `DictInARound_BindsOrReturnsTheErrorResultAndNeverThrows` | Covered |
| Review20 A4 | Rust: a combined `flags` with a skipped count and a stale `n: 0` is refused naming `pt` (`zero_given` only in the split form) | FT-X-45; tests: Rust `loop20_parity_pins_tests.rs::review20_a4_*` (three tests) | Covered |
| Review20 A8 | C# `PackOut` refuses with the member name before an `int` overflow; effective cap `min(maxBytes, 0x7FFFFFC7)` | FT-X-51; tests: C# `PackOutCapTests.*` (four tests) | Covered |
| Review20 B1 | Python: a required leaf with an empty list is `KeyError 'missing field w'`, never a bare `IndexError` | FT-X-46; tests: Python `test_loop20_parity_pins.py::test_review_b1_*` (three tests) | Covered |
| Review20 B3 | Python row 16 pins `ShortPacket(field='1', needed=0, left=66040)` | FT-X-41; tests: Python `test_pack_output_budget.py::test_ac4_row16_the_same_packet_is_refused_by_unpack_at_the_default_limit` (passes on HEAD; assertion tightened) | Covered |
| Review20 C1 | C++: a late `when`/`times` nested in a `when` or `flags` inside the bit is refused | FT-X-47; tests: C++ `held_count_nested_late_host_tests.cpp::c1_late_when_in_a_when_is_refused`, `c1_late_when_in_flags_is_refused`, `c1_late_times_in_a_when_is_refused` (9 checks fail on HEAD) | Covered |
| Review20 C2 | C++: a `bits`/`packed`/`sized` count behind a clear `when` is refused (`010005`) | FT-X-47; tests: C++ `held_count_nested_late_host_tests.cpp::c2_*` (four tests) | Covered |
| Review20 C3 | C++: a `times` in the same `when` that holds its count has no 255-entry limit | FT-X-47; tests: C++ `held_count_nested_late_host_tests.cpp::c3_times_inside_the_holding_when_has_no_limit` | Covered |

## Restrictions Coverage

| Restriction ID | Restriction | Test IDs | Coverage |
|---------------|-------------|----------|----------|
| R-01 | Library only. No server and no GPU | NFT-RES-LIM-01 | Covered |
| R-02 | Runs on the language runtime's host | FT-P-03 | Covered |
| R-03 | First publish is the six languages | FT-P-03, FT-P-08 | Covered |
| R-04 | Current .NET LTS and current Node LTS at first publish | FT-P-08 | Covered |
| R-05 | Kotlin is not in the first publish | FT-N-04 | Covered |
| R-06 | Vue and React use the TypeScript package | FT-P-08 | Covered |
| R-07 | No code generator in the first release | FT-P-08 | Covered |
| R-08 | No tag, length prefix, version byte, or schema id | FT-P-01 | Covered |
| R-09 | Public registry, not GitHub Packages | FT-P-08, FT-P-10 | Covered |
| R-10 | License is MIT | FT-P-08 | Covered |
| R-11 | No calendar deadline | — | WAIVED — the interview set no date, so there is no date to test |
| R-12 | No budget figure | — | WAIVED — no budget number was set |
| R-13 | Source is https://github.com/zxsanny/packbin | FT-P-09 | Covered |
| R-14 | CI runs on every push and pull request | FT-P-09 | Covered |
| R-15 | A version tag publishes each language in that commit | FT-P-08, FT-P-10 | Covered |
| R-16 | The first tag publishes the six packages together | FT-P-08 | Covered |
| R-17 | Later registries publish only when that language is in the tree | FT-N-04 | Covered |
| R-18 | A language absent from the tree is not published | FT-N-04 | Covered |
| R-19 | Registry credentials stay in the CI secret store | NFT-SEC-01 | Covered |

## Coverage Summary

| Category | Total Items | Covered | BLOCKED | WAIVED | Coverage |
|----------|-----------|---------|---------|--------|----------|
| Acceptance Criteria | 284 | 283 | 1 | 0 | every row Covered or WAIVED, except AZ-2220 AC-9 (not verified, see below) |
| Restrictions | 19 | 17 | 0 | 2 | every row Covered or WAIVED |
| **Total** | 303 | 300 | 1 | 2 | one row not verified |

## Uncovered Items Analysis

| Item | Status | Reason | Risk | Mitigation |
|------|--------|--------|------|-----------|
| R-11 | WAIVED | No calendar date was set | A release could slip with no alarm | The first publish is gated by the golden hex, not a date |
| R-12 | WAIVED | No budget number was set | None for a $0 library | Revisit if a paid service is added |
| AZ-2220 AC-9 | BLOCKED — not verified | The spec asks for a Loop 15 block in the security docs; later summaries replaced it and the security docs belong to the security step | The F10 and F11 outcome could be misread | Security agent confirms the status in `_docs/05_security/` |
| AZ-2373 AC-1 to AC-3 | NOT STARTED (loop 21) | C# exact integer types from unpack, whole floats refused for u8 to i64, repack tests: the spec is written (`todo/AZ-2373`), no code, no test; owner decision 2026-10-11 (document now, fix in loop 21) | A C# integer field accepts `5.0`; unpack returns narrow integers as `double` | README documents it; the fix is in the loop 21 hopper |
| AZ-2358 AC-2, typed rows | Gap | `StrictSlotTests` packs dictionary rows only | A typed row with a `double` member in a `u2`/`bits`/`packed` slot is unpinned | Add a typed-row case in a loop 21 test task |

## Loops 11 to 18: specs with no AC rows yet (Not verified)

Step 12 of loop 19 added AC rows for the specs the handoff named (AZ-2088, AZ-2191, AZ-2216 to AZ-2220) and for loop 19. The specs below closed in loops 11 to 18 (they appear in a `batch_*_loop11` to `batch_*_loop18` report) and still have no AC row. This is a pointer for a later sync, not coverage: a row is added only when each AC is mapped to a test name read in the package. Their behavior is partly described by FT-X-01 to FT-X-21. The AC count is the number of `**AC-n` headings in the spec.

### With a test file that cites the task id (file level only, ACs not mapped)

| Spec | Name | ACs | Files that cite the id |
|------|------|-----|------------------------|
| AZ-2072 | TypeScript hostile-packet unpack | 7 | `typescript/tests/support/hostile-cases.ts` |
| AZ-2074 | Java hostile-packet unpack | 6 | `java/src/test/java/packbin/HostileUnpackTest.java`, `java/src/test/java/packbin/HostileVectorTest.java` |
| AZ-2077 | Java thread-safe flags unpack | 5 | `java/src/test/java/packbin/FlagStateTest.java` |
| AZ-2084 | TypeScript numeric range check on pack | 6 | `fixtures/hostile/README.md` |
| AZ-2085 | Rust typed-scheme integrity | 6 | `java/src/test/java/packbin/EqBoolTrueOnlyTest.java` |
| AZ-2087 | C# reference scope check | 5 | `.github/workflows/language-pair.sh`, `fixtures/hostile/README.md` |
| AZ-2089 | Java reference scope and bool placement | 8 | `java/src/test/java/packbin/BoolPlacementTest.java`, `java/src/test/java/packbin/FlagStateTest.java`, `java/src/test/java/packbin/HostileUnpackTest.java`, `java/src/test/java/packbin/HostileVectorTest.java`, `java/src/test/java/packbin/ReferenceScopeTest.java` and 2 more |
| AZ-2090 | TypeScript `when`/count reference resolution | 6 | `fixtures/hostile/README.md` |
| AZ-2091 | TypeScript nested-group structure fixes | 7 | `.github/workflows/language-pair.sh` |
| AZ-2092 | C# typed binding per scope | 8 | `.github/workflows/language-pair.sh`, `csharp/tests/TypedBindingTests.cs`, `csharp/tests/TypedParityTests.cs` |
| AZ-2093 | C# honest AC-10 test | 3 | `csharp/tests/Ac10TimingTests.cs` |
| AZ-2094 | Java 17 / Android API 26 artifact | 6 | `java/src/test/java/packbin/ApiSafeReplacementsTest.java` |
| AZ-2095 | Publish gated on test.yml | 6 | `.github/workflows/publish-gate.test.sh` |
| AZ-2096 | Two-phase publish (build, then upload) | 6 | `.github/workflows/publish-phases.test.sh` |
| AZ-2097 | Re-runnable publish with declared required registries | 7 | `.github/workflows/publish-rerun.test.sh` |
| AZ-2098 | Buildable vcpkg port with consumer check | 5 | `.github/workflows/publish-vcpkg.test.sh` |
| AZ-2101 | Java typed nested rows | 6 | `java/src/test/java/packbin/TypedNestedRowTest.java` |
| AZ-2102 | TypeScript group/flags as list and dict elements | 6 | `.github/workflows/drivers/HandoffElements.java`, `.github/workflows/drivers/handoff.py`, `.github/workflows/drivers/handoff.ts`, `.github/workflows/language-pair.sh` |
| AZ-2103 | npm package as JavaScript + .d.ts | 6 | `.github/workflows/publish-npm.test.sh` |
| AZ-2110 | Java zero-width elements and orphan flag bits | 5 | `java/src/test/java/packbin/ZeroWidthElementTest.java` |
| AZ-2113 | Python refuses when and count names that point to a later field | 4 | `fixtures/hostile/README.md`, `python/tests/test_bool_placement.py`, `python/tests/test_zero_width_elements.py` |
| AZ-2114 | Hostile session unpack tests for C#, Java and Rust | 2 | `csharp/tests/HostileSessionTests.cs`, `java/src/test/java/packbin/HostileSessionTest.java`, `rust/src/session_hostile_tests.rs` |
| AZ-2115 | Pin the split-form reference bytes in TypeScript and C# tests | 1 | `csharp/tests/SplitFormReferenceTests.cs`, `typescript/tests/split-form-reference.test.ts` |
| AZ-2119 | C# group as list or dict element throws KeyNotFoundException on unpack | 3 | `.github/workflows/drivers/csharp/HandoffElements.cs`, `csharp/tests/GroupElementTests.cs` |
| AZ-2121 | Orphan flag-bit tests for every container | 4 | `csharp/tests/FlagScopeContainerTests.cs`, `java/src/test/java/packbin/FlagScopeContainerTest.java` |
| AZ-2127 | Java nested rounds | 4 | `java/src/test/java/packbin/HostileUnpackTest.java`, `java/src/test/java/packbin/NestedRoundTest.java`, `java/src/test/java/packbin/RepeatRoundTest.java` |
| AZ-2131 | Java empty group refused | 4 | `java/src/test/java/packbin/BoolPlacementTest.java`, `java/src/test/java/packbin/FlagStateTest.java`, `java/src/test/java/packbin/TypedNestedRowTest.java` |
| AZ-2133 | Rust and C++ bitwhen | 2 | `.github/workflows/out/artifacts/rust/stage/src/flag_presence_tests.rs`, `rust/src/flag_presence_tests.rs` |
| AZ-2134 | Aligned round values | 4 | `.github/workflows/language-pair.sh`, `fixtures/hostile/README.md` |
| AZ-2147 | C++ empty group without member | 2 | `cpp/tests/core/scheme_tests.cpp` |
| AZ-2179 | Rounds ring in `language-pair.sh` | 4 | `fixtures/hostile/README.md` |
| AZ-2180 | C# scheme clones its flag-bit groups | 5 | `csharp/tests/FlagGroupCopyTests.cs` |
| AZ-2181 | C# count source is an integer field | 4 | `csharp/tests/CountKindTests.cs`, `csharp/tests/CountOverflowTests.cs`, `csharp/tests/EqBoolTrueOnlyTests.cs`, `csharp/tests/HostileUnpackTests.Counts.cs` |
| AZ-2182 | C# lone value in a round | 7 | `csharp/tests/LoneRoundValueTests.cs` |
| AZ-2185 | TypeScript `times` list longer than the count is an error | 6 | `fixtures/hostile/README.md` |
| AZ-2186 | Python `times` list longer than the count is an error | 6 | `fixtures/hostile/README.md` |
| AZ-2187 | Java `times` list longer than count is refused | 6 | `fixtures/hostile/README.md`, `java/src/test/java/packbin/TimesLongerTest.java` |
| AZ-2188 | TypeScript duplicate member names refused at construction | 7 | `typescript/tests/nested-group.test.ts`, `typescript/tests/round-values.test.ts` |
| AZ-2190 | Java pack range and type check for integers and floats | 7 | `java/src/test/java/packbin/PackStrictTest.java` |
| AZ-2193 | `language-pair.sh` in CI | 7 | `.github/workflows/ring-wiring.test.sh` |
| AZ-2214 | Pin actions by commit and tools by exact version (F12) | 8 | `.github/workflows/publish-pins.test.sh` |
| AZ-2215 | Read-only repo mount for the publish containers (F13) | 8 | `.github/workflows/publish-readonly.test.sh` |
| AZ-2230 | Python numbers split bits by scheme order | 10 | `fixtures/hostile/README.md` |
| AZ-2232 | vcpkg port limited to Linux and macOS, `find_package` version rule "same minor" for 0.x | 6 | `.github/workflows/publish-vcpkg.test.sh` |
| AZ-2233 | Java nested row: a flag bit with no flag byte inside the row is refused at construction | 6 | `java/src/test/java/packbin/SplitBitOrderTest.java` |
| AZ-2234 | Java pack: missing nested rows and null group elements throw, `u2` honours the round item | 9 | `java/src/test/java/packbin/FlagPresenceTest.java`, `java/src/test/java/packbin/MissingNestedValueTest.java`, `java/src/test/java/packbin/PackStrictTest.java`, `java/src/test/java/packbin/RepeatRoundTest.java` |
| AZ-2235 | Java typed rows: a list or dict element nested-row group without a factory is refused at construction | 6 | `java/src/test/java/packbin/TypedElementScopeTest.java`, `java/src/test/java/packbin/TypedNestedRowTest.java` |
| AZ-2237 | Rust pack reads what it wrote | 8 | `rust/src/when_kept_tests.rs` |
| AZ-2238 | Three harness fixes: `publish-position.sh` installs with `cd` + `npm ci`, `examples.sh` captures `find` output before it picks the first line, `language-pair.sh` names a failing consumer | 5 | `.github/workflows/publish-gate.test.sh`, `.github/workflows/publish-position.test.sh`, `.github/workflows/ring-wiring.test.sh` |
| AZ-2239 | `listgroup` ring in `language-pair.sh` for the packages that support the shapes | 6 | `.github/workflows/drivers/HandoffElements.java`, `.github/workflows/drivers/csharp/HandoffElements.cs`, `.github/workflows/drivers/handoff.py`, `.github/workflows/drivers/handoff.ts`, `.github/workflows/language-pair.sh` |
| AZ-2240 | `publish-check.py` checks `exports`, `types` and the dist modules of the npm tarball, and the CMake file, LICENSE and host dependencies of the vcpkg port | 6 | `.github/workflows/publish-npm.test.sh`, `.github/workflows/publish-vcpkg.test.sh` |
| AZ-2243 | TypeScript `PackSession.load` takes only a `Uint8Array` seed | 6 | `typescript/tests/session.test.ts` |
| AZ-2246 | Java duplicate member names refused at construction | 11 | `java/src/test/java/packbin/DuplicateNamesTest.java` |

### No test or fixture file cites the id (Not verified: tests may exist under another name)

| Spec | Name | ACs |
|------|------|-----|
| AZ-2071 | Python hostile-packet unpack | 7 |
| AZ-2073 | C# hostile-packet unpack | 6 |
| AZ-2075 | Rust hostile-packet unpack | 5 |
| AZ-2076 | C# thread-safe flags unpack | 5 |
| AZ-2079 | C# bool presence and 9th flag bit | 8 |
| AZ-2080 | TypeScript bool presence and flag-bit limit | 8 |
| AZ-2082 | Rust flag bits and bool rule | 5 |
| AZ-2083 | Python bool placement and flag-bit limit | 5 |
| AZ-2086 | Rust typed times | 6 |
| AZ-2099 | Embedded harness fails a target on any failed command | 6 |
| AZ-2100 | Python split form and repeat/times fixes | 9 |
| AZ-2104 | Python seed check and safe star-import | 5 |
| AZ-2105 | Rust session pack error | 4 |
| AZ-2107 | Python zero-width elements | 4 |
| AZ-2108 | TypeScript zero-width elements and orphan flag bits | 5 |
| AZ-2109 | C# zero-width elements and orphan flag bits | 5 |
| AZ-2111 | Rust zero-width elements and orphan flag bits | 5 |
| AZ-2112 | TypeScript accepts u64 counts for sized, packed and times | 3 |
| AZ-2116 | C# unpack returns exact integer types | 2 |
| AZ-2117 | Rust scope check covers name-based references | 4 |
| AZ-2118 | Rust pack borrowed_count uses checked_add | 1 |
| AZ-2122 | TypeScript __proto__ dict key, when-in-repeat round scope, BOM kept | 4 |
| AZ-2123 | C# top-range u64/i64 overflow, capacity reserve, atomic session counter | 4 |
| AZ-2124 | Java atomic PackSession send counter | 2 |
| AZ-2125 | Rust cap collection capacity at the bytes left | 2 |
| AZ-2129 | TypeScript constructor checks | 4 |
| AZ-2130 | C# empty nested-row group | 4 |
| AZ-2132 | Python empty group refused | 3 |
| AZ-2175 | C# `when` reads what pack wrote | 7 |
| AZ-2176 | C# nested rounds refused at construction | 3 |
| AZ-2177 | TypeScript nested rounds refused at construction | 4 |
| AZ-2178 | Rust typed `times` shape pins | 7 |
| AZ-2183 | TypeScript pack finds flags under a split bit and inside flags | 7 |
| AZ-2184 | TypeScript dict entries stay out of the row's members | 7 |
| AZ-2189 | Rust map `times` refuses a per-name value it cannot align | 4 |
| AZ-2192 | Python float fields accept only numbers and name the field on overflow | 6 |
| AZ-2197 | TypeScript `when` reads what pack wrote | 6 |
| AZ-2231 | Python `PackSession.load` takes only a bytes-like seed | 5 |
| AZ-2236 | TypeScript refuses an anchored group as a list or dict element when the scheme is built | 7 |
| AZ-2244 | Python `PackSession.start` and `join` take only a bytes-like nonce | 9 |
| AZ-2245 | Python duplicate member names refused at construction | 10 |
| AZ-2247 | Rust duplicate data member names refused at construction | 11 |
| AZ-2248 | Python `times` short or empty list for a member under `flags` | 8 |
| AZ-2249 | Python refuses an attribute-style accessor inside a `list` or `dict` element group when the scheme is built | 10 |


<!-- autodev-step5-post-architecture-pass: 2026-09-22 -->
<!-- autodev-step12-loop-update: loop 18, 2026-10-11, 53 rows added (AZ-2120, 2126, 2128, 2135, 2194, 2304-2311) -->
<!-- autodev-step12-loop-update: loop 19, 2026-10-11, 57 AC rows added (AZ-2088, 2191, 2216-2220 catch-up; AZ-2329-2342); 97 loop 11-18 specs listed as not verified -->
<!-- autodev-step12-loop-update: loop 20, 2026-10-12, 38 AC rows added (AZ-2354 to AZ-2367 29 rows, review20 A1 A2 A4 A8 B1 B3 C1 C2 C3 9 regression rows); AZ-2373 listed as not started -->
