# Feature assessment — loop 71

loop: 71
feature: frame-mode-csharp-java-swift (frame mode in C#, Java and Swift; AZ-3232, AZ-3233, AZ-3234, AZ-3235; epic AZ-3199)
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-10-25
**Implement pass**: batch 01 (`d99414e`), report `_docs/03_implementation/batch_01_loop71_report.md`
**Verdict**: COMPLETE — 12 covered / 1 out-of-scope / 0 gap-clear / 0 gap-unclear (the Linux Swift run is a step 11 check, row D7 below)

Test files by package: C# `csharp/tests/Frame*.cs`, `CryptoVectorTests.cs`; Java `java/src/test/java/packbin/Frame*Test.java`, `CryptoVectorsTest.java`; Swift `swift/Tests/PackbinTests/Frame*Tests.swift`, `CryptoVectorTests.swift`. Production paths: C# `csharp/FrameSession.cs`, `MacKey.cs`, `ReplayWindow.cs`, `FrameCrypto.cs`; Java `FrameSession.java`, `MacKey.java`, `ReplayWindow.java`, `FrameCrypto.java`; Swift `FrameSession.swift`, `MacKey.swift`, `FrameTypes.swift`, `FrameCrypto.swift`.

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | a C# server opens a frame a node sealed | covered | AC-1, AC-G3.2; `FrameVectorTests` / `FrameVectorsTest` / `FrameVectorTests` replay all 157 rows incl. E1 to E5 against the Rust bytes; `FrameSession.Seal` / `seal` / `seal(direction:...)` | intake |
| S2 | a station hears one frame twice | covered | AC-5; `FrameReplayTests`, `FrameTamperReplayTest`, `FrameReplayTests.swift` count 0 MAC computations; replay check before the tag in `Open` / `open` | intake |
| S3 | frames out of order inside 64 counters | covered | AC-1, AC-5; the 17-step `replay` rows and `ReplayWindow.Check` / `commit` | intake |
| S4 | a bit flipped anywhere / changed msg_id, kind, direction, epoch, key | covered | AC-4; `FrameTamperTests`, `FrameTamperReplayTest`, `FrameTamperTests.swift` sweep E1 to E3; tag check in `FrameCrypto` | intake |
| S5 | key rotation, previous slot | covered | AC-6; the previous-slot tests in the replay files; `SetPrevious` / `setPrevious` and the second tag check in `Open` | intake |
| S6 | body 256, ad 256, short body, output one byte short | covered | AC-8; `FrameRefusalTests`, `FrameMacRefusalsTest`, `FrameRefusalTests.swift`; argument checks at the top of seal/open | intake |
| S7 | epoch 0xFFFFFF / 0x1000000, direction 0/4, kind 16, tag_len 0/5/32 | covered | AC-1; the boundary rows of `vectors.txt`; `Load` / `load` ranges and `FrameDirection(number:)` | intake |
| S8 | the 4-byte network MIC over 1, 2, 3 parts | covered | AC-7; `FrameMacOnlyTests`, `FrameMacRefusalsTest`, `FrameMacTests`; `MacKey` | intake |
| S9 | one session from many threads | covered | AC-11; `FrameConcurrencyTests` (8 threads x 1,000 seals), the Java lifecycle test, `ConcurrencyTests.swift` under the thread sanitizer; `Seal` holds no mutable state; setters documented as not concurrent | intake |
| S10 | release while a caller still holds the session | covered | AC-10; `FrameWipeAndCompareTests`, `FrameLifecycleTest`, `FrameWipeTests`; Dispose/close/deinit zero the key arrays, use afterwards is `BadValue` | intake |
| S11 | a caller reuses a msg_id | out-of-scope | `scenarios.md` S11; bold rule in README and docs of seal and the context type | intake |
| S12 | existing stream sessions | covered | AC-12; existing session suites pass in all three packages (4305 / `test.sh` / 461); `PackSession` untouched | intake |
| S13 | C# on netstandard2.0 | covered | AC-12; the second `dotnet test` run with `-p:PackbinTarget=netstandard2.0`, 4305 passed; no `CryptographicOperations` call | intake |

### Discovered during implementation

Ten rows in the batch report, nine `clear` and handled (extra error values in C# and Java, a fourth Swift kind `buffer_full`, no pad states in managed HMAC, setters not concurrent, null versus throw, Swift-only argument checks, source-text compare check, corrected row counts, Java `SessionPad` overloads). One row (D7) is open until step 11: Linux `swift-crypto` could not be run by the worker; the Swift Docker stage of `scripts/loop-tests.sh` runs it. A failure there is a defect of AZ-3234 to fix in this loop, not a new scenario.

### Not walked

- Several senders sharing one replay window (the caller owns one per sender; documented).
- A frame session from a `PackSession`; per-key-slot windows (F69-2); hardening of `hkdf.rs`; a cross-language frame ring (owner, out of scope).
- Java on a real Android device and Swift on an iOS device (no device run; the Android API 26 check and the macOS suite stand in).
