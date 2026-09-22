# packbin — Architecture

## Architecture Vision

packbin is a library: the caller writes a field list, pack and unpack move the exact bytes, and GitHub Actions tests every push and publishes C#, TypeScript, Python, Rust, C++, and Java on a version tag after every one of them matches the golden hex.

**Components and ownership**

- Field list — the caller owns the packet description
- C# package — pack and unpack for .NET
- TypeScript package — pack and unpack for Vue, React, and Node
- Python package — pack and unpack for tools and scripts
- Rust package — pack and unpack for a native node
- C++ package — pack and unpack for a C++ program
- Java package — pack and unpack for a Java program
- GitHub Actions — tests on every push and pull request, publish on a version tag

**Principles**

- The bytes are only the fields
- The first release has no code generator
- A short packet returns no value

> See ADR 001 (Walk field lists with runtime primitives).

## 1. System Context

**Problem being solved**: Six languages must pack and unpack a binary layout the caller already has, without adding tag bytes that change the size.

**System boundaries**: Inside the library are the field helpers, pack, and unpack. Outside it are the caller's socket, the caller's field lists, and the public registries.

**External systems**:

| System | Integration Type | Direction | Purpose |
|--------|-----------------|-----------|---------|
| GitHub | git and Actions | Outbound | Source, tests, tag publish |
| npmjs.org | registry upload | Outbound | TypeScript package |
| nuget.org | registry upload | Outbound | C# package |
| pypi.org | registry upload | Outbound | Python package |
| crates.io | registry upload | Outbound | Rust package |
| Maven Central | registry upload | Outbound | Java package |
| vcpkg | git registry push | Outbound | C++ package `packbin` |

> See ADR 003 (Publish C++ through a vcpkg git registry).

## 2. Technology Stack

| Layer | Technology | Version | Rationale |
|-------|-----------|---------|-----------|
| Language | C# | current .NET LTS at first publish | Server runtime |
| Language | TypeScript | current Node LTS at first publish | Vue, React, and Node |
| Language | Python | current stable at first publish | Tools and scripts |
| Language | Rust | current stable at first publish | A native node |
| Language | C++ | current stable at first publish | A C++ program |
| Language | Java | current stable at first publish | A Java program |
| Framework | none | — | A library, not an application |
| Database | none | — | No stored packets |
| Cache | none | — | Each call is independent |
| Message Queue | none | — | The caller owns the socket |
| Hosting | none | — | No server |
| CI/CD | GitHub Actions | — | Tests on push and pull request. Publish on a version tag |

> See ADR 002 (Publish six packages from a version tag).

**Key constraints from restrictions.md**:

- No tag, length prefix, version byte, or schema id is added to the buffer
- Vue and React do not get their own package
- Registry credentials stay in the CI secret store

## 3. Deployment Model

**Environments**: a workstation for development, GitHub Actions for the test run, and the public registries for the published packages. There is no staging host.

**Infrastructure**:
- No cloud application host
- No container orchestration for the product
- The test containers are the current .NET LTS SDK, the current Node LTS image, and the current stable images for Python, Rust, C++, and Java

**Environment-specific configuration**:

| Config | Development | Production |
|--------|-------------|------------|
| Database | none | none |
| Secrets | none in the library | registry tokens in GitHub Actions secrets |
| Logging | the short-packet error returned to the caller | the same error; nothing is shipped to a log service |

## 4. Data Model Overview

**Core entities**:

| Entity | Description | Owned By Component |
|--------|-------------|--------------------|
| Field list | Order, widths, endian, and flag bits | Caller |
| Bytes | The packed buffer | Caller, after pack |
| Short packet | Field name, bytes needed, bytes left | unpack |

**Key relationships**:
- One field list describes one packet shape
- One value plus one field list produces one byte buffer, or pack refuses an integer that does not fit

**Data flow summary**:
- Value → pack → bytes: the caller sends the bytes on their own socket
- Bytes → unpack → value or error: a short buffer does not yield a partial value

## 5. Integration Points

### Internal Communication

| From | To | Protocol | Pattern | Notes |
|------|----|----------|---------|-------|
| Caller | pack | in-process call | Request-Response | value in, bytes out |
| Caller | unpack | in-process call | Request-Response | bytes in, value or error out |

### External Integrations

| External System | Protocol | Auth | Rate Limits | Failure Mode |
|----------------|----------|------|-------------|--------------|
| npmjs.org | HTTPS publish | CI secret | registry policy | the tag publishes 0 packages when the golden bytes disagree |
| nuget.org | HTTPS publish | CI secret | registry policy | same commit as the other five, or none on a mismatch |
| pypi.org | HTTPS publish | CI secret | registry policy | same commit, or none on a mismatch |
| crates.io | HTTPS publish | CI secret | registry policy | same commit, or none on a mismatch |
| Maven Central | HTTPS publish | CI secret | registry policy | same commit, or none on a mismatch. A published version stays |
| vcpkg | git push of the registry | CI secret | registry policy | same commit, or none on a mismatch. A pushed port version stays |

> See ADR 002 (Publish six packages from a version tag), ADR 003 (Publish C++ through a vcpkg git registry).

There is no inbound vendor callback. The bytes the library reads are the caller's packet, checked against the golden fixture, not a vendor schema.

## 6. Non-Functional Requirements

| Requirement | Target | Measurement | Priority |
|------------|--------|-------------|----------|
| Availability | none — no service | — | — |
| Latency | 100000 position round trips ≤ 1 second on one core | elapsed time of that loop | High |
| Throughput | the same loop | iterations per second | High |
| Data retention | none | the library stores nothing | — |
| Recovery | a later call is unaffected by a short packet | pack after a failed unpack still matches the golden hex | High |
| Scalability | one call does not share state with another | two sequential calls | Medium |

## 7. Security Architecture

**Authentication**: none inside the library

**Authorization**: none

**Data protection**:
- At rest: the library does not store the packet
- In transit: the caller chooses the socket
- Secrets management: registry tokens stay in GitHub Actions secrets and are absent from the published archive

**Audit logging**: none. The short-packet error is the caller's to log.

## 8. Key Architectural Decisions

### ADR-001: Walk the field list with runtime primitives

**Context**: The packet size is the caller's layout. A tagged serializer changes that size.

**Decision**: Each language uses little-endian primitive writes. No code generator in the first release.

**Alternatives considered**:
1. Protobuf — rejected because it adds tags and does not promise identical bytes
2. Kaitai Struct — rejected because write support is Java and Python, and it is a generator

**Consequences**: Each language writes the list by hand. Golden fixtures catch drift.

> See ADR 001 (Walk field lists with runtime primitives).

### ADR-002: Publish from a version tag

**Context**: The packages must appear on the public registries without a laptop upload.

**Decision**: GitHub Actions runs tests on every push and pull request. A version tag publishes the six packages from the same commit after the golden bytes match on every one of them. The C++ package is vcpkg `packbin`, pushed as a public git registry.

**Alternatives considered**:
1. GitHub Packages — rejected because a public install still asks for a token
2. Trusted publishing — documented by the registries, not selected; credentials stay in the CI secret store

**Consequences**: A golden mismatch publishes 0 packages.

> See ADR 002 (Publish six packages from a version tag), ADR 003 (Publish C++ through a vcpkg git registry).
