# packbin — Planning Report

## Executive Summary

packbin is six stateless libraries that pack and unpack a caller-owned field list to the same bytes. GitHub Actions tests every push and publishes npm, NuGet, PyPI, crates.io, Maven Central, and vcpkg from one version tag after the golden hex matches. Planning produced 6 components, 3 accepted ADRs, and 8 epics (about 40 story points).

## Problem Statement

C#, Vue, and Android already share a binary layout. A tagged serializer would change the size. Each language writes the list by hand. The first publish is those six languages, and a mismatch publishes nothing.

## Architecture Overview

Walk the list with little-endian runtime primitives. No code generator. No server and no database. The C++ package is a public vcpkg git registry, because vcpkg has no upload API.

**Technology stack**: C#, TypeScript, Python, Rust, C++, Java. GitHub Actions. No database.

**Deployment**: a workstation, GitHub Actions, and the six public registries. There is no staging host.

## Component Summary

| # | Component | Purpose | Dependencies | Epic |
|---|-----------|---------|-------------|------|
| — | Bootstrap | Fixture, CI, tag publish | — | AZ-1858 |
| 01 | C# package | Pack and unpack for .NET | golden fixture | AZ-1859 |
| 02 | TypeScript package | Pack and unpack for Vue, React, and Node | golden fixture | AZ-1860 |
| 03 | Python package | Pack and unpack for tools and scripts | golden fixture | AZ-1861 |
| 04 | Rust package | Pack and unpack for a native node | golden fixture | AZ-1862 |
| 05 | C++ package | Pack and unpack for a C++ program | golden fixture | AZ-1863 |
| 06 | Java package | Pack and unpack for Android and Java | golden fixture | AZ-1864 |
| — | Blackbox tests | Six-language and tag scenarios | the six packages | AZ-1865 |

**Implementation order**:
1. AZ-1858, the fixture and the workflows
2. The six packages, in parallel
3. AZ-1865, the blackbox suite

## System Flows

| Flow | Description | Key Components |
|------|-------------|---------------|
| F1 Pack | A value becomes bytes | the caller's package |
| F2 Unpack | Bytes become a value or an error | the caller's package |
| F3 Publish | A tag publishes six packages, or zero | GitHub Actions and the six registries |

See `system-flows.md`.

## Risk Summary

| Level | Count | Key Risks |
|-------|-------|-----------|
| Critical | 0 | — |
| High | 1 | R01 six hand-written lists drift |
| Medium | 0 | — |
| Low | 3 | R02 vcpkg version stays, R03 Maven Central version stays, R04 a language misses the speed bound |

**Iterations completed**: 1
**All Critical/High risks mitigated**: Yes. R01 publishes nothing when the mismatch count is above 0. The C++ host is vcpkg.

See `risk_mitigations.md`.

## Test Coverage

| Component | Integration | Performance | Security | Acceptance | AC Coverage |
|-----------|-------------|-------------|----------|------------|-------------|
| C# | 9 | 1 | 2 | 6 | 16/16 |
| TypeScript | 9 | 1 | 2 | 6 | 16/16 |
| Python | 9 | 1 | 2 | 6 | 16/16 |
| Rust | 9 | 1 | 2 | 6 | 16/16 |
| C++ | 9 | 1 | 2 | 6 | 16/16 |
| Java | 9 | 1 | 2 | 6 | 16/16 |

**Overall acceptance criteria coverage**: 16 / 16 (100%). System scenarios are in `tests/traceability-matrix.md`. Restrictions R-11 and R-12 are waived there because no date and no budget were set.

## Epic Roadmap

| Order | Epic | Component | Effort | Dependencies |
|-------|------|-----------|--------|-------------|
| 1 | AZ-1858: Bootstrap | shared | M | — |
| 2 | AZ-1859: C# | 01 | M | AZ-1858 |
| 2 | AZ-1860: TypeScript | 02 | M | AZ-1858 |
| 2 | AZ-1861: Python | 03 | M | AZ-1858 |
| 2 | AZ-1862: Rust | 04 | M | AZ-1858 |
| 2 | AZ-1863: C++ | 05 | M | AZ-1858 |
| 2 | AZ-1864: Java | 06 | M | AZ-1858 |
| 3 | AZ-1865: Blackbox tests | tests | M | the six packages |

**Total estimated effort**: 8 epics, 5 points each, 40 points. The six language epics run in parallel after bootstrap.

## Key Decisions Made

| # | Decision | Rationale | Alternatives Rejected |
|---|----------|-----------|----------------------|
| 1 | ADR 001 runtime primitives, no generator | The bytes are only the fields | Protobuf, Kaitai, a day-one compiler |
| 2 | ADR 002 publish from a version tag | 0 manual uploads | GitHub Packages, trusted publishing, a laptop upload |
| 3 | ADR 003 vcpkg git registry | The project owner named vcpkg. vcpkg has no upload API | Conan, a pull request to microsoft/vcpkg |

## Open Questions

| # | Question | Impact | Assigned To |
|---|----------|--------|-------------|
| 1 | — | — | — |

No open planning question. The C++ registry is vcpkg.

## Artifact Index

| File | Description |
|------|-------------|
| `architecture.md` | System architecture |
| `adr/` | Accepted ADR 001, 002, 003 |
| `system-flows.md` | Pack, unpack, and publish |
| `interaction-risks.md` | Seam risks and their ACs |
| `data_model.md` | Field list, bytes, short packet. No database |
| `risk_mitigations.md` | Risk register |
| `epics.md` | Epic keys and order |
| `components/01_csharp_package/` | C# spec and tests |
| `components/02_typescript_package/` | TypeScript spec and tests |
| `components/03_python_package/` | Python spec and tests |
| `components/04_rust_package/` | Rust spec and tests |
| `components/05_cpp_package/` | C++ spec and tests |
| `components/06_java_package/` | Java spec and tests |
| `tests/` | System blackbox draft |
| `deployment/` | CI, environments, procedures |
| `diagrams/components.drawio` | Component diagram |

## Quality checklist

- Traceability covers AC-1 through AC-16. R-11 and R-12 are waived.
- There is no database migration. `data_model.md` says so.
- CI stages are test and publish. There is no third-party security scanner. The archive check is token count 0.
- The library does not log or page. Actions keeps the test log. A failed golden check is the alert.
- The product has no runtime container. Test images are the six language toolchains.
- Risk confirmation: the C++ host was named vcpkg, and the register has no open decision.
