# Feature assessment — loop 72, frame hardening in C#, Java and Swift

Intent: `_docs/02_task_plans/frame-hardening-csharp-java-swift/problem.md`. The loop closes items 5, 6, 7, 8 and 10 of the loop 71 security review (`_docs/05_security/frame_mode_managed_loop71.md`) in the packages meshbell's C# server, Android app and iOS app use, with no change to the wire bytes. Delivered in commit `ce0658a` (AZ-3254, AZ-3255, AZ-3256).

| Intent row | Spec / AC | Delivered | Status |
|------------|-----------|-----------|--------|
| Item 5: test hooks reachable from apps | AC-1 (rewritten for owner decision B) | Swift `@_spi(Vectors) public` changed to `package` (SE-0386); the tests use a plain `import`. The strict release test build passes with no flag, and a probe from outside the package fails to compile. C# `internal` and Java package-private kept as each language's official own-tests visibility. | covered (decision B) |
| Item 6: unwiped pad and HMAC temporaries | AC-2 | Wiped: C# and Java `state`, `work` and pad block; Java `full`, T(i) and compare copies; Swift pad and stream keys through `FrameCrypto.wipe`; Swift full HMACs. Code-read list in `batch_01_loop72_report.md`. | covered |
| Item 7: Java static MAC counter | AC-3 | Per-instance `AtomicLong` in `FrameSession` and `MacKey`; `FrameStaticStateTest`; the broken copy of `open` fails the replay test | covered |
| Item 8: C# `Load` with no direction | AC-4 | Returns a session; `Seal` and `Open` in directions 1 to 3 are `BadValue` and write nothing; the other refusals still return null | covered |
| Item 10: C# `Seal` with overlapping buffers | AC-5 | Body built in a stack buffer and written last; 4 layouts on `E1.seal` and `E3.seal`, plus `Open` overlap; 3 of 8 cases fail on the old order | covered |
| Bytes unchanged | AC-6 | Package suites green (157 frame rows, 27 crypto rows); ring and stream sessions in step 11 | covered (step 11) |
| Speed | AC-7 | Load-aware checks green; Swift release speed 2.080 s (HEAD 2.06 to 2.09 s) | covered |
| Out of scope | — | Rust `hkdf.rs`, F69-2, other packages, frame ring: untouched | out-of-scope |

Verdict: **COMPLETE**. Every intent row is covered; item 5 in C# and Java is closed by the owner's decision B rather than by a code change. No EXTEND or CLARIFY.
