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
| 006 | Compact text is the one wire form of every string | Accepted | 2026-10-18 | — |
| 007 | A scheme may add parity bytes that detect and repair a corrupted message | Accepted | 2026-10-18 | — |
| 008 | Frame mode authenticates; stream mode does not | Accepted | 2026-10-25 | — |
| 009 | Frame mode is the only session; the stream session is removed | Accepted | 2026-10-26 | — |

ADR-004 amends the count of six in ADR-002 (the first tag's six packages stay history); ADR-002 itself is unchanged.
ADR-005 amends nothing: Swift adds no package and no tag, and ADR-002 and ADR-004 stay as written.
ADR-006 amends nothing: the compact text codec is one more runtime primitive under ADR-001; the string wire form changes, no other ADR does.
ADR-007 amends nothing: ADR-001's "the wire size is the sum of the present fields" holds for every scheme that does not declare parity bytes; the one exception is opt-in.
ADR-008 amends ADR-001's "the wire size is the sum of the present fields" and the "authentication: none" line of the architecture for frame mode only: the body ends with its tag. Stream mode is unchanged.
ADR-009 amends ADR-008: its frame-mode decision stands; the stream mode beside it, and "one session type serves the websocket (stream) and the radio (frame)", are removed. ADR-008 itself is unchanged.
