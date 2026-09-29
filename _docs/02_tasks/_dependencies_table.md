# Dependencies Table

**Date**: 2026-09-29
**Total Tasks**: 42
**Total Complexity Points**: 181

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

The six pack tasks do not depend on each other. AZ-1875 runs after all six. The five blackbox tasks run after AZ-1913 and do not depend on each other. The three earlier todo tasks do not depend on each other and still have no tracker id. AZ-1938 through AZ-1941 are under epic AZ-1937. The string count does not include itself; the list count does not consume the next field.
