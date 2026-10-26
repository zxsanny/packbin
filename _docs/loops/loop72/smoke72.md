# Loop 72 smoke — frame hardening in C#, Java and Swift

LOCAL_URL: none (library; no site). Branch: dev at ce0658a. Script: `bash _docs/loops/loop72/smoke72.sh`. Run by the agent on 2026-10-26 at host load about 6, under the owner rule of 2026-10-12: one paste script, with the agent auto-passing the gate when every step passes.

## Checks

- [x] 1. No application source is dirty
- [x] 2. C# frame, primitive and session tests pass on net10.0 and netstandard2.0 (AZ-3254 AC-3, AC-4, AC-5)
- [x] 3. C# Release test build (`ac10`) passes (AZ-3254 AC-1)
- [x] 4. Java `test.sh`: `api-check` and the frame test classes pass, including `FrameStaticStateTest` (AZ-3255 AC-1..AC-4)
- [x] 5. Swift frame, primitive, README and session suites pass (AZ-3256 AC-3)
- [x] 6. No SPI and no `@testable` in `swift/`; C# hooks are `internal` and Java hooks package-private (decision B, AC-1)
- [x] 6b. The Swift strict release test build (`run-suite.sh` `swift_speed` command, no extra flag) and the speed run pass (AZ-3256 AC-1, AC-7)
- [x] 7. Java `FrameCrypto`, `FrameSession` and `MacKey` hold no static mutable field (AZ-3255 AC-3)
- [x] 8. The frame and crypto fixture checks pass; `rust/` and `fixtures/` are unchanged since dc98688 (AC-6)
- [x] 9. The README frame examples for C#, Java and Swift equal their tests
- [x] 10. No touched source or test file is over 500 lines

## Agent walk

11 PASS, 0 FAIL, 0 NOT RUN (`smoke72: 0 failed`).

## For the operator

Nothing: every check ran in the script.
