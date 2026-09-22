# Implementation report — packbin loop 1

**Date**: 2026-09-22
**Batches**: 1–4
**Completeness**: `_docs/03_implementation/implementation_completeness_loop1_report.md`

Six language packages pack and unpack a caller-owned field list. A version tag packs every language present in that commit against `fixtures/golden.hex` and publishes only when the mismatch count is 0.

| Batch | Tasks | Commit |
|-------|-------|--------|
| 1 | AZ-1866 | `15c62c7` |
| 2 | AZ-1876, AZ-1877, AZ-1878, AZ-1879 | `58b6d14` |
| 3 | AZ-1880, AZ-1881 | `f3f3177` |
| 4 | AZ-1875 | `617fc19` |

Open product questions are in the batch 4 discovery table (Maven group id, vcpkg remote). They are not scaffolds in the pack path.
