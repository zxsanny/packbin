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
| AZ-2214 | ci_pin_credentialed_job | 3 | None | AZ-2069 |
| AZ-2215 | build_containers_read_only | 5 | None (implement after AZ-2214: shared files) | AZ-2069 |
| AZ-2216 | csharp_round_limits | 3 | None | AZ-2069 |
| AZ-2217 | typescript_round_limits | 3 | None | AZ-2069 |
| AZ-2218 | java_round_limits | 3 | None | AZ-2069 |
| AZ-2219 | rust_round_limits | 3 | None | AZ-2069 |
| AZ-2220 | round_limits_hostile_and_docs | 3 | AZ-2216, AZ-2217, AZ-2218, AZ-2219 | AZ-2069 |
| AZ-2230 | python_split_bits_scheme_order | 3 | AZ-2135, AZ-2100 | AZ-2069 |
| AZ-2231 | python_session_load_bytes_only | 1 | AZ-2104 | AZ-2069 |
| AZ-2232 | vcpkg_supported_platforms_minor_version | 2 | AZ-2098 | AZ-2069 |
| AZ-2233 | java_nested_row_orphan_bit_refused | 2 | AZ-2135 | AZ-2069 |
| AZ-2234 | java_pack_fails_loudly_nulls_u2 | 3 | AZ-2101, AZ-2127 | AZ-2069 |
| AZ-2235 | java_typed_element_groups_checked | 2 | AZ-2101 | AZ-2069 |
| AZ-2236 | typescript_direct_element_kinds_refused | 2 | AZ-2102 | AZ-2069 |
| AZ-2237 | rust_map_pack_when_written_values | 3 | AZ-2189, AZ-2197 | AZ-2069 |
| AZ-2238 | harness_hygiene_prefix_find_consumer | 2 | AZ-2193, AZ-2099 | AZ-2069 |
| AZ-2239 | listgroup_cross_language_ring | 3 | AZ-2193, AZ-2102 | AZ-2069 |
| AZ-2240 | publish_guard_dist_and_port_asserts | 1 | AZ-2103, AZ-2098 | AZ-2069 |
| AZ-2304 | cpp_flag_byte_scope_members | 2 | AZ-2135 | AZ-2069 |
| AZ-2305 | csharp_collection_member_checked | 2 | AZ-2092 | AZ-2069 |
| AZ-2306 | csharp_empty_nested_row_present | 1 | AZ-2128 | AZ-2069 |
| AZ-2307 | csharp_flags_element_and_rings | 3 | AZ-2119, AZ-2239 | AZ-2069 |
| AZ-2308 | lone_dict_in_round_refused | 2 | AZ-2182 | AZ-2069 |
| AZ-2309 | csharp_numeric_slots_strict | 1 | AZ-2191 | AZ-2069 |
| AZ-2310 | csharp_dict_pack_repack_and_bytes_int | 2 | AZ-2119, AZ-2191 | AZ-2069 |
| AZ-2311 | rust_times_lone_scalar | 2 | AZ-2182 | AZ-2069 |
| AZ-2329 | pack_round_count_cap | 3 | AZ-2216 | AZ-2069 |
| AZ-2330 | python_round_fresh_scope | 2 | None | AZ-2069 |
| AZ-2331 | split_form_pack_fails_loudly | 3 | AZ-2120, AZ-2128 | AZ-2069 |
| AZ-2332 | lone_bytes_in_round_refused | 2 | AZ-2182 | AZ-2069 |
| AZ-2333 | rust_flags_member_scope | 2 | AZ-2304 | AZ-2069 |
| AZ-2334 | cpp_empty_group_when_source | 1 | None | AZ-2069 |
| AZ-2335 | times_count_zero_with_values_error | 2 | AZ-2304 | AZ-2069 |
| AZ-2336 | python_short_times_list_named_error | 1 | AZ-2248 | AZ-2069 |
| AZ-2337 | csharp_group_element_members_only | 2 | AZ-2307 | AZ-2069 |
| AZ-2338 | eq_value_checked_at_construction | 3 | AZ-2126 | AZ-2069 |
| AZ-2339 | fraction_slot_probe | 1 | AZ-2309 | AZ-2069 |
| AZ-2340 | cpp_present_result_pinned | 1 | AZ-2128 | AZ-2069 |
| AZ-2341 | run_suite_python_venv_check | 1 | None | AZ-2069 |
| AZ-2342 | split_files_near_cap | 2 | None | AZ-2069 |
| AZ-2354 | pack_output_budget | 5 | AZ-2329 | AZ-2069 |
| AZ-2355 | repeat_round_cap_on_pack | 2 | AZ-2329 | AZ-2069 |
| AZ-2356 | count_zero_after_byte_list_error | 2 | AZ-2335, AZ-2331 | AZ-2069 |
| AZ-2357 | cpp_count_behind_clear_when | 2 | AZ-2331 | AZ-2069 |
| AZ-2358 | csharp_whole_float_refused | 1 | AZ-2309, AZ-2338 | AZ-2069 |
| AZ-2359 | enum_slot_values_pinned | 1 | AZ-2309 | AZ-2069 |
| AZ-2360 | flags_skipped_count_values_loud | 2 | AZ-2331 | AZ-2069 |
| AZ-2361 | java_counts_fractions_sink | 2 | AZ-2329, AZ-2339 | AZ-2069 |
| AZ-2362 | python_repeat_empty_flags_named_error | 1 | AZ-2336 | AZ-2069 |
| AZ-2363 | typescript_times_in_when_split_bit | 1 | AZ-2331 | AZ-2069 |
| AZ-2364 | cpp_late_marks_every_member | 1 | AZ-2331 | AZ-2069 |
| AZ-2365 | split_files_near_cap_l20 | 1 | AZ-2342 | AZ-2069 |
| AZ-2366 | csharp_typed_round_unpack_error | 2 | AZ-2305 | AZ-2069 |
| AZ-2367 | hostile_pack_budget_cases | 2 | AZ-2354, AZ-2355, AZ-2356, AZ-2360 | AZ-2069 |
| AZ-2373 | csharp_exact_integer_types_unpack | 5 | AZ-2358 | AZ-2069 |
| AZ-2381 | python_unpack_slot_surcharge | 2 | AZ-2382 | AZ-2069 |
| AZ-2382 | round_slot_width_rule | 5 | AZ-2329 | AZ-2069 |
| AZ-2383 | short_list_in_optional_flags | 2 | none | AZ-2069 |
| AZ-2384 | split_bit_times_clear_bit | 2 | none | AZ-2069 |
| AZ-2385 | cpp_late_when_in_bit_body | 2 | AZ-2364 | AZ-2069 |
| AZ-2386 | count_one_behind_clear_when | 2 | none | AZ-2069 |
| AZ-2387 | bits_packed_sized_count_behind_clear_when | 3 | AZ-2386 | AZ-2069 |
| AZ-2388 | csharp_typed_rounds_bind_to_rows | 5 | AZ-2366 | AZ-2069 |
| AZ-2389 | csharp_dict_member_in_round_refused | 2 | none | AZ-2069 |
| AZ-2390 | empty_round_body_refused | 3 | AZ-2382 | AZ-2069 |
| AZ-2391 | ts_slice_round_scope_and_memory_note | 2 | none | AZ-2069 |
| AZ-2392 | hostile_loader_rule_tables | 3 | AZ-2394 | AZ-2069 |
| AZ-2393 | csharp_count_text_repeat_bytes_withlimits | 2 | AZ-2373 | AZ-2069 |
| AZ-2394 | hostile_cases_loop21 | 2 | AZ-2381 to AZ-2391 | AZ-2069 |

The six pack tasks do not depend on each other. AZ-1875 runs after all six. The five blackbox tasks run after AZ-1913 and do not depend on each other. The three earlier todo tasks do not depend on each other and still have no tracker id. AZ-1938 through AZ-1941 are under epic AZ-1937. The string count does not include itself; the list count does not consume the next field.

AZ-2060 through AZ-2068 are under epic AZ-2059 (C++ on microcontrollers). All nine touch only `cpp/` and the C++ CI and publish files, so they run in order, not in parallel. The session task depends on the scheme task, not only on the scalars, because it packs through a core scheme. The host port (AZ-2064) waits for the session so the old walker is deleted once. AZ-2068 is a stretch task (D-3 A). Estimation: `_docs/LESSONS.md` asks to keep the six packages as peers; this feature is C++ only, so no point bump.

AZ-2070 through AZ-2105 are under epic AZ-2069 (cross-language bug fixes; order and severity in `_docs/04_refactoring/02-whole-project-assessment/analysis/bugfix_task_plan.md`). Loop 10 claims only AZ-2070, AZ-2078 and AZ-2081; the rest are loop 11 onward. A task that lists a dependency on another AZ-2069 task in the same package lands after it.

AZ-2107 through AZ-2111 are loop 11 follow-through from feature-assess round 1 (zero-width list and dict elements; orphan split flag bit). AZ-2112 through AZ-2118 are follow-ups from the same assessment, unclaimed. The Python orphan-flag-bit rule rides on AZ-2100.
AZ-2119 and AZ-2120 are C# bugs found by the loop 11 round 2 worker; both predate the loop and are unclaimed.
AZ-2122 through AZ-2125 are loop 11 security-audit fixes (F4-F9), claimed by loop 11 at the owner's request. AZ-2116 (exact C# integers) and AZ-2119 (C# group list element) stay open; F4 here only stops the exception.
AZ-2175 through AZ-2179 are loop 13 feature-assessment round 1 tasks (owner scope A, 2026-10-05), claimed by loop 13. AZ-2180 through AZ-2194 are the deferred follow-ups of that assessment, unclaimed; AZ-2197 (TypeScript twin of AZ-2175, found by the loop 13 README writer) is unclaimed too; AZ-2117 and AZ-2113 gained acceptance criteria from it (4 and 3 points). Decisions marked open in them wait for the owner before the loop that takes them.
AZ-2214 through AZ-2220 are loop 15 (security findings F12, F13 and F10, owner request 2026-10-06), claimed by loop 15. AZ-2214 and AZ-2215 edit the same publish files, so AZ-2214 lands first; AZ-2220 follows the four round-limit tasks.
AZ-2230 through AZ-2240 are loop 16 round 2 (feature assessment round 1 CLARIFY, owner answer 2026-10-06: implement everything now), claimed by loop 16. AZ-2234 and AZ-2233 and AZ-2235 edit the same Java files and run in one worker; AZ-2238 and AZ-2239 both edit `language-pair.sh` and run in one worker; AZ-2232 and AZ-2240 both touch the vcpkg port checks and run in one worker. All eleven are Done in loop 16: the specs are in `done/`, each with a `## Loop 16 result` section; the table has no status column, so the rows above are unchanged. AZ-2243 through AZ-2249 (loop 16 round 3: the TypeScript and Python session seeds and nonces, the repeated member name in Python, Java and Rust, the Python short `times` list and the Python element accessor) are Done in loop 16 as well, specs in `done/`; the table has no rows for them.

AZ-2304 through AZ-2311 are loop 18 (owner decisions of 2026-10-10 on the loop 17 assessment, plus its clear gaps), claimed by loop 18: AZ-2304 (C++ flag-byte scope), AZ-2305 to AZ-2307, AZ-2309 and AZ-2310 (C#), AZ-2308 (lone dictionary in a round: C# first, other packages after the probe), AZ-2311 (Rust). The C# specs share `csharp/` and run in one worker; AZ-2307 also edits the shared ring files (`language-pair.sh`, the C# driver) and no other worker touches them in that wave.

AZ-2329 through AZ-2342 are loop 19 (owner decisions of 2026-10-11 on the loop 18 review and assessment, plus its clear gaps), claimed by loop 19; one worker per package directory, AZ-2342 first in each of rust, java, csharp.

AZ-2354 through AZ-2367 are loop 20 (owner decisions of 2026-10-11 on the loop 19 assessment, review and audit, plus its clear gaps), claimed by loop 20: TypeScript implements AZ-2354/AZ-2355 first and writes the reference table; then one worker per package directory; AZ-2367 is wave 2.

AZ-2373 and AZ-2381 through AZ-2394 are loop 21 (owner decisions U1 to U10 of 2026-10-12 on the loop 20 assessment, review and audit, plus its clear gaps), claimed by loop 21: TypeScript implements AZ-2382 first and writes the slot reference table; csharp runs AZ-2373, AZ-2389, AZ-2388, AZ-2393 in wave 1a and its AZ-2382/AZ-2390/AZ-2387 share in wave 1b; AZ-2394 then AZ-2392 are wave 2. The Go package (AZ-2222) follows.
AZ-2410 through AZ-2418 are loop 22 (owner decisions U11 to U17 of 2026-10-12 on the loop 21 handoff, plus gap G1 and the loader checks), claimed by loop 22: TypeScript implements AZ-2410 and AZ-2415 first and writes the reference table; then one worker per package directory; AZ-2417 then AZ-2418 are wave 2. AZ-2417 depends on AZ-2410 and AZ-2412 to AZ-2416; AZ-2418 on AZ-2417. The Go package (AZ-2222) follows.
AZ-2431 through AZ-2437 are loop 23 (owner decisions U18 to U23 of 2026-10-13 on the loop 22 handoff, plus gaps G1 to G3, and the Python bug AZ-2437 found in the batch), claimed by loop 23: one worker per package directory; `cpp/` runs AZ-2431 then AZ-2432; AZ-2436 is test-only in all six. U18 and U21 are README-only. The Go package (AZ-2222) follows.

AZ-2440 through AZ-2451 are loop 24, the Go package (epic AZ-2222; owner decisions G-1 to G-6 and the 12-task split of 2026-10-13), claimed by loop 24. `go/` has one writer at a time: AZ-2440, AZ-2441, AZ-2442, AZ-2443, AZ-2444, AZ-2445, AZ-2446, AZ-2447, then AZ-2451's `go/example_test.go`. AZ-2448 (CI suite, scaffold job) runs beside the chain after AZ-2440; AZ-2449 (ring, ring job) after AZ-2445; AZ-2450 (release, ADR-004) after AZ-2448 and AZ-2449; AZ-2451 last. Estimation: no LESSONS bump; the epic's 26 points became 43 because loops 17 to 23 added the parity rows and work bounds (flagged concern in `problem.md`).

| Task | Name | Complexity | Dependencies | Epic |
|------|------|-----------|-------------|------|
| AZ-2440 | go_core | 5 | None | AZ-2222 |
| AZ-2441 | go_scheme_checks | 5 | AZ-2440 | AZ-2222 |
| AZ-2442 | go_rounds | 5 | AZ-2441 | AZ-2222 |
| AZ-2443 | go_collections | 5 | AZ-2442 | AZ-2222 |
| AZ-2444 | go_limits | 3 | AZ-2443 | AZ-2222 |
| AZ-2445 | go_session | 3 | AZ-2440 | AZ-2222 |
| AZ-2446 | go_hostile_vectors | 3 | AZ-2444, AZ-2445 | AZ-2222 |
| AZ-2447 | go_parity_rows | 3 | AZ-2446 | AZ-2222 |
| AZ-2448 | go_ci_suite | 3 | AZ-2440 | AZ-2222 |
| AZ-2449 | go_ring | 3 | AZ-2445 | AZ-2222 |
| AZ-2450 | go_release | 5 | AZ-2448, AZ-2449 | AZ-2222 |
| AZ-2451 | go_readme | 2 | AZ-2447, AZ-2450 | AZ-2222 |

AZ-2472 through AZ-2479 are loop 25 (owner batch 2026-10-14 on the loop 24 handoff: D1-D7 recommended A, F44 owner-applied before any Go tag; short wave U25 A, U26 A, Low-1 A; U24 B README-only; D8 Go peak memory). Wave 1 runs four single-package workers in parallel: AZ-2472 (`cpp/`, arm stage required), AZ-2473 (`csharp/`), AZ-2474 (`python/`), AZ-2475 (`go/`). Wave 2 runs the probes and the run-suite alignment: AZ-2476 (D1 probe four packages, docs-only), AZ-2477 (D6 align six `run-suite.sh` to Go on missing manifest), AZ-2478 (D7 probe five packages and fix outliers), AZ-2479 (U24 B README). AZ-2068 stays out. The first `go/vX.Y.Z` tag needs the owner's explicit go and the F44 ruleset applied; the agent cannot do either.

| Task | Name | Complexity | Dependencies | Epic |
|------|------|-----------|-------------|------|
| AZ-2472 | cpp_builder_range_check | 3 | None | |
| AZ-2473 | csharp_nested_dict_names | 2 | None | |
| AZ-2474 | python_value_error_text | 1 | None | |
| AZ-2475 | go_peak_memory | 1 | None | |
| AZ-2476 | anchor_group_no_takers_probe | 1 | None | |
| AZ-2477 | run_suite_missing_manifest_fail | 2 | None | |
| AZ-2478 | split_flag_false_when_probe | 3 | None | |
| AZ-2479 | readme_cpp_clear_bit_unbound | 1 | None | |

AZ-2513 through AZ-2524 are loop 26, the Swift package (epic AZ-2223; owner decisions S-1 to S-5 and the five rulings of 2026-10-14; 47 points). `swift/` has one writer at a time: AZ-2513, then AZ-2514, AZ-2515, AZ-2516, AZ-2517, AZ-2519, AZ-2520, with AZ-2518 (session; also writes `Package.swift` and `Package.resolved`) after AZ-2513 and not beside another `swift/` writer. AZ-2521 (CI suite) runs beside the chain after AZ-2513; AZ-2522 (ring) after AZ-2518; AZ-2523 (release, ADR-005) after AZ-2521 and AZ-2522; AZ-2524 last. AZ-2068 stays out. No tag is pushed; the first tag after this loop needs the owner's explicit go and the F44 ruleset.

| Task | Name | Complexity | Dependencies | Epic |
|------|------|-----------|-------------|------|
| AZ-2513 | swift_core | 5 | None | AZ-2223 |
| AZ-2514 | swift_scheme_checks | 5 | AZ-2513 | AZ-2223 |
| AZ-2515 | swift_rounds | 5 | AZ-2514 | AZ-2223 |
| AZ-2516 | swift_collections | 5 | AZ-2515 | AZ-2223 |
| AZ-2517 | swift_limits | 3 | AZ-2516 | AZ-2223 |
| AZ-2518 | swift_session | 5 | AZ-2513 | AZ-2223 |
| AZ-2519 | swift_hostile_vectors | 3 | AZ-2517, AZ-2518 | AZ-2223 |
| AZ-2520 | swift_parity_rows | 3 | AZ-2519 | AZ-2223 |
| AZ-2521 | swift_ci_suite | 3 | AZ-2513 | AZ-2223 |
| AZ-2522 | swift_ring | 3 | AZ-2518 | AZ-2223 |
| AZ-2523 | swift_release | 5 | AZ-2521, AZ-2522 | AZ-2223 |
| AZ-2524 | swift_readme | 2 | AZ-2520, AZ-2523 | AZ-2223 |
| AZ-2563 | ci_gate_timings | 2 | None | AZ-2223 |
| AZ-2564 | ci_job_split | 5 | AZ-2563 | AZ-2223 |
| AZ-2565 | cpp_pool_race | 3 | None | AZ-2223 |
| AZ-2566 | swift_limit_docs | 1 | None | AZ-2223 |
| AZ-2567 | swift_peak_memory | 2 | None | AZ-2223 |
| AZ-2582 | publish_gate_cut | 5 | AZ-2563 | AZ-2223 |
| AZ-2600 | ci_speed | 8 | AZ-2582 | AZ-2223 |
| AZ-2607 | ci_speed_2 | 5 | AZ-2600 | AZ-2223 |
| AZ-2625 | ci_speed_3 | 5 | AZ-2607 | AZ-2223 |
| AZ-2626 | ci_speed_4 | 5 | AZ-2625 | AZ-2223 |
| AZ-2627 | ci_speed_5 | 5 | AZ-2626 | AZ-2223 |
| AZ-2646 | compact_text_format_spec | 5 | None | AZ-2645 |
| AZ-2647 | compact_text_vectors | 3 | AZ-2646 | AZ-2645 |
| AZ-2648 | python_compact_text | 5 | AZ-2647 | AZ-2645 |
| AZ-2649 | typescript_compact_text | 5 | AZ-2647 | AZ-2645 |
| AZ-2650 | csharp_compact_text | 5 | AZ-2647 | AZ-2645 |
| AZ-2651 | java_compact_text | 5 | AZ-2647 | AZ-2645 |
| AZ-2652 | rust_compact_text | 5 | AZ-2647 | AZ-2645 |
| AZ-2653 | go_compact_text | 5 | AZ-2647 | AZ-2645 |
| AZ-2654 | swift_compact_text | 5 | AZ-2647 | AZ-2645 |
| AZ-2655 | cpp_compact_text_codec | 5 | AZ-2647 | AZ-2645 |
| AZ-2656 | cpp_text_api_and_embedded | 4 | AZ-2655 | AZ-2645 |
| AZ-2657 | compact_text_hostile_ring_ci | 3 | AZ-2648 to AZ-2656 | AZ-2645 |
| AZ-2658 | compact_text_docs | 2 | AZ-2657 | AZ-2645 |
| AZ-2678 | ecc_format_spec | 5 | None | AZ-2677 |
| AZ-2679 | ecc_reference_vectors | 3 | AZ-2678 | AZ-2677 |
| AZ-2680 | python_ecc | 5 | AZ-2679 | AZ-2677 |
| AZ-2681 | typescript_ecc | 5 | AZ-2679 | AZ-2677 |
| AZ-2682 | csharp_ecc | 5 | AZ-2679 | AZ-2677 |
| AZ-2683 | java_ecc | 5 | AZ-2679 | AZ-2677 |
| AZ-2684 | rust_ecc | 5 | AZ-2679 | AZ-2677 |
| AZ-2685 | go_ecc | 5 | AZ-2679 | AZ-2677 |
| AZ-2686 | swift_ecc | 5 | AZ-2679 | AZ-2677 |
| AZ-2687 | cpp_ecc_codec | 5 | AZ-2679 | AZ-2677 |
| AZ-2688 | cpp_ecc_api_and_embedded | 4 | AZ-2687 | AZ-2677 |
| AZ-2689 | ecc_ring_ci | 3 | AZ-2680 to AZ-2688 | AZ-2677 |
| AZ-2690 | ecc_docs | 2 | AZ-2689 | AZ-2677 |
| AZ-2704 | ecc_dispatch_check_order | 3 | AZ-2694 | AZ-2677 |

AZ-2563 through AZ-2567 are loop 28 (owner 2026-10-15: speed check, then the S3 limit, the cpp pool race and the small leftovers; speed set accepted as recommended). AZ-2564 waits for AZ-2563 (both edit `publish-gate.test.sh`). AZ-2565 owns `scripts/loop-tests.sh` and its test; AZ-2566 owns README and ADR-005; AZ-2567 owns only a scratchpad driver and a record entry. AZ-2068 stays out.

AZ-2582 is loop 29 (owner 2026-10-15: cut the publish gate; approach A, target at most 18 minutes).

AZ-2600 is loop 30 (owner 2026-10-16: all recommended reductions of the CI metrics report). AZ-2607 is loop 31 (owner 2026-10-17: all six recommendations of the loop 31 handoff; one task, two batches). AZ-2625 is loop 32 (owner 2026-10-17: readonly-gate in three jobs, pins moved, phases in two, Swift strict build merged; target a median wall of at most 330 s; one task, one batch). AZ-2626 is loop 33 (owner 2026-10-17: ring off the critical path, exact pull list per gate job; target a median wall of at most 250 s and ring at most 180 s; one task, one batch). AZ-2627 is loop 34 (owner 2026-10-17: Swift build caches with ccache for the C files, at most 20 jobs; target a median wall of at most 225 s; one task, one batch). AZ-2068 stays out.

AZ-2646 through AZ-2658 are loop 35 (owner 2026-10-18: compact strings, epic AZ-2645; 57 points). Order: AZ-2646 (format, tables), AZ-2647 (reference, vectors), then AZ-2648 to AZ-2655 are independent peers (one package each, disjoint files), AZ-2656 after the C++ codec, AZ-2657 after every package, AZ-2658 last. Estimation: `LESSONS.md` says a new language costs 47 points over 12 specs; here each package changes one walker path, so 5 points per package with no bump. The Swift and C++ tasks carry the two largest risks (F47 for keys; scratch buffer and the size probe).

AZ-2674 through AZ-2676 are loop 37 (owner 2026-10-18: the Low findings of review35, epic AZ-2645; 6 points). Disjoint files: AZ-2674 owns `cpp/Makefile`, `core.hpp` comment and a check script; AZ-2675 owns `csharp/tests`; AZ-2676 owns `_docs/02_task_plans/compact-strings/research`. Findings 7 and 8 are accepted with no code. AZ-2068 stays out.

AZ-2678 through AZ-2690 are loop 38 (owner 2026-10-18: message error correction, epic AZ-2677; 57 points; full correction chosen over detect-first). Order: AZ-2678 (contract), AZ-2679 (reference and vectors), then AZ-2680 to AZ-2687 are independent of each other and own disjoint package folders, AZ-2688 follows AZ-2687, AZ-2689 (ring, CI) after all packages, AZ-2690 (docs) last.

AZ-2694 and AZ-2695 are loop 39 (owner 2026-10-18: review cleanups of loop 38, epic AZ-2677; 5 points; short loop). Disjoint: AZ-2694 owns the ECC paths of all eight packages and one contract sentence; AZ-2695 owns the re-verify tests and the C++ component description. Run AZ-2694 first, AZ-2695 after (both touch the same test folders). Parity setter shape and the default correction limit stay out.

AZ-2704 is loop 40 (owner 2026-10-19: the loop 39 review Lows, epic AZ-2677; 3 points; short loop). One task: the dispatch check order of all eight packages and a required Rust `parity()`. The default correction limit and the 254-byte limit stay.

AZ-2713 and AZ-2722 are loop 42 (owner 2026-10-19: "accept all recommended"; epic AZ-2645; 8 + 3 points). AZ-2713: the strictly ascending dict keys of all eight packages; AZ-2722: F57, F59, F60 and the F19 instances (F58 deferred). They share no source file except per-package test folders and `AZ-2722` touches C++ `session.hpp`/`codec.hpp` while AZ-2713 touches `unpack.cpp`. AZ-2068 stays out.

AZ-2723 and AZ-2724 are loop 43 (owner 2026-10-19: "accept all recommended" after loop 42; epic AZ-2645; 5 + 2 points). AZ-2723 owns only test files of the eight packages plus one AGENT_GOTCHAS line; AZ-2724 owns `python/src/packbin/_receive`/`_session` code, a new Python test file and the `pack-session.md` and README sentence. They share no file except that both touch `python/`; the Python timing worker leaves `python/src` alone. AZ-2068 stays out.

AZ-2068 and AZ-2728 are loop 44 (owner 2026-10-19: "accept all recommended" after loop 43; 3 + 1 points). AZ-2068 (epic AZ-2059) owns `cpp/include/packbin`, `cpp/src/core`, `cpp/embedded` and the AVR example; AZ-2728 (epic AZ-2645) owns `typescript/tests/hostile.test.ts` and `typescript/tests/support/hostile-worker.ts`. They share no file and run in parallel.

AZ-2733 is loop 45 (owner 2026-10-20: "Run /feature-assess", then "accept all six" and "small items now, tests next loop"; epic AZ-2645; 5 points). It owns `typescript/src/text.ts` and a new TypeScript test, `cpp/tests`, `go/testdata/fuzz`, the Python and TypeScript AC-8 speed tests, `_docs/02_document/tests/`, `_docs/02_document/components/05_cpp_package/description.md` and the two acceptance-criteria files named in AC-6 to AC-8. No dependency; no shared source file with another open task.

AZ-2735, AZ-2736, AZ-2737, AZ-2739 and AZ-2740 are loop 46 (owner 2026-10-20: "accept all six" and "small items now, tests next loop" in loop 45, `handoff46.md`; epic AZ-2645; 3 + 3 + 2 + 5 + 2 = 15 points). They are independent. Test files per package are disjoint new files: AZ-2735 (C#, Java, Rust, Go, Swift), AZ-2736 (Python, C#, Swift, Go and `compact-strings/acceptance_criteria.md`), AZ-2737 (Java, C#, Rust, C++); AZ-2739 owns `.github/workflows/language-pair.sh`, `ring-wiring.test.sh` and the eight session drivers; AZ-2740 owns `_docs/02_document/tests/`, `scripts/text/size_report.py` and `size_report.md`. Workers run by package, not by task. No file under `cpp/src`, `cpp/include` or `cpp/embedded`. AZ-2742 (epic AZ-2645, 3 points, To Do) is the C++ shortcut for the repeated text, opened by the owner's choice when the C++ test of AZ-2737 measured 1.9 s against 1 s.

AZ-2744 and AZ-2745 are loop 47 (owner 2026-10-20: "accept all recommended" on the hopper rows of `handoff47.md`; epic AZ-2645; 3 + 2 points). They are independent and own disjoint files: AZ-2744 owns `.github/workflows/language-pair.sh`, the new `ring-lib.sh`, `ring-wiring.test.sh`, `ring-wiring-swift.test.sh`, `ring-ecc.sh`, `ring-prepare.test.sh` and one new session-ecc wiring test; AZ-2745 owns `.github/workflows/run-suite.sh` and `run-suite-swift.test.sh`. No package source file. AZ-2742 (the C++ shortcut) stays To Do for a later loop.

AZ-2742 and AZ-2747 are loop 48 (owner 2026-10-20: "accept all recommended" on the leftovers of `record47.md` and `handoff48.md`; epic AZ-2645; 3 + 1 points). They are independent and own disjoint files: AZ-2742 owns `cpp/src/core`, `cpp/tests/core/text_repeat_host_tests.cpp` and the C++ margins in `_docs/AGENT_GOTCHAS.md`; AZ-2747 owns the ring scripts and wiring tests under `.github/workflows`. No shared source file.

AZ-2749 and AZ-2751 through AZ-2757 are loop 50 (owner 2026-10-20: option B "port the C++ heap-free core" of the Complexity Budget, then "accept all recommended"; epic AZ-2750; 34 points in eight slices). `LESSONS.md` says a new language costs 47 points over 12 specs; here one core module follows a proven C++ design, so no bump, but the first 5-point estimate of AZ-2749 was for the whole feature and was wrong. Order: AZ-2749 (core types, features, flat schemes, differential harness), then AZ-2751 (embedded profile CI) and AZ-2752 (flags, bits, when) both need only AZ-2749, AZ-2753 after AZ-2752, AZ-2754 after AZ-2753, AZ-2755 after AZ-2749, AZ-2756 after AZ-2755, AZ-2757 last. All write `rust/src/nostd/**` (AZ-2751 writes CI and `rust/embedded`), so they run one after another.

| Task | Name | Complexity | Dependencies | Epic |
|------|------|-----------|-------------|------|
| AZ-2749 | rust_nostd_core (features, flat schemes, host proof) | 5 | None | AZ-2750 |
| AZ-2751 | rust_core_embedded_profile | 5 | AZ-2749 | AZ-2750 |
| AZ-2752 | rust_core_bits_and_when | 5 | AZ-2749 | AZ-2750 |
| AZ-2753 | rust_core_lists_and_dicts | 5 | AZ-2752 | AZ-2750 |
| AZ-2754 | rust_core_compact_text | 5 | AZ-2753 | AZ-2750 |
| AZ-2755 | rust_core_ecc | 3 | AZ-2749 | AZ-2750 |
| AZ-2756 | rust_core_session | 3 | AZ-2755 | AZ-2750 |
| AZ-2757 | rust_core_hostile_and_docs | 3 | AZ-2749, AZ-2751, AZ-2752, AZ-2753, AZ-2754, AZ-2755, AZ-2756 | AZ-2750 |

AZ-3132, AZ-3133 and AZ-3134 are loop 55 (owner 2026-10-21: "Accept all recommended: A+B+D" on `handoff55.md`; epic AZ-2645; 3 + 3 + 3 points). They are independent. Shared write area: the C++ package (AZ-3132 `cpp/embedded`, margins; AZ-3133 `cpp/tests/core` runner and `fixtures/hostile/cases.txt`; AZ-3134 `cpp/tests/core/text_repeat_host_tests.cpp`) and each package's tests directory, so one worker per package carries all three tasks (loop 46 lesson).

| Task | Name | Complexity | Dependencies | Epic |
|------|------|-----------|-------------|------|
| AZ-3132 | cpp_when_chain_stack | 3 | None | AZ-2645 |
| AZ-3133 | when_bool_source_corpus | 3 | None | AZ-2645 |
| AZ-3134 | repeated_text_headroom | 3 | None | AZ-2645 |

AZ-3141 is loop 55 assess round 1 (EXTEND, gap E1): AZ-3132 left a held `when` whose body reads a flag byte on `unpack_one`, so its chain stack is unmeasured. 2 points, epic AZ-2645, depends on AZ-3132 (done); owns `cpp/` only.

| Task | Name | Complexity | Dependencies | Epic |
|------|------|-----------|-------------|------|
| AZ-3141 | cpp_when_chain_flag_byte_stack | 2 | AZ-3132 | AZ-2645 |

AZ-3143, AZ-3144 and AZ-3145 are loop 56 (owner 2026-10-21: "Accept recommended for loop 56" on `handoff56.md`; epic AZ-2645; 3 + 3 + 2 points). AZ-3144 depends on AZ-3143 (flash saving first). AZ-3143 and AZ-3144 own `cpp/` only; AZ-3145 owns the Go, Swift and Rust test loaders only, so the two lines run in parallel.

| Task | Name | Complexity | Dependencies | Epic |
|------|------|-----------|-------------|------|
| AZ-3143 | cpp_flag_byte_bit_at_resolve | 3 | None | AZ-2645 |
| AZ-3144 | cpp_held_when_one_path | 3 | AZ-3143 | AZ-2645 |
| AZ-3145 | corpus_counts_derived | 2 | None | AZ-2645 |

AZ-3151 to AZ-3154 are loop 57 (owner 2026-10-22: "Accept all recommended" on `handoff57.md`; epic AZ-2645; 3 + 3 + 3 + 1 points). AZ-3152 depends on AZ-3151 (flash saving first); AZ-3154 depends on AZ-3152 (pin set last). AZ-3151, AZ-3152 and AZ-3154 own `cpp/` only; AZ-3153 owns the Rust, Swift and Go test loaders only, so the C++ line and the loader line are disjoint.

| Task | Name | Complexity | Dependencies | Epic |
|------|------|-----------|-------------|------|
| AZ-3151 | cpp_flash_search | 3 | None | AZ-2645 |
| AZ-3152 | cpp_held_when_fold_retry | 3 | AZ-3151 | AZ-2645 |
| AZ-3153 | corpus_guards | 3 | None | AZ-2645 |
| AZ-3154 | cpp_flash_pin | 1 | AZ-3152 | AZ-2645 |

AZ-3160 to AZ-3162 are loop 58 (owner 2026-10-22: "Accept all recommended" on `handoff58.md`; epic AZ-2645; 2 + 1 + 2 points). All three are test-only and own disjoint files: Rust nostd test (AZ-3160), Go pack test (AZ-3161), C++ `dict_order_host_tests.cpp` (AZ-3162).

| Task | Name | Complexity | Dependencies | Epic |
|------|------|-----------|-------------|------|
| AZ-3160 | rust_nostd_corpus_count | 2 | None | AZ-2645 |
| AZ-3161 | go_refusal_check_ids | 1 | None | AZ-2645 |
| AZ-3162 | cpp_dict_key_order_high_byte | 2 | None | AZ-2645 |

AZ-3163 and AZ-3164 are loop 59 (owner 2026-10-22: "Review Lows of loop 58" from `handoff59.md`; epic AZ-2645; 2 + 2 points). Both are test-only and own disjoint files.

| Task | Name | Complexity | Dependencies | Epic |
|------|------|-----------|-------------|------|
| AZ-3163 | rust_nostd_corpus_count_name_rule | 2 | None | AZ-2645 |
| AZ-3164 | cpp_dict_key_order_checks | 2 | None | AZ-2645 |

AZ-3165 to AZ-3166 are loop 60 (owner 2026-10-22: "Review Lows of loop 59 + retro" from `handoff60.md`; epic AZ-2645; 2 + 2 points). Both are test-only and own disjoint files. Jira keys created 2026-10-24 (loop 66 replay).

| Task | Name | Complexity | Dependencies | Epic |
|------|------|-----------|-------------|------|
| AZ-3165 | cpp_dict_key_order_error_report | 2 | None | AZ-2645 |
| AZ-3166 | rust_nostd_corpus_kind_hex_rule | 2 | None | AZ-2645 |

AZ-3167 is loop 61, AZ-3168 loop 62, AZ-3169 loop 63 (epic AZ-2645; keys created 2026-10-24).

| Task | Name | Complexity | Dependencies | Epic |
|------|------|-----------|-------------|------|
| AZ-3167 | cpp_pack_held_of_measure | 2 | None | AZ-2645 |
| AZ-3168 | cpp_field_layout_shrink | 3 | None | AZ-2645 |
| AZ-3169 | cpp_pack_flash_saving | 3 | None | AZ-2645 |

AZ-3170 is loop 65 (CI paths-ignore, Rust limits, flag-byte chain) and AZ-3171 is loop 66 (publish gate under load); epic AZ-2645.

| Task | Name | Complexity | Dependencies | Epic |
|------|------|-----------|-------------|------|
| AZ-3170 | ci_paths_ignore_rust_limits_flag_round_chain | 3 | None | AZ-2645 |
| AZ-3171 | publish_gate_load_aware | 3 | None | AZ-2645 |
| AZ-3185 | cpp_unpack_flag_scope_stack | 3 | None | AZ-2645 |
