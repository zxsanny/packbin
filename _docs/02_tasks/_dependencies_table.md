# Dependencies Table

**Date**: 2026-09-22
**Total Tasks**: 14
**Total Complexity Points**: 64

Estimation: `_docs/LESSONS.md` is absent. No estimation bias applied.

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

The six pack tasks do not depend on each other. AZ-1875 runs after all six. The five blackbox tasks run after AZ-1913 and do not depend on each other.
