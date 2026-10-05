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
| AZ-2087 | csharp_forward_refs | 2 | AZ-2070, AZ-2079 | AZ-2069 |
| AZ-2088 | csharp_pack_fails_loudly | 3 | AZ-2087, AZ-2079 | AZ-2069 |
| AZ-2089 | java_forward_refs_bool | 2 | AZ-2070, AZ-2077, AZ-2074 | AZ-2069 |
| AZ-2090 | typescript_reference_scope | 3 | AZ-2072, AZ-2080 | AZ-2069 |
| AZ-2091 | typescript_nested_flags_names | 3 | AZ-2080, AZ-2090 | AZ-2069 |
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

The six pack tasks do not depend on each other. AZ-1875 runs after all six. The five blackbox tasks run after AZ-1913 and do not depend on each other. The three earlier todo tasks do not depend on each other and still have no tracker id. AZ-1938 through AZ-1941 are under epic AZ-1937. The string count does not include itself; the list count does not consume the next field.

AZ-2060 through AZ-2068 are under epic AZ-2059 (C++ on microcontrollers). All nine touch only `cpp/` and the C++ CI and publish files, so they run in order, not in parallel. The session task depends on the scheme task, not only on the scalars, because it packs through a core scheme. The host port (AZ-2064) waits for the session so the old walker is deleted once. AZ-2068 is a stretch task (D-3 A). Estimation: `_docs/LESSONS.md` asks to keep the six packages as peers; this feature is C++ only, so no point bump.

AZ-2070 through AZ-2105 are under epic AZ-2069 (cross-language bug fixes; order and severity in `_docs/04_refactoring/02-whole-project-assessment/analysis/bugfix_task_plan.md`). Loop 10 claims only AZ-2070, AZ-2078 and AZ-2081; the rest are loop 11 onward. A task that lists a dependency on another AZ-2069 task in the same package lands after it.
