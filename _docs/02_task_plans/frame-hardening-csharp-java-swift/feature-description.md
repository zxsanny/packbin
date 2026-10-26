# Feature: harden frame mode in C#, Java and Swift (loop 72)

This loop closes the five carried Lows of the loop 71 security review (`_docs/05_security/frame_mode_managed_loop71.md` items 5, 6, 7, 8 and 10) in the three managed packages that meshbell's C# server, Android and iOS use. First, no shipped build exposes a member that returns key bytes or the MAC count, and the tests still read them. Second, the ChaCha20 block words, the pad and the full HMAC outputs are wiped before they go out of scope. Third, Java counts MAC computations per instance instead of in a static counter. Fourth, C# `FrameSession.Load` with no direction builds a session that refuses every call, as Rust, Java and Swift do. Fifth, C# `Seal` gives the same bytes whatever the overlap between its inputs and `output`. Wire bytes and the frame and crypto vectors do not change. New-task estimate: 8 points (C# 3, Java 3, Swift 2), split by package on disjoint trees. Problem: `problem.md`. Criteria: `acceptance_criteria.md`.

## Scenarios

See `scenarios.md` (all rows `confirmed`).

## Fit decisions

| Card | Collision | Chosen option (auto-applied, 2026-10-26) | Rejected options |
|------|-----------|-------------------------------------------|------------------|
| F1 | The tests read live key arrays and the MAC count through members that ship | **Owner decision B (2026-10-26), replacing the auto-applied A**: each language's official own-tests visibility. Swift `package` (SE-0386) in place of `@_spi(Vectors) public`; C# `internal` + `InternalsVisibleTo` and Java package-private as at loop 71. A plain `@testable` broke the one release test build (`run-suite.sh` `swift_speed`); `package` passed it on a HEAD copy with no flag. Superseded A: C# and Java delete the hooks (`KeyArrays`, `CurrentKeys`, `MacComputations`, `MacKey.KeyArray`; `encKeyForTest`, `macKeyForTest`, `macComputationsForTest`, `MacKey.keyForTest`), and a test-support helper reads the private fields by reflection. Swift makes `derivedKeys(for:previous:)` and `storedKey` `internal`, and the three test files that use them `@testable import Packbin` | C#: an `InternalsVisibleTo` gated by a build property, which builds Packbin twice. Java: a sealed package in the jar manifest, which leaves the hooks in the jar and still allows reflection |
| F2 | Java counts every HMAC in one static `AtomicLong` shared by all sessions and threads | **A**: a per-instance `AtomicLong` in `FrameSession` and in `MacKey`; the tests read it through a package-private `macComputationsForTest()` (decision B) | Dropping the count altogether would lose the proof that a replay refusal starts no MAC |
| F3 | C# `Seal` writes `clear` into `output` and then reads `plain` and `ad`, so an overlap corrupts the frame | **A**: build `clear ‖ ciphertext ‖ tag` in a stack buffer of at most 255 bytes, reading `ad`, `clear` and `plain` before the first write to `output`, then copy the buffer out | Refusing overlap as `BadValue` would turn away callers who seal in place |
| F4 | C# `Load` with no direction returns null; Rust, Java and Swift return a session | Owner, 2026-10-25: C# matches the others | — |
