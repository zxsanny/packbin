# Swift package

## 1. High-Level Overview

**Purpose**: Pack and unpack a caller-owned scheme for Swift programs (iOS, macOS, server-side Swift on Linux), with the same bytes as the other seven packages.

**Architectural Pattern**: stateless clear pack and unpack over an immutable scheme, plus a `PackSession` the caller holds (as the TypeScript and Go packages). Hand-written walkers, no code generation, no wrapper of the C++ core (ADR-001).

**Upstream dependencies**: none inside the repo. Outside: the Swift standard library, and Foundation only where it can be imported, to read a Foundation `NSNumber` in a map row (`ForeignNumber.swift`); the session uses HKDF-SHA256 from CryptoKit on Apple platforms and `swift-crypto` (`Crypto`) on other platforms. The ChaCha20 stream is written in the package and checked against RFC 8439 (§2.3.2, §2.4.2). `swift-crypto` (exactly 4.3.1) is the only package dependency and is declared for non-Apple platforms only; SwiftPM still resolves and clones it, and `swift-asn1`, on Apple platforms, where nothing of it is linked.

**Downstream consumers**: Swift programs, added with `.package(url: "https://github.com/zxsanny/packbin", from: "X.Y.Z")` from the existing `vX.Y.Z` git tag (ADR-005). There is no registry upload and no `swift/vX.Y.Z` tag; the README has the install and the examples.

**Layout**: the manifest `Package.swift` sits at the repository root (Swift Package Manager resolves a package only from there) with `swift-tools-version: 6.0` (Swift 6 language mode), platforms iOS 15 and macOS 12, one library product and target `Packbin` at `swift/Sources/Packbin`, tests at `swift/Tests/PackbinTests`.

## 2. Interfaces

Same shape as TypeScript (`components/02_typescript_package/description.md` §2) and Go (`components/07_go_package/description.md` §2): a scheme built from fields by order id, `pack(scheme, row) throws -> [UInt8]`, `unpack(buffer, schemes) throws`, first-byte dispatch over a scheme list, a typed `PackbinError`, and `PackSession` start/join/pack/unpack (`contracts/library/pack-session.md`). The exact Swift names are listed in the package documentation, `swift/Sources/Packbin/Packbin.docc/Packbin.md` (Public names).

Rows: a typed struct bound by getter and setter closures, or `[String: Any]`. `nil` is no value; an empty array is a value with 0 items. Hostile input throws and never traps.

### Interface: Error correction (loop 38, ADR-007, `contracts/library/message-ecc.md`)

Optional parity bytes per scheme: `n` from 0 to 32, default 0, which keeps the bytes, the errors and the speed of an unprotected scheme. `n` is not on the wire. C++ is pending (AZ-2688).

| Name | Meaning |
|------|---------|
| `withLimits(maxRounds:maxSlots:maxBytes:parity:)` | `parity` sets `n`; left out it keeps this scheme's count (a limit left out is still the default). A count outside 0 to 32 throws `.schemeError` naming `parity`, the count and 32. `Scheme.parity` reads it |
| `unpackRepair(_:limit:_:)`, `unpackMapRepair(_:limit:_:)` | repair up to `limit` wrong bytes (0 to `n / 2`) before the type byte picks the scheme; they return `(row, repaired)`; the schemes may also be given as an array. `unpack` and `unpackMap` are limit 0. Another limit, or a mix of counts, throws `.schemeError` before any byte is read |
| `PackbinError.Kind.uncorrectable` | raw value `uncorrectable`; names no field |
| `.tooMany` (reused) | a buffer above 254 bytes, `left` the length. A buffer shorter than `n` is `.short` naming `parity` |

- **Pack**: a clear message above `254 - n` bytes throws `.packError` naming the length and the limit.
- **Dispatch**: the schemes of one call declare the same `n`; with one `n` the message is repaired first, then dispatched.
- **Session**: `pack` pads, then appends the parity of the padded bytes. `PackSession.unpackRepair(_:limit:_:)` and `unpackMapRepair` repair, drop the parity, remove the pad, then read. The position is spent whether or not the repair succeeds; a bad limit or mix throws before it is spent. With `n` = 0 the payload has the length of clear pack.
- **`t` and detection**: `t` defaults to 0 and then any corruption of up to `n` wrong bytes is detected. A `t` above 0 repairs up to `t` wrong bytes but gives up detection: corruption of `t + 1` to `n - t` bytes is still refused, a larger corruption may be repaired to a different message. The contract table lists the chance (`n` = 4: 1 in 4.29e+09 at `t` = 0, 1 in 990,537 at `t` = 1, 1 in 485 at `t` = 2). `t` above `n / 2` is an error before any byte is read.
- **Size and speed**: a message is at most 254 bytes, parity included; pack refuses a clear message above `254 - n` bytes and writes nothing. Unpack of hostile bytes does at most about 3 x 255 x 32 field operations beyond the unprotected walk and never throws or traps on them. Acceptance bound EC-13 (a bound, not a recorded measurement): 1,000 unpacks with correction of a 254-byte message with 16 parity bytes and 8 wrong bytes in 1 second; 1,000 packs of such blocks in 1 second.

## 3. Rules

Swift copies TypeScript row for row (loop 26 fit decision 4), except the documented TypeScript-only exceptions (U6), where it follows the others; the D1b rows stay as documented.

- A built scheme is immutable and `Sendable`: safe for concurrent `pack` and `unpack`; a `PackSession` is for one task at a time (SW-14).
- Swift traps on arithmetic overflow, index out of range and force unwrap; every size or index derived from input is computed with checked arithmetic, so no input traps (SW-4, SW-15).
- The round limits are TypeScript's (65 535 rounds, 1 048 576 slots, 16 MiB output).

### Frame mode (loop 71, AZ-3234)

| Name | Meaning |
|------|---------|
| `FrameSession.load(key:epoch:config:)` | throws `badValue` for a key not 32 bytes, an epoch above 0xFFFFFF, a tag length other than 4, 8, 16 or no direction; `setPrevious`, `clearPrevious`, `close()` (a closed session throws `badValue`) |
| `seal(direction:context:ad:clear:plain:into:)` | the body length, or a `PackbinError`; writes nothing on a refusal |
| `open(direction:context:ad:body:clearLength:into:)` and the form with `window: inout ReplayWindow, counter:` | a `FrameOpened` (`slot`, `clearLength`, `plainLength`) or a `PackbinError` |
| `ReplayWindow` | a `Sendable` struct: `check(_:)` (`fresh`, `duplicate`, `tooOld`), `commit(_:)`, `top`, `bits` |
| `MacKey.derive(key:epoch:label:)`, `tag(_:length:)`, `verify(_:tag:)`, `close()` | tags of 4, 8, 16 or 32 bytes |
| `PackbinError.Kind` | new cases `tagMismatch` "tag_mismatch", `duplicate` "duplicate", `tooOld` "too_old" and `bufferFull` "buffer_full" (Swift had no buffer-full kind); the pinned case list of `ShortTrailingTests` holds the 9 old values plus these four; the short-packet refusal is the existing `short` |

`FrameSession` and `MacKey` are `@unchecked Sendable`: `seal`, `open`, `tag` and `verify` are safe from many threads; `setPrevious`, `clearPrevious` and `close` are not safe beside another call. Files: `swift/Sources/Packbin/FrameSession.swift` (327 lines), `FrameTypes.swift` (157), `FrameCrypto.swift` (130), `MacKey.swift` (97); the test hooks are `@_spi(Vectors)` (`FramePrimitives`, `FrameProbe`). The 8-task seal test lives in `ConcurrencyTests.swift` (the thread-sanitizer pattern of `run-suite.sh` allows four file names).

- **Frame mode** (loop 71, contract `pack-session.md` 2.0.0, ADR 008): a `FrameSession` beside the stream `PackSession` (which is untouched), a `ReplayWindow` the caller owns (64 messages; `check` never changes state, `commit` only after an `Ok` open) and a `MacKey` for the MAC-only call. Seal and open follow the contract's order (argument checks, then the replay check without any MAC for `Duplicate` and `TooOld`, then the tag with the current key and then the previous key, then decrypt and commit). The bytes equal the Rust ones: the package passes every row of `fixtures/frame/vectors.txt` (157 rows, E1 to E5 included) and the 27 rows of `fixtures/crypto/vectors.txt`. The platform HMAC cannot expose precomputed pad states, so a session holds the 32-byte MAC key per direction and a `MacKey` the 32-byte label key (the contract's 72-byte figure does not apply); the HMAC key schedule runs on each call. Keys are overwritten on release; the tag compare folds every byte with no early exit; both are best effort in a managed runtime (stated in the API docs). The `msg_id` uniqueness rule is in the docs of `seal` and of the message context. A test-only counter of MAC computations proves a duplicate or too-old frame costs none (the Rust figure of SHA-256 compressions has no equivalent here). The README example of the package is the code of its example test (`scripts/frame/readme-examples.sh`).

## 4. Decisions

`_docs/02_task_plans/swift-package/problem.md` S-1 to S-5 (owner, 2026-10-14): root `Package.swift`, in-package ChaCha20 with swift-crypto for HKDF on non-Apple platforms, release as a resolve check on the existing tag, tools 5.9 / iOS 15 / macOS 12 / `swift:6`, whole epic in loop 26 (S-4 amended 2026-10-14, owner decision: Swift 6 only, tools 6.0, CI image `swift:6.3.3`). ADR-001, ADR-005.

## 5. Tests

`swift test` in the repository root (the manifest is there): golden, parity rows of TypeScript, the hostile vectors (`fixtures/hostile/cases.txt`, 65 cases), session vectors and RFC 8439 vectors, concurrency (8 tasks, thread sanitizer), the fuzz run (60 s in `run-suite.sh swift`), and the README examples (`ReadmeExampleTests.swift`: the README Swift blocks are its snippets, and their output is the README hex). `docker compose -f docker-compose.test.yml run --rm swift` is the suite as CI runs it.

The test specification is [tests.md](tests.md) (AC-1 to AC-16, SW-1 to SW-16) and the per-loop list [tests-by-loop.md](tests-by-loop.md); scenarios FT-X-124 to FT-X-155 are in `tests/blackbox-tests-19-loop26-swift-package.md`. Loop 26 step 11: the suite is 335 tests in 55 suites; on the Mac `swift test` 335 pass; the `swift:6.3.3` container stage passed (620 s); Swift 6.0, the declared minimum, was not run.

## Deferred

None.
