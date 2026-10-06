# packbin — Architecture

## Architecture Vision

packbin is a library: the caller writes a field list, pack and unpack move the exact bytes, and GitHub Actions tests every branch push and pull request and publishes C#, TypeScript, Python, Rust, C++, and Java on a version tag after every one of them matches the golden hex.

**Components and ownership**

- Field list — the caller owns the packet description
- C# package — pack and unpack for .NET
- TypeScript package — pack and unpack for Vue, React, and Node
- Python package — pack and unpack for tools and scripts
- Rust package — pack and unpack for a native node
- C++ package — pack and unpack for a C++ program or 32-bit firmware, from one allocation-free core
- Java package — pack and unpack for a Java program
- GitHub Actions — tests on every branch push and pull request, publish on a version tag (after the tests pass on the tagged commit)

**Principles**

- The bytes are only the fields
- The first release has no code generator
- A short packet returns an error and no value. In C++ the error is a `Result` and the row keeps the fields read before it
- Unpack treats its bytes as hostile (loop 11). In C#, TypeScript, Python, Rust and Java it returns an error value, within a time and memory bound set by the input length, and never throws. In C#, TypeScript, Java and Rust a scheme also refuses a `repeat` or `times` round past 65,535 rounds, or past 4,194,304 slots for the whole call, so the memory of the rounds is set by the scheme's limits, not by the packet (loop 15; the scheme can raise them; C++ unpacks into fixed arrays and Python keeps only values it read, so neither needs a limit). A `times` round or a `list`/`dict` element that reads nothing is an error; a `repeat` round that reads nothing ends the repeat and the rest is trailing bytes (C++ ends a `times`, `list` or `dict` container on such a round instead of failing, see below). The error shape is interim until C15
- A `bool` is a flag bit with no payload, set only for `true`, and stands only directly under `flags` or a flag-byte bit; one flags byte holds 8 bits; an empty group that could never set its bit is refused (loop 12). Every package refuses a violation when the field list is built, not when a packet arrives
- A `when` condition or borrowed count names a field read earlier in its own scope (the top level, one `repeat` or `times` round, one `list` or `dict` element, or a nested row), and a `repeat` or `times` round cannot hold another round (loop 13). C#, TypeScript, Java and C++ refuse a bad reference when the field list is built, and Rust refuses a bad numeric id (a Rust reference by name and every Python reference are not checked yet, AZ-2117 and AZ-2113). C#, TypeScript and Java refuse a nested round; Rust refuses all but a `times` inside a `repeat` (AZ-2127). In C#, TypeScript and Java a round unpacks to one list entry per round, `null` or `undefined` for a skipped round, and pack reads item i of each list for round i
- The C++ core allocates nothing and throws nothing

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
| PlatformIO, ESP-IDF component registry, Arduino | registry upload and git branch | Outbound | the same C++ sources for firmware |

> See ADR 003 (Publish C++ through a vcpkg git registry).

## 2. Technology Stack

| Layer | Technology | Version | Rationale |
|-------|-----------|---------|-----------|
| Language | C# | current .NET LTS at first publish | Server runtime |
| Language | TypeScript | current Node LTS at first publish | Vue, React, and Node |
| Language | Python | current stable at first publish | Tools and scripts |
| Language | Rust | current stable at first publish | A native node |
| Language | C++ | C++17, freestanding core (`-fno-exceptions -fno-rtti`, no heap) | A C++ program or 32-bit firmware: Cortex-M, ESP32, RP2040 |
| Language | Java | Java 17 (`--release 17`), Android API 26 | A Java program, including Android |
| Framework | none | — | A library, not an application |
| Database | none | — | No stored packets |
| Cache | none | — | Each call is independent |
| Message Queue | none | — | The caller owns the socket |
| Hosting | none | — | No server |
| CI/CD | GitHub Actions | — | Tests on branch push and pull request. Publish on a version tag, after the called tests pass |

> See ADR 002 (Publish six packages from a version tag).

**Key constraints from restrictions.md**:

- No tag, length prefix, version byte, or schema id is added to the buffer
- Vue and React do not get their own package
- Registry credentials stay in the CI secret store

### C++ core

The C++ package is one core for host programs and firmware. It writes into a caller buffer and reads from one, keeps no global state, and reports every failure as a `Result` (error kind, byte offset, field order id, bytes needed). Scheme tables are built with `scheme<Row>(...)`, at compile time when `constexpr`, and live in flash. The walker follows these rules (loop 10, batch 5):

- Flag bytes are scoped per container. Each round of a `repeat`, `times`, `list` or `dict` reads its own flag bytes, and the outer ones come back at the end of the container.
- A `repeat` round, or a round of a container with no bound member (`times`, `list`, `dict`), that reads no bytes ends the container. Bound containers stop at their capacity.
- A `boolean` or an empty `group` is valid only directly under `flags` or `flag_bit`; elsewhere the scheme is `SchemeInvalid` (a compile error when `constexpr`).
- A `group(id)` with no children and no member can never set its bit, so it is `SchemeInvalid` wherever it stands, inside `flags` too (loop 12).
- A `u2` holds at most 64 children.

## 3. Deployment Model

**Environments**: a workstation for development, GitHub Actions for the test run, and the public registries for the published packages. There is no staging host.

**Infrastructure**:
- No cloud application host
- No container orchestration for the product
- The test containers are the current .NET LTS SDK, the current Node LTS image, and the current stable images for Python, Rust, C++, and Java
- Two more images run the C++ embedded targets: `cpp-embedded` (arm-none-eabi GCC, QEMU, cross g++ for s390x) and `cpp-embedded-esp` (`espressif/idf:v5.3.2`)

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
| Short packet | Field name, bytes needed, bytes left (C++: order id, byte offset, bytes needed) | unpack |

**Key relationships**:
- One field list describes one packet shape
- One value plus one field list produces one byte buffer, or pack refuses an integer that does not fit (TypeScript range-checks every integer and float width since loop 13; C# refuses a required value that is missing)

**Data flow summary**:
- Value → pack → bytes: the caller sends the bytes on their own socket
- Bytes → unpack → value or error: a short buffer does not yield a partial value. In C++ the fields read before a failure keep their values in the caller's row

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

The publish builds and checks every artifact before the first upload, and the registry tools then run on the runner host (loop 14). Before each upload the registry is asked whether the version is already there, so a re-run of the tag finishes a partial publish. PlatformIO, ESP-IDF and Arduino are optional targets; the other six registries are required (`_docs/04_deploy/packages.md`). The golden gate and the language builds run in containers that mount the repo read-only and write only their own artifacts folder, so a build step cannot change a script the host runs next with the credentials (loop 15).

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
