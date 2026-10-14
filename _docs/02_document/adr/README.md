# Architecture Decision Records

This index lists every ADR for this project, in number order. ADRs are immutable once `Accepted` —
new decisions that overturn a prior ADR are recorded as new ADRs whose `Supersedes` field points
back, and the original ADR's `Superseded by` field is updated.

| # | Title | Status | Date | Supersedes |
|---|-------|--------|------|------------|
| 001 | Walk field lists with runtime primitives | Accepted | 2026-09-22 | — |
| 002 | Publish six packages from a version tag | Accepted | 2026-09-22 | — |
| 003 | Publish C++ through a vcpkg git registry | Accepted | 2026-09-22 | — |
| 004 | Go ships as a git tag from the same commit | Accepted | 2026-10-13 | — |
| 005 | Swift installs from the root Package.swift at the vX.Y.Z tag | Accepted | 2026-10-14 | — |

ADR-004 amends the count of six in ADR-002 (the first tag's six packages stay history); ADR-002 itself is unchanged.
ADR-005 amends nothing: Swift adds no package and no tag, and ADR-002 and ADR-004 stay as written.
