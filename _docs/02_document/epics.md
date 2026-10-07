# Epics — packbin

LESSONS.md is absent. No estimation lesson applies.

Cross-cutting epics: none. The library does not log, authenticate, or load configuration. Registry tokens stay in GitHub Actions secrets.

Tracker: Jira project AZ on denyspopov.atlassian.net.

## Order

```mermaid
flowchart TD
  Boot[AZ-1858 Bootstrap]
  Cs[AZ-1859 C#]
  Ts[AZ-1860 TypeScript]
  Py[AZ-1861 Python]
  Rs[AZ-1862 Rust]
  Cpp[AZ-1863 C++]
  Java[AZ-1864 Java]
  Tests[AZ-1865 Blackbox tests]
  Boot --> Cs
  Boot --> Ts
  Boot --> Py
  Boot --> Rs
  Boot --> Cpp
  Boot --> Java
  Cs --> Tests
  Ts --> Tests
  Py --> Tests
  Rs --> Tests
  Cpp --> Tests
  Java --> Tests
```

| Order | Key | Epic | Type | Effort | Depends on |
|-------|-----|------|------|--------|------------|
| 1 | AZ-1858 | Bootstrap and initial structure | bootstrap | M / 5 | — |
| 2 | AZ-1859 | C# package | component | M / 5 | AZ-1858 |
| 2 | AZ-1860 | TypeScript package | component | M / 5 | AZ-1858 |
| 2 | AZ-1861 | Python package | component | M / 5 | AZ-1858 |
| 2 | AZ-1862 | Rust package | component | M / 5 | AZ-1858 |
| 2 | AZ-1863 | C++ package | component | M / 5 | AZ-1858 |
| 2 | AZ-1864 | Java package | component | M / 5 | AZ-1858 |
| 3 | AZ-1865 | Blackbox tests | tests | M / 5 | the six packages |
| 4 | AZ-2018 | Pack session | feature | L / 13 | the six packages |
| 5 | AZ-2222 | Go package (full parity) | component | L / ~26 | the six packages |
| 6 | AZ-2223 | Swift package (full parity) | component | L / ~26 | the six packages |

The six language epics are the same order. Each is pack, unpack, and that registry's publish. Full descriptions are on the Jira issues.

Go and Swift (2026-10-06) each cover every feature the six packages have: the wire format, schemes, strings, lists, dicts, the session, round limits, hostile vectors, the language-pair ring, and CI. Neither has a registry upload. Both install from a git tag, so their open decisions are about tag and manifest layout (Go `go/vX.Y.Z` tags; Swift `Package.swift` at the repository root). These are listed on the Jira issues.
