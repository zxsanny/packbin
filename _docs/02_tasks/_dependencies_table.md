# Dependencies Table

**Date**: 2026-09-23
**Total Tasks**: 21
**Total Complexity Points**: 95

Estimation: `_docs/LESSONS.md` says the six packages stay peers. These four tasks do not add a shared walker. No point bump.

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

The six pack tasks do not depend on each other. AZ-1875 runs after all six. The five blackbox tasks run after AZ-1913 and do not depend on each other. The three earlier todo tasks do not depend on each other and still have no tracker id. AZ-1938 through AZ-1941 are under epic AZ-1937. The string count does not include itself; the list count does not consume the next field.
