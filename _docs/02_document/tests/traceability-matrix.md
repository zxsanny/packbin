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
| Acceptance Criteria | 189 | 189 | 0 | 0 | every row Covered or WAIVED |
| Restrictions | 19 | 17 | 0 | 2 | every row Covered or WAIVED |
| **Total** | 208 | 206 | 0 | 2 | every row Covered or WAIVED |

## Uncovered Items Analysis

| Item | Status | Reason | Risk | Mitigation |
|------|--------|--------|------|-----------|
| R-11 | WAIVED | No calendar date was set | A release could slip with no alarm | The first publish is gated by the golden hex, not a date |
| R-12 | WAIVED | No budget number was set | None for a $0 library | Revisit if a paid service is added |

<!-- autodev-step5-post-architecture-pass: 2026-09-22 -->
<!-- autodev-step12-loop-update: loop 18, 2026-10-11, 53 rows added (AZ-2120, 2126, 2128, 2135, 2194, 2304-2311) -->
