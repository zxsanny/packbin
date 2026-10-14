# Swift package

## 1. High-Level Overview

**Purpose**: Pack and unpack a caller-owned scheme for Swift programs (iOS, macOS, server-side Swift on Linux), with the same bytes as the other seven packages.

**Architectural Pattern**: stateless clear pack and unpack over an immutable scheme, plus a `PackSession` the caller holds (as the TypeScript and Go packages). Hand-written walkers, no code generation, no wrapper of the C++ core (ADR-001).

**Upstream dependencies**: none inside the repo. Outside: the Swift standard library, and Foundation only where it can be imported, to read a Foundation `NSNumber` in a map row (`ForeignNumber.swift`); the session uses HKDF-SHA256 from CryptoKit on Apple platforms and `swift-crypto` (`Crypto`) on other platforms. The ChaCha20 stream is written in the package and checked against RFC 8439 (§2.3.2, §2.4.2). `swift-crypto` (exactly 3.12.5) is the only package dependency and is declared for non-Apple platforms only; SwiftPM still resolves and clones it, and `swift-asn1`, on Apple platforms, where nothing of it is linked.

**Downstream consumers**: Swift programs, added with `.package(url: "https://github.com/zxsanny/packbin", from: "X.Y.Z")` from the existing `vX.Y.Z` git tag (ADR-005). There is no registry upload and no `swift/vX.Y.Z` tag; the README has the install and the examples.

**Layout**: the manifest `Package.swift` sits at the repository root (Swift Package Manager resolves a package only from there) with `swift-tools-version: 5.9`, platforms iOS 15 and macOS 12, one library product and target `Packbin` at `swift/Sources/Packbin`, tests at `swift/Tests/PackbinTests`.

## 2. Interfaces

Same shape as TypeScript (`components/02_typescript_package/description.md` §2) and Go (`components/07_go_package/description.md` §2): a scheme built from fields by order id, `pack(scheme, row) throws -> [UInt8]`, `unpack(buffer, schemes) throws`, first-byte dispatch over a scheme list, a typed `PackbinError`, and `PackSession` start/join/pack/unpack (`contracts/library/pack-session.md`). The exact Swift names are listed in the package documentation, `swift/Sources/Packbin/Packbin.docc/Packbin.md` (Public names).

Rows: a typed struct bound by getter and setter closures, or `[String: Any]`. `nil` is no value; an empty array is a value with 0 items. Hostile input throws and never traps.

## 3. Rules

Swift copies TypeScript row for row (loop 26 fit decision 4), except the documented TypeScript-only exceptions (U6), where it follows the others; the D1b rows stay as documented.

- A built scheme is immutable and `Sendable`: safe for concurrent `pack` and `unpack`; a `PackSession` is for one task at a time (SW-14).
- Swift traps on arithmetic overflow, index out of range and force unwrap; every size or index derived from input is computed with checked arithmetic, so no input traps (SW-4, SW-15).
- The round limits are TypeScript's (65 535 rounds, 1 048 576 slots, 16 MiB output).

## 4. Decisions

`_docs/02_task_plans/swift-package/problem.md` S-1 to S-5 (owner, 2026-10-14): root `Package.swift`, in-package ChaCha20 with swift-crypto for HKDF on non-Apple platforms, release as a resolve check on the existing tag, tools 5.9 / iOS 15 / macOS 12 / `swift:6`, whole epic in loop 26. ADR-001, ADR-005.

## 5. Tests

`swift test` in the repository root (the manifest is there): golden, parity rows of TypeScript, the hostile vectors (`fixtures/hostile/cases.txt`, 65 cases), session vectors and RFC 8439 vectors, concurrency (8 tasks, thread sanitizer), the fuzz run (60 s in `run-suite.sh swift`), and the README examples (`ReadmeExampleTests.swift`: the README Swift blocks are its snippets, and their output is the README hex). `docker compose -f docker-compose.test.yml run --rm swift` is the suite as CI runs it.

## Deferred

None.
