# Loop 71 smoke — checks

LOCAL_URL: none (a library: frame mode in the C#, Java and Swift packages; nothing to open)
Branch: dev
Script: `smoke71.sh` in this folder (`bash _docs/loops/loop71/smoke71.sh`, about 4 minutes on a quiet host; needs dotnet, a JDK, the Xcode Swift toolchain, python3).

## Checks

- [x] 1. the working tree is clean at the commit that precedes the close commit
- [x] 2. AZ-3232: the C# frame and primitive tests pass on `net10.0` and `netstandard2.0` (66 tests each)
- [x] 3. AZ-3233: `java/test.sh` passes with `api-check` (Android API 26) and the 7 frame test classes
- [x] 4. AZ-3234: the Swift frame, primitive, README, error-kind and concurrency suites pass
- [x] 5. AZ-3235: the README examples for C#, Java and Swift equal their example tests
- [x] 6. the frame and primitive fixture checks pass against the Python reference
- [x] 7. AZ-3232..3234 AC-12: `PackSession` in the 3 packages, `rust/` and `fixtures/` are unchanged since the claim `6fd61df`
- [x] 8. no new source or test file is over 500 lines

## Result

Agent run 2026-10-25 at `347d38c` (owner rule 2026-10-12): **8/8 steps passed**, after step 11 (csharp, java, swift, scaffold, ring, ac10 PASS; publish-gate PASS twice, the second time on the final tree after the security fixes: 330 s). The first smoke run failed step 2 for a defect of the script itself (`env VAR=1 limit ...` cannot call a shell function); the script was fixed (`347d38c`), not the check.

## Agent walk

No browser (no UI).

## For the operator

- CI of the push (`dev` and `main`): read the `csharp`, `java`, `swift` and `scaffold` jobs; the Swift Linux job (swift-crypto) and the Java job on the CI JDK are the ones the Mac cannot reproduce.
- A real Android device and an iOS device are not covered.
