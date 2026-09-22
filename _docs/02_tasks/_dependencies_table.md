# Dependencies Table

**Date**: 2026-09-22
**Total Tasks**: 8
**Total Complexity Points**: 40

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

The six pack tasks do not depend on each other. AZ-1875 runs after all six.
