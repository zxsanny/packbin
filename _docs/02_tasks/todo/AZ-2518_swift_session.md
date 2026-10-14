---
loop: 26
branch: dev
---

# Swift PackSession matching C#, with an in-package ChaCha20

**Task**: AZ-2518_swift_session
**Name**: Swift PackSession matching C#, with an in-package ChaCha20
**Description**: Swift `PackSession` gives C#'s ciphertext for the same seed, value and row, per the pack-session contract; ChaCha20 is written in the package and matches RFC 8439; `swift-crypto` becomes the only dependency, for non-Apple platforms.
**Complexity**: 5 points
**Dependencies**: AZ-2513
**Component**: swift
**Tracker**: AZ-2518
**Epic**: AZ-2223

## Problem

Swift apps that talk to a C# or browser peer over the encrypted session need the same stream (contract `_docs/02_document/contracts/library/pack-session.md` v1.0.0). CryptoKit has HKDF but no raw ChaCha20 stream, and the owner chose an in-package ChaCha20 over `_CryptoExtras` (S-2), so the cipher is Swift code that must be proven against RFC 8439. This grows the task from Go's 3 points.

Feature ACs and scenarios: `_docs/02_task_plans/swift-package/` (owns SW-6 and SW-11; contributes to SW-14 (one task at a time); scenario S12 owned).

## Outcome

- Same seed (bytes 1..32), 16-byte value `01` + 15 zero bytes and the AC-1 row give ciphertext `b55d0a29c56c203712b241232e`.
- Session AC-2 to AC-7 hold; the ChaCha20 block and stream outputs equal RFC 8439 §2.3.2 and §2.4.2.
- `Package.swift` has exactly one package dependency, `swift-crypto`, linked only on non-Apple platforms.

## Scope

### Included

- `PackSession` load/start/join/pack/unpack per the contract: HKDF-SHA256 (IKM seed, salt the 16 bytes, info `packbin`, 64 bytes), per-direction keys, counter nonce little-endian, ChaCha20 (RFC 8439) block counter 0, XOR only; the seed wiped after use; `start()` draws its 16 bytes from the system random generator of the standard library.
- HKDF-SHA256 from CryptoKit on Apple platforms and from `swift-crypto` (`Crypto`) elsewhere, same results on both.
- ChaCha20 block function and stream in the package, with the RFC 8439 vectors as tests.
- `Package.swift` gains `swift-crypto` at an exact version, its product used by `Packbin` only on non-Apple platforms (`.when(platforms: [.linux, ...])`); `Package.resolved` committed with that pin.
- Package docs: a `PackSession` is used by one task at a time (SW-14).
- Owns (exclusive write): `swift/**`, `Package.swift`, `Package.resolved`

### Excluded

- The session ring (AZ-2522)
- The CI dependency check (AZ-2521)

## Acceptance Criteria

**AC-1: C# ciphertext (SW-6, S12)**
Given seed bytes 1..32, value `01000000000000000000000000000000`, the AC-1 row
When the opener packs, on macOS (CryptoKit) and on Linux (`swift-crypto`)
Then the bytes are `b55d0a29c56c203712b241232e` on both

**AC-2: Session criteria (SW-6, S12)**
Given session AC-2 to AC-7 (`_docs/02_task_plans/pack-session/acceptance_criteria.md`)
When run in Swift
Then each holds: round trip both ways, a second packet, two clients from the same seed with different 16-byte values differ, 0 sessions from a 31-byte seed or 15-byte value, pack before start/join throws

**AC-3: Hostile session input (SW-6)**
Given the TypeScript `session` test rows and the hostile session rows of the other packages
When run in Swift
Then thrown errors; traps 0

**AC-4: RFC 8439 vectors (SW-6)**
Given the RFC 8439 §2.3.2 block vector and the §2.4.2 encryption vector (114-byte plaintext over two blocks, block counter 1)
When the in-package ChaCha20 runs
Then the key stream and ciphertext equal the RFC bytes; mismatches 0

**AC-5: One dependency (SW-11)**
Given `Package.swift` and `Package.resolved`
When inspected, and the package is built on macOS and on Linux
Then exactly 1 package dependency (`swift-crypto`) at an exact version; on macOS the built `Packbin` links no product of it; on Linux it links `Crypto`; unsafe flags 0; C targets 0

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-1 | C# vector | exact hex |
| AC-2 | session AC-2..7 | hold |
| AC-3 | hostile session | thrown errors, no trap |
| AC-4 | RFC 8439 §2.3.2, §2.4.2 | exact bytes |
| AC-5 | manifest, resolved pin, linked products | as stated |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-1 | ring `pack-session`, session ring (AZ-2522) | Swift in the ring | C# ciphertext | — |

## Constraints

- Swift copies TypeScript at HEAD row for row (loop 26 fit decision 4). A disagreement found while porting is reported to the parent, not decided inside the task (probe-first).
- ADR-001: hand-written, no import or wrapper of another package. S-2: no `_CryptoExtras`, no other crypto library; HKDF only from CryptoKit / `swift-crypto`. Unsafe flags 0, C targets 0.
- Local runs are `swift test` at the repository root on the owner's Mac (Swift 6.3.3, CryptoKit path); the Linux path runs in `swift:6`. No language feature newer than Swift 5.9.
- Errors are thrown as the typed `PackbinError`; no trap escapes `PackSession` on any input. ChaCha20's 32-bit word additions use wrapping arithmetic (Swift's `+` traps on overflow); the block counter is never carried past 2^32 − 1 (a payload is at most 16 MiB, far below that).

## Risks & Mitigation

**Risk 1: Hand-written cipher**
- *Risk*: An in-package ChaCha20 can be wrong in ways one vector misses (word order, counter placement, partial last block).
- *Mitigation*: The RFC block and stream vectors, the C# ciphertext, and the session ring with seven other languages (AZ-2522) all check it; the 114-byte stream vector covers a partial block.

**Risk 2: The dependency is resolved on Apple platforms too**
- *Risk*: SwiftPM fetches a package dependency on every platform; the platform condition only stops it being linked. A macOS consumer still clones `swift-crypto` on resolve.
- *Mitigation*: AC-5 measures what is linked on Apple platforms (0 products), not what is resolved; the README (AZ-2524) says so.

**Risk 3: Network dependency in CI**
- *Risk*: `swift-crypto` is the first package pulled from the network by the Swift CI.
- *Mitigation*: Exact pin in `Package.resolved`; the SwiftPM cache is a named volume in compose (AZ-2521).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| SW-11 says "on Apple platforms the package has 0 dependencies", but SwiftPM resolves (clones) `swift-crypto` on every platform; only linking is conditional | AC-5 reads SW-11 as 0 linked dependencies on Apple; parent confirms the reading | open | Medium |
| `swift-crypto` 3.x requires `swift-asn1`, so `Package.resolved` on Linux pins 2 packages for 1 direct dependency (as Go allowed `golang.org/x/sys // indirect`) | allowed as a transitive pin of the one direct dependency; parent confirms | open | Low |
