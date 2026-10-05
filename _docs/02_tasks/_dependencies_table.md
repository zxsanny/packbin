# Dependencies Table

**Date**: 2026-10-04
**Total Tasks**: 87
**Total Complexity Points**: 294

Estimation: `_docs/LESSONS.md` says the six packages stay peers. The session is implemented in each package. No shared walker. Compare the full hex. No point bump.

| Task | Name | Complexity | Dependencies | Epic |
|------|------|-----------|-------------|------|
| AZ-1866 | initial_structure | 5 | None | AZ-1858 |
| AZ-1876 | csharp_pack | 5 | AZ-1866 | AZ-1859 |
| AZ-1877 | typescript_pack | 5 | AZ-1866 | AZ-1860 |
| AZ-1878 | python_pack | 5 | AZ-1866 | AZ-1861 |
| AZ-1879 | rust_pack | 5 | AZ-1866 | AZ-1862 |
| AZ-1880 | cpp_pack | 5 | AZ-1866 | AZ-1863 |
| AZ-1881 | java_pack | 5 | AZ-1866 | AZ-1864 |
| AZ-1875 | pipeline_publish | 5 | AZ-1876, AZ-1877, AZ-1878, AZ-1879, AZ-1880, AZ-1881 | AZ-1858 |
| AZ-1913 | test_infrastructure | 3 | None | AZ-1865 |
| AZ-1919 | position_bytes | 5 | AZ-1913 | AZ-1865 |
| AZ-1920 | flags_short | 5 | AZ-1913 | AZ-1865 |
| AZ-1921 | groups | 3 | AZ-1913 | AZ-1865 |
| AZ-1922 | speed | 3 | AZ-1913 | AZ-1865 |
| AZ-1923 | tag_gate | 5 | AZ-1913 | AZ-1865 |
| 01_flag_group | flag_group | 5 | AZ-1876, AZ-1877, AZ-1878, AZ-1879, AZ-1880, AZ-1881 | pending |
| 02_length_prefixed_bytes | length_prefixed_bytes | 3 | AZ-1876, AZ-1877, AZ-1878, AZ-1879, AZ-1880, AZ-1881 | pending |
| 03_counted_bit_pack | counted_bit_pack | 5 | AZ-1876, AZ-1877, AZ-1878, AZ-1879, AZ-1880, AZ-1881 | pending |
| AZ-1938 | utf8_string | 3 | AZ-1876, AZ-1877, AZ-1878, AZ-1879, AZ-1880, AZ-1881 | AZ-1937 |
| AZ-1939 | counted_list | 5 | AZ-1938 | AZ-1937 |
| AZ-1940 | dictionary | 5 | AZ-1938, AZ-1939 | AZ-1937 |
| AZ-1941 | language_pair_e2e | 5 | AZ-1940 | AZ-1937 |
| AZ-1945 | type_number | 5 | AZ-1876, AZ-1877, AZ-1878, AZ-1879, AZ-1880, AZ-1881 | pending |
| AZ-1946 | scheme | 8 | AZ-1945 | pending |
| AZ-1949 | scheme_dispatch | 8 | AZ-1946 | pending |
| AZ-1950 | field_id_binding | 8 | AZ-1949 | pending |
| AZ-1963 | python_single_accessor | 3 | AZ-1950 | AZ-1861 |
| 04_borrowed_count | borrowed_count | 8 | AZ-1950 | pending |
| AZ-2010 | csharp_anchor | 3 | None | AZ-1859 |
| AZ-2011 | typescript_anchor | 3 | None | AZ-1860 |
| AZ-2012 | python_anchor | 3 | None | AZ-1861 |
| AZ-2013 | rust_scheme_order | 5 | None | AZ-1862 |
| AZ-2014 | cpp_anchor | 3 | None | AZ-1863 |
| AZ-2015 | java_anchor | 3 | None | AZ-1864 |
| AZ-2016 | order_sentence | 1 | None | AZ-1865 |
| AZ-2019 | csharp_session | 5 | None | AZ-2018 |
| AZ-2020 | typescript_session | 3 | AZ-2019 | AZ-2018 |
| AZ-2021 | python_session | 3 | AZ-2019 | AZ-2018 |
| AZ-2022 | rust_session | 3 | AZ-2019 | AZ-2018 |
| AZ-2023 | cpp_session | 3 | AZ-2019 | AZ-2018 |
| AZ-2024 | java_session | 3 | AZ-2019 | AZ-2018 |
| AZ-2025 | session_match | 3 | AZ-2019, AZ-2020, AZ-2021, AZ-2022, AZ-2023, AZ-2024 | AZ-2018 |
| AZ-2026 | readme_session | 2 | AZ-2019 | AZ-2018 |
| AZ-2060 | cpp_core_scalars | 3 | None | AZ-2059 |
| AZ-2061 | cpp_core_schemes | 5 | AZ-2060 | AZ-2059 |
| AZ-2062 | cpp_core_grouped_kinds | 3 | AZ-2061 | AZ-2059 |
| AZ-2063 | cpp_core_counted_kinds | 5 | AZ-2061 | AZ-2059 |
| AZ-2065 | cpp_core_session | 2 | AZ-2061 | AZ-2059 |
| AZ-2064 | cpp_host_on_core | 5 | AZ-2062, AZ-2063, AZ-2065 | AZ-2059 |
| AZ-2066 | cpp_target_ci | 3 | AZ-2062, AZ-2063, AZ-2065 | AZ-2059 |
| AZ-2067 | cpp_embedded_packaging | 3 | AZ-2066 | AZ-2059 |
| AZ-2068 | cpp_avr_build | 3 | AZ-2066 | AZ-2059 |
| AZ-2070 | hostile_vectors | 1 | None | AZ-2069 |
| AZ-2071 | python_hostile_unpack | 2 | AZ-2070 | AZ-2069 |
| AZ-2072 | typescript_hostile_unpack | 2 | AZ-2070 | AZ-2069 |
| AZ-2073 | csharp_hostile_unpack | 2 | AZ-2070 | AZ-2069 |
| AZ-2074 | java_hostile_unpack | 2 | AZ-2070 | AZ-2069 |
| AZ-2075 | rust_hostile_unpack | 2 | AZ-2070 | AZ-2069 |
| AZ-2076 | csharp_unpack_state_per_call | 2 | None | AZ-2069 |
| AZ-2077 | java_unpack_state_per_call | 2 | None | AZ-2069 |
| AZ-2078 | cpp_flag_byte_scope | 2 | AZ-2070 | AZ-2069 |
| AZ-2079 | csharp_bool_rule_flag_limit | 2 | AZ-2070, AZ-2076 | AZ-2069 |
| AZ-2080 | typescript_bool_flag_limit | 2 | AZ-2072 | AZ-2069 |
| AZ-2081 | cpp_bool_u2_construction | 1 | AZ-2078 | AZ-2069 |
| AZ-2082 | rust_flag_bits_bool | 2 | AZ-2075 | AZ-2069 |
| AZ-2083 | python_bool_flag_limit | 1 | AZ-2071 | AZ-2069 |
| AZ-2084 | typescript_int_range | 2 | AZ-2080 | AZ-2069 |
| AZ-2085 | rust_typed_scheme_integrity | 3 | AZ-2082, AZ-2075 | AZ-2069 |
| AZ-2086 | rust_typed_times_vec | 3 | AZ-2085, AZ-2075 | AZ-2069 |
| AZ-2087 | csharp_forward_refs | 5 | AZ-2070, AZ-2079 | AZ-2069 |
| AZ-2088 | csharp_pack_fails_loudly | 3 | AZ-2087, AZ-2079 | AZ-2069 |
| AZ-2089 | java_forward_refs_bool | 2 | AZ-2070, AZ-2077, AZ-2074 | AZ-2069 |
| AZ-2090 | typescript_reference_scope | 3 | AZ-2072, AZ-2080 | AZ-2069 |
| AZ-2091 | typescript_nested_flags_names | 6 | AZ-2080, AZ-2090 | AZ-2069 |
| AZ-2092 | csharp_scoped_binding | 5 | AZ-2088, AZ-2079, AZ-2076 | AZ-2069 |
| AZ-2093 | csharp_ac10_public_path | 1 | AZ-2092 | AZ-2069 |
| AZ-2094 | java_release_17 | 2 | AZ-2096 | AZ-2069 |
| AZ-2095 | publish_after_tests | 2 | AZ-2070 | AZ-2069 |
| AZ-2096 | publish_build_before_upload | 3 | AZ-2094, AZ-2095 | AZ-2069 |
| AZ-2097 | publish_rerun_and_registry_policy | 3 | AZ-2096 | AZ-2069 |
| AZ-2098 | vcpkg_port_builds | 3 | AZ-2096 | AZ-2069 |
| AZ-2099 | embedded_errexit | 2 | None | AZ-2069 |
| AZ-2100 | python_split_form_repeat | 3 | AZ-2071, AZ-2083 | AZ-2069 |
| AZ-2101 | java_typed_nested_rows | 3 | AZ-2089, AZ-2077, AZ-2074 | AZ-2069 |
| AZ-2102 | typescript_list_group_elements | 3 | AZ-2090, AZ-2091 | AZ-2069 |
| AZ-2103 | typescript_npm_javascript | 3 | None | AZ-2069 |
| AZ-2104 | python_session_star_import | 1 | None | AZ-2069 |
| AZ-2105 | rust_session_pack_error | 1 | None | AZ-2069 |
| AZ-2107 | python_zero_width_elements | 2 | None | AZ-2069 |
| AZ-2108 | typescript_zero_width_elements | 3 | None | AZ-2069 |
| AZ-2109 | csharp_zero_width_elements | 3 | None | AZ-2069 |
| AZ-2110 | java_zero_width_elements | 3 | None | AZ-2069 |
| AZ-2111 | rust_zero_width_elements | 3 | None | AZ-2069 |
| AZ-2112 | typescript_u64_counts | 2 | AZ-2072 | AZ-2069 |
| AZ-2113 | python_later_field_refs | 3 | None | AZ-2069 |
| AZ-2114 | hostile_session_tests | 2 | None | AZ-2069 |
| AZ-2115 | split_form_reference_bytes | 2 | AZ-2091 | AZ-2069 |
| AZ-2116 | csharp_exact_integers | 3 | None | AZ-2069 |
| AZ-2117 | rust_named_reference_scope | 4 | AZ-2075 | AZ-2069 |
| AZ-2118 | rust_pack_checked_count | 1 | None | AZ-2069 |
| AZ-2119 | csharp_group_list_element | 3 | None | AZ-2069 |
| AZ-2120 | csharp_when_under_flags_pack | 2 | None | AZ-2069 |
| AZ-2121 | flag_scope_container_tests | 2 | None | AZ-2069 |
| AZ-2122 | typescript_proto_key_when_scope_bom | 3 | None | AZ-2069 |
| AZ-2123 | csharp_top_range_ints_capacity_session_counter | 3 | None | AZ-2069 |
| AZ-2124 | java_atomic_session_counter | 2 | None | AZ-2069 |
| AZ-2125 | rust_capacity_hint_bounded | 1 | None | AZ-2069 |
| AZ-2126 | eq_bool_true_only | 3 | AZ-2079, AZ-2080, AZ-2082, AZ-2083, AZ-2089 | AZ-2069 |
| AZ-2127 | java_nested_rounds | 3 | AZ-2089 | AZ-2069 |
| AZ-2128 | flag_group_presence_parity | 3 | AZ-2079, AZ-2082, AZ-2089 | AZ-2069 |
| AZ-2129 | typescript_constructor_checks | 2 | AZ-2080 | AZ-2069 |
| AZ-2130 | csharp_empty_nested_row | 2 | AZ-2079 | AZ-2069 |
| AZ-2131 | java_empty_group_refused | 2 | AZ-2089 | AZ-2069 |
| AZ-2132 | python_empty_group_refused | 1 | AZ-2083 | AZ-2069 |
| AZ-2133 | rust_cpp_bitwhen | 1 | AZ-2082 | AZ-2069 |
| AZ-2134 | aligned_round_values | 2 | AZ-2083, AZ-2087, AZ-2091 | AZ-2069 |
| AZ-2135 | split_bits_field_order | 5 | AZ-2079, AZ-2080, AZ-2089 | AZ-2069 |
| AZ-2147 | cpp_empty_group_without_member | 1 | AZ-2081 | AZ-2069 |
| AZ-2175 | csharp_when_on_written_values | 5 | AZ-2087, AZ-2088 | AZ-2069 |
| AZ-2176 | csharp_nested_round_refused | 2 | AZ-2175, AZ-2087, AZ-2088 | AZ-2069 |
| AZ-2177 | typescript_nested_round_refused | 3 | AZ-2090, AZ-2091 | AZ-2069 |
| AZ-2178 | rust_typed_times_pins | 1 | AZ-2086 | AZ-2069 |
| AZ-2179 | rounds_ring | 5 | AZ-2087, AZ-2091, AZ-2086, AZ-2175 | AZ-2069 |
| AZ-2180 | csharp_flag_group_clone | 2 | AZ-2087, AZ-2088 | AZ-2069 |
| AZ-2181 | csharp_count_integer_only | 2 | AZ-2087 | AZ-2069 |
| AZ-2182 | csharp_nonlist_round_value | 2 | AZ-2087, AZ-2088 | AZ-2069 |
| AZ-2183 | typescript_flags_under_split_bit | 2 | AZ-2091, AZ-2128 | AZ-2069 |
| AZ-2184 | typescript_dict_keys_not_flattened | 2 | AZ-2091 | AZ-2069 |
| AZ-2185 | typescript_times_list_longer | 1 | AZ-2091 | AZ-2069 |
| AZ-2186 | python_times_list_longer | 1 | AZ-2083 | AZ-2069 |
| AZ-2187 | java_times_list_longer | 1 | AZ-2089 | AZ-2069 |
| AZ-2188 | typescript_duplicate_member_names | 1 | AZ-2091 | AZ-2069 |
| AZ-2189 | rust_map_times_list_under_flags | 1 | AZ-2086 | AZ-2069 |
| AZ-2190 | java_pack_integer_float_strict | 1 | AZ-2089 | AZ-2069 |
| AZ-2191 | csharp_dict_pack_strict | 1 | AZ-2088 | AZ-2069 |
| AZ-2192 | python_float_pack_strict | 1 | AZ-2083 | AZ-2069 |
| AZ-2193 | ci_cross_language_ring | 3 | AZ-2179 | AZ-2069 |
| AZ-2194 | hostile_pack_stage | 2 | AZ-2070, AZ-2179 | AZ-2069 |
| AZ-2197 | typescript_when_on_written_values | 3 | AZ-2091, AZ-2177 | AZ-2069 |

The six pack tasks do not depend on each other. AZ-1875 runs after all six. The five blackbox tasks run after AZ-1913 and do not depend on each other. The three earlier todo tasks do not depend on each other and still have no tracker id. AZ-1938 through AZ-1941 are under epic AZ-1937. The string count does not include itself; the list count does not consume the next field.

AZ-2060 through AZ-2068 are under epic AZ-2059 (C++ on microcontrollers). All nine touch only `cpp/` and the C++ CI and publish files, so they run in order, not in parallel. The session task depends on the scheme task, not only on the scalars, because it packs through a core scheme. The host port (AZ-2064) waits for the session so the old walker is deleted once. AZ-2068 is a stretch task (D-3 A). Estimation: `_docs/LESSONS.md` asks to keep the six packages as peers; this feature is C++ only, so no point bump.

AZ-2070 through AZ-2105 are under epic AZ-2069 (cross-language bug fixes; order and severity in `_docs/04_refactoring/02-whole-project-assessment/analysis/bugfix_task_plan.md`). Loop 10 claims only AZ-2070, AZ-2078 and AZ-2081; the rest are loop 11 onward. A task that lists a dependency on another AZ-2069 task in the same package lands after it.

AZ-2107 through AZ-2111 are loop 11 follow-through from feature-assess round 1 (zero-width list and dict elements; orphan split flag bit). AZ-2112 through AZ-2118 are follow-ups from the same assessment, unclaimed. The Python orphan-flag-bit rule rides on AZ-2100.
AZ-2119 and AZ-2120 are C# bugs found by the loop 11 round 2 worker; both predate the loop and are unclaimed.
AZ-2122 through AZ-2125 are loop 11 security-audit fixes (F4-F9), claimed by loop 11 at the owner's request. AZ-2116 (exact C# integers) and AZ-2119 (C# group list element) stay open; F4 here only stops the exception.
AZ-2175 through AZ-2179 are loop 13 feature-assessment round 1 tasks (owner scope A, 2026-10-05), claimed by loop 13. AZ-2180 through AZ-2194 are the deferred follow-ups of that assessment, unclaimed; AZ-2197 (TypeScript twin of AZ-2175, found by the loop 13 README writer) is unclaimed too; AZ-2117 and AZ-2113 gained acceptance criteria from it (4 and 3 points). Decisions marked open in them wait for the owner before the loop that takes them.
