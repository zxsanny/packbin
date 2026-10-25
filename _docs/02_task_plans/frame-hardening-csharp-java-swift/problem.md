---
loop: 72
branch: dev
---

# Loop 72: harden frame mode in C#, Java and Swift (AZ-3199 follow-up)

Phase 1 grasp confirmed (owner, 2026-10-25, AskQuestion at loop start, recommended option "Harden C#/Java/Swift frame").

## What

Loop 71 shipped frame mode (contract `pack-session.md` 2.0.0, ADR 008) in the C#, Java and Swift packages. The independent security review of that work (`_docs/05_security/frame_mode_managed_loop71.md`) found no Critical or High and carried five items: 5, 6, 7, 8 and 10. meshbell's C# server, Android (through Java) and iOS (through Swift) run this code, so this loop closes those five items. Wire bytes do not change: the 157 rows of `fixtures/frame/vectors.txt`, the 27 rows of `fixtures/crypto/vectors.txt` and the stream session vectors stay byte for byte as they are.

| # | Review item | Packages | Change |
|---|-------------|----------|--------|
| 5 | Test hooks that return key bytes (`derivedKeys`, `storedKey`, `*ForTest`, `KeyArray`, `KeyArrays`, `CurrentKeys`) ship in release builds; Swift has them `public` | C#, Java, Swift | No member reachable from outside the package in a shipped build returns a stored key, a derived key or the MAC counter; the tests still read them |
| 6 | `SessionPad` leaves the ChaCha20 `state` and `work` words unwiped (C#, Java); the Java `full` HMAC arrays are not wiped; the Swift pad is zeroed by a plain loop the optimizer may drop | C#, Java, Swift (shared stream code) | Every temporary that held key-derived words or pad bytes is overwritten before it goes out of scope, with a wipe the compiler does not remove where the platform has one |
| 7 | Java counts every HMAC in one `static AtomicLong` (`FrameCrypto.MAC_COMPUTATIONS`) on the production path, shared by all sessions and threads | Java (C# already counts per instance) | No static mutable state in Java frame code; each `FrameSession` and `MacKey` counts its own MAC computations |
| 8 | C# `FrameSession.Load` returns null for an empty direction set; Rust, Java and Swift build a session whose every call is `BadValue` | C# | C# builds that session too |
| 10 | C# `Seal` with `plain` or `clear` overlapping `output` corrupts the message (it stays authenticated and leaks nothing) | C# | `Seal` writes the same bytes whatever the overlap |

## Code sections / UI locations for this loop

Owner words: the chosen option named `csharp/`, `java/` and `swift/` and the five carried Lows (test hooks, `SessionPad` wipe, Java static MAC counter, C# `Load` with no direction, C# `Seal` with overlapping buffers).

- C#: `csharp/FrameSession.cs`, `csharp/MacKey.cs`, `csharp/FrameKeys.cs`, `csharp/FrameTypes.cs`, `csharp/SessionPad.cs`, `csharp/Packbin.csproj` (`InternalsVisibleTo`), the frame tests in `csharp/tests/`.
- Java: `java/src/main/java/packbin/FrameSession.java`, `MacKey.java`, `FrameCrypto.java`, `SessionPad.java`, the frame tests in `java/src/test/java/packbin/`, the jar build in `java/test.sh` and the publish scripts if the hook change needs the jar manifest.
- Swift: `swift/Sources/Packbin/FrameSession.swift`, `MacKey.swift`, `FrameCrypto.swift`, `ChaCha20.swift`, the frame tests in `swift/Tests/PackbinTests/` (`FrameWipeTests.swift`, `FrameReplayTests.swift`, `FrameVectorRows.swift`).
- Shared, read only: `fixtures/frame/vectors.txt`, `fixtures/crypto/vectors.txt`, `_docs/02_document/contracts/library/pack-session.md` (2.0.0), the Rust reference `rust/src/nostd`, `rust/src/session_core`.

Out of scope: Rust (`hkdf.rs` temporaries, `frame` with `std`), a replay window per key slot (F69-2), Python, TypeScript, Go and C++, a cross-language frame ring.

## Flagged concerns

| concern | policy / owner | status | severity |
| --- | --- | --- | --- |
| How a test reads a key without a shipped hook differs by runtime (Swift `@testable import`; C# `InternalsVisibleTo` or reflection; Java package-private plus a sealed jar or reflection); the `ac10` stage builds the C# tests in Release | new-task decides per package; the outcome is AC-1 | open | Low |
| A wipe of a local array or a stack span is best effort in managed runtimes (JIT dead-store elimination, GC copies); L71-1 already says so in the docs | documented, not a guarantee | accepted-risk | Low |
| Two more 64-byte clears per ChaCha20 block slow the stream pad and the frame cipher a little; the load-aware timing tests bound the session | AC-7 | open | Low |
| C# `Load` with no direction changes from null to a session (an API change in a package with no published version yet) | owner chose "match the others" | resolved | Low |

Acceptance criteria: `acceptance_criteria.md`. Expected results: `input_data/expected_results/results_report.md`.
