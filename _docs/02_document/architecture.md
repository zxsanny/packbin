# packbin — Architecture

## Architecture Vision

packbin is a library: the caller writes a field list, pack and unpack move the exact bytes, and GitHub Actions tests every branch push and pull request and publishes C#, TypeScript, Python, Rust, C++, and Java on a version tag, and tags Go from the same commit (a `go/vX.Y.Z` git tag, ADR 004), after every one of them matches the golden hex. Swift installs from that `vX.Y.Z` tag itself (the root `Package.swift`); after the same gate the release run checks that a throwaway consumer resolves and builds the tag (ADR 005).

**Components and ownership**

- Field list — the caller owns the packet description
- C# package — pack and unpack for .NET
- TypeScript package — pack and unpack for Vue, React, and Node
- Python package — pack and unpack for tools and scripts
- Rust package — pack and unpack for a native node
- C++ package — pack and unpack for a C++ program or 32-bit firmware, from one allocation-free core
- Java package — pack and unpack for a Java program
- Go package — pack and unpack for a Go program; the seventh package, shipped as a git tag `go/vX.Y.Z` of the module `github.com/zxsanny/packbin/go`, not uploaded to a registry (ADR 004)
- Swift package — pack and unpack for a Swift program (iOS, macOS, Linux); the eighth package, resolved by Swift Package Manager from the root `Package.swift` at the `vX.Y.Z` tag, with no registry upload and no Swift tag (ADR 005; `components/08_swift_package/description.md`)
- GitHub Actions — tests (three jobs: `scaffold`, `embedded` and the cross-language `ring`) on every branch push and pull request, publish on a version tag (after the tests pass on the tagged commit)

**Principles**

- The bytes are only the fields (one opt-in exception: a scheme may declare parity bytes that detect and repair a corrupted message, ADR 007; a scheme that does not has no extra byte)
- The first release has no code generator
- A short packet returns an error and no value. In C++ the error is a `Result` and the row keeps the fields read before it
- Unpack treats its bytes as hostile (loop 11). In C#, TypeScript, Python, Rust, Java and Go it returns an error value, within a time and memory bound set by the input length, and never throws; Swift throws a `PackbinError` within the same bounds and never traps (the typed C# `Unpack` of a packet that holds a `repeat` or `times` round used to throw, F17; since loop 20 it returns an error value when the row cannot hold the lists of rounds, and a C# collection member that could throw is refused when the scheme is built since loop 18). In C#, TypeScript, Java, Rust, Python, Go and Swift a scheme also refuses a `repeat` or `times` round past 65,535 rounds, or past 1,048,576 slots for the whole call (4,194,304 before loop 22), so the memory of the rounds is set by the scheme's limits, not by the packet (loop 15, Python since loop 16; the scheme can raise them; C++ unpacks into fixed arrays, so it needs no limit). A `times` round or a `list`/`dict` element that reads nothing is an error; a `repeat` round that reads nothing ends the repeat and the rest is trailing bytes (C++ ends a `times`, `list` or `dict` container on such a round instead of failing, see below). The error shape is interim until C15
- Pack bounds its output the way unpack bounds its rounds (loops 19 and 20). In C#, TypeScript, Python, Java, Rust, Go and Swift a scheme refuses, before the write, a `times` count or a `repeat` list above `maxRounds`, rounds that would hold more than `maxSlots` slots (charged per round with the width the package's unpack charges; since loop 21 one rule in all six: the distinct names a round can hold), and a packet longer than `maxBytes` (16,777,216 by default, the type byte included; it is also the memory bound of a pack call, 2 to 3 times the packet); the error names the member and the numbers, and the scheme can raise each limit. A `repeat` or `times` whose body holds no member is refused when the scheme is built (loop 21, F33), because a round of it would charge no slot and write no byte, so none of the three limits would bound its work. A lone string in a round is still repeated in every round, so the packet length is the caller's to bound. C++ needs none: it writes into the caller's buffer and its rounds live in fixed arrays
- A `bool` is a flag bit with no payload, set only for `true`, and stands only directly under `flags` or a flag-byte bit; one flags byte holds 8 bits; an empty group that could never set its bit is refused (loop 12). Every package refuses a violation when the field list is built, not when a packet arrives. Loop 18 (AZ-2126) extended this to the kinds a reference may name: a `when` names an integer field, a `u2` slot or a bool, and a bool is compared only with `true`; a count names an integer field or a `u2` slot; every package refuses the rest at construction
- A `when` condition or borrowed count names a field read earlier in its own scope (the top level, one `repeat` or `times` round, one `list` or `dict` element, or a nested row), and a `repeat` or `times` round cannot hold another round (loop 13). Every package refuses a bad reference when the field list is built (Rust by name as well as by numeric id and Python since loop 16, AZ-2117 and AZ-2113). C#, TypeScript and Python refuse a nested round; Rust refuses all but a `times` inside a `repeat`; Java and C++ support it (Java gives each inner name one list per outer round, AZ-2127). In C#, TypeScript, Java and Python a round unpacks to one list entry per round, `null` or `undefined` for a skipped round, and pack reads item i of each list for round i
- Every string is written by the compact text codec, one more runtime primitive under ADR 001 (ADR 006, loop 35). All eight packages write the same bytes; the code tables are part of the format. The C++ core keeps the codec allocation-free: pack takes a caller-sized scratch buffer and unpack copies into `Text<N>`, so the core allocates nothing and throws nothing
- The C++ core allocates nothing and throws nothing

> See ADR 001 (Walk field lists with runtime primitives).

## 1. System Context

**Problem being solved**: Eight languages (six registry packages, one Go module and one Swift package resolved from the version tag) must pack and unpack a binary layout the caller already has, without adding tag bytes that change the size.

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
| proxy.golang.org | HTTPS module proxy (a check, no upload) | Outbound | Go module `github.com/zxsanny/packbin/go`: the release run pushes the git tag `go/vX.Y.Z` and asks the proxy that `go list -m` finds it |
| vcpkg | git registry push | Outbound | C++ package `packbin` |
| github.com via Swift Package Manager | git tag resolve (a check, no upload) | Outbound | Swift package: an app resolves the `vX.Y.Z` tag; the release run checks that a throwaway consumer resolves and builds it at the tagged commit |
| PlatformIO, ESP-IDF component registry, Arduino | registry upload and git branch | Outbound | the same C++ sources for firmware |

> See ADR 003 (Publish C++ through a vcpkg git registry).

## 2. Technology Stack

| Layer | Technology | Version | Rationale |
|-------|-----------|---------|-----------|
| Language | C# | current .NET LTS at first publish | Server runtime |
| Language | TypeScript | current Node LTS at first publish | Vue, React, and Node |
| Language | Python | current stable at first publish | Tools and scripts |
| Language | Rust | current stable at first publish; a heap-free `nostd` API for firmware (`default-features = false`, loop 50) | A native node, or Cortex-M firmware (meshbell) |
| Language | C++ | C++17, freestanding core (`-fno-exceptions -fno-rtti`, no heap) | A C++ program or 32-bit firmware: Cortex-M, ESP32, RP2040 |
| Language | Java | Java 17 (`--release 17`), Android API 26 | A Java program, including Android |
| Language | Go | Go 1.26 minimum (`go 1.26.0` in `go.mod`); CI and compose use `golang:1.27`; standard library plus `golang.org/x/crypto` (ChaCha20 in the internal crypto module `go/crypto.go`, called by frame mode since loop 75, ADR 009), no cgo | A Go program or service |
| Language | Swift | `swift-tools-version: 6.0` (Swift 6 language mode), iOS 15, macOS 12; CI and compose run the suite on `swift:6.3.3`; one dependency, `swift-crypto` (HKDF-SHA256 and HMAC-SHA256 for frame mode), linked only off Apple platforms (CryptoKit there); ChaCha20 in the package | A Swift program on iOS, macOS or Linux |
| Framework | none | — | A library, not an application |
| Database | none | — | No stored packets |
| Cache | none | — | Each call is independent |
| Message Queue | none | — | The caller owns the socket |
| Hosting | none | — | No server |
| CI/CD | GitHub Actions | — | Tests on branch push and pull request. Publish on a version tag, after the called tests pass |

> See ADR 002 (Publish six packages from a version tag), ADR 004 (Go ships as a git tag from the same commit) and ADR 005 (Swift installs from the root Package.swift at the vX.Y.Z tag).

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
- The test containers are the current .NET LTS SDK, the current Node LTS image, and the current stable images for Python, Rust, C++, and Java, and `golang:1.27` for Go, and `swift:6.3.3` for Swift
- The heap-free Rust API runs in the same `cpp-embedded` image (loop 50, `rust/embedded/run.sh`; the static library is built by the host cargo for `thumbv7em-none-eabihf` and, since loop 70, `thumbv8m.main-none-eabihf` (the nRF54L15 row `rust-m33f`), the image links it and runs it on QEMU).
- Two more images run the C++ embedded targets: `cpp-embedded` (arm-none-eabi GCC, QEMU, cross g++ for s390x) and `cpp-embedded-esp` (`espressif/idf:v5.3.2`). The embedded harness reports a target as FAIL on a non-zero exit of its function or on a recorded failed check, and the stage exits 1 (loop 16, AZ-2099)
- The `ring` job of `test.yml` runs the cross-language hand-offs (`language-pair.sh`) on the runner itself: it installs the toolchains of the seven other suites (versions in the job env `RING_*`, Go through `actions/setup-go` as `RING_GO`, checked by `ring-toolchains.sh`) and builds the Swift drivers with the runner's Swift, or in the `swift:6.3.3` image when the runner has no `swift` (`RING_SWIFT`, `ring-swift.sh`; `ring-toolchains.sh` requires Swift 6.3.3 either way) and compiles C++ in the `gcc:16` image through `ring-cxx.sh`, because the runner has no GCC 16 release (loop 16, AZ-2193)

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
- One value plus one field list produces one byte buffer, or pack refuses an integer that does not fit (TypeScript range-checks every integer and float width since loop 13; C# refuses a required value that is missing, a dictionary-row number that is not a whole number fitting the field since loop 17, and since loop 18 a `u2` slot, `bits` item or `packed` item that is not a whole number in range, and a `char`, enum or `object` for any numeric field; since loop 20 also a whole-number float in such a slot and in an `eq` against an integer source, and since loop 21 a plain integer field refuses a `float`, `double` or `decimal` too, as unpack returns the exact integer types, AZ-2373)

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

> See ADR 002 (Publish six packages from a version tag), ADR 003 (Publish C++ through a vcpkg git registry), ADR 004 (Go ships as a git tag from the same commit), ADR 005 (Swift installs from the root Package.swift at the vX.Y.Z tag).

The publish builds and checks every artifact before the first upload, and the registry tools then run on the runner host (loop 14). Before each upload the registry is asked whether the version is already there, so a re-run of the tag finishes a partial publish. PlatformIO, ESP-IDF and Arduino are optional targets; the other six registries are required (`_docs/04_deploy/packages.md`). The Go tag is not a registry upload: it is the last step of the run, pushed after every registry target, and only after the same golden gate (ADR 004). The Swift check uploads nothing and creates no tag: after the registry uploads and the Go tag it resolves and builds the `vX.Y.Z` tag in a throwaway consumer, and fails the run when the pin is another commit or the build fails for 30 minutes (ADR 005). The golden gate and the language builds run in containers that mount the repo read-only and write only their own artifacts folder, so a build step cannot change a script the host runs next with the credentials (loop 15).

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

**Authentication**: none in clear pack; frame mode, packbin's only session (ADR-008, ADR-009, `pack-session.md` 3.0.0), encrypts and authenticates with a truncated HMAC-SHA256 tag, with keys the caller holds. Frame mode is in all eight packages (Rust loop 69, C#, Java and Swift loop 71, C++, Go, Python and TypeScript loop 75) under one set of type names (`FrameSession`, `FrameConfig`, `FrameDirection`, `FrameDirections`, `FrameSlot`, `FrameOpened`, `MsgContext`, `ReplayWindow`, `Freshness`, `MacKey`; Java has all of them and adds `FrameSealed`); every package keeps SHA-256, HMAC-SHA256, HKDF-SHA256 and ChaCha20 in an internal, unexported module checked on the 27 rows of `fixtures/crypto/vectors.txt`, and passes the 157 rows of `fixtures/frame/vectors.txt`. Outside Rust, the `MacKey` object holds the 32-byte `K_label` and not precomputed pad states (the platform HMAC does not expose them), so a tag costs two more SHA-256 compressions; the bytes are equal. The C++ frame image on the `cpp-m33f` row is pinned at 8,416 B of flash and 912 B of stack. The stream session (a shared seed, an opener nonce, no tag) was removed in loop 74

> See ADR 008 (Frame mode authenticates; stream mode does not) and ADR 009 (Frame mode is the only session; the stream session is removed).

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

> See ADR 002 (Publish six packages from a version tag), ADR 003 (Publish C++ through a vcpkg git registry), ADR 004 (Go ships as a git tag from the same commit), ADR 005 (Swift installs from the root Package.swift at the vX.Y.Z tag).
