# Traceability matrix — loop 71 (AZ-3232 to AZ-3235)

Each AC of AZ-3232 (C#), AZ-3233 (Java) and AZ-3234 (Swift) has the same number and wording; the evidence is the test class of each package. Step 11 of loop 71: csharp, java, swift (rerun after a README block test fix), scaffold, ring, ac10, publish-gate PASS.

| AC | Behavior | Status | Test IDs |
|----|----------|--------|----------|
| AZ-3232/3233/3234 AC-1 | frame vector rows (157) match, E1 to E5, boundary refusals | Covered | C# `FrameVectorTests`; Java `FrameVectorsTest`; Swift `FrameVectorTests` |
| AZ-3232/3233/3234 AC-2 | primitive rows (27) match | Covered | C# `CryptoVectorTests`; Java `CryptoVectorsTest`; Swift `CryptoVectorTests` |
| AZ-3232/3233/3234 AC-3 | fixture loaders not vacuous (one byte changed, row named) | Covered | the same test classes (corrupted temp copies) |
| AZ-3232/3233/3234 AC-4 | single-bit tamper sweep of E1 to E3: `TagMismatch`, sentinel intact, window unchanged | Covered | C# `FrameTamperTests`; Java `FrameTamperReplayTest`; Swift `FrameTamperTests` |
| AZ-3232/3233/3234 AC-5 | duplicate / too-old open computes 0 MACs | Covered | C# `FrameReplayTests`; Java `FrameTamperReplayTest`; Swift `FrameReplayTests` |
| AZ-3232/3233/3234 AC-6 | previous slot: `Previous`, `Current`, `TagMismatch` without it | Covered | the replay test classes above |
| AZ-3232/3233/3234 AC-7 | MAC-only: split independent, flipped bit false, label and n refusals | Covered | C# `FrameMacOnlyTests`; Java `FrameMacRefusalsTest`; Swift `FrameMacTests` |
| AZ-3232/3233/3234 AC-8 | refusal kinds and 1,000 hostile inputs, 0 crashes | Covered | C# `FrameRefusalTests`; Java `FrameMacRefusalsTest`, `FrameHostileTest`; Swift `FrameRefusalTests` |
| AZ-3232/3233/3234 AC-9 | tag compare folds every byte | Covered | C# `FrameWipeAndCompareTests`; Java `FrameLifecycleTest`; Swift `FrameWipeTests` |
| AZ-3232/3233/3234 AC-10 | wipe on release, use after release is `BadValue` | Covered | the same classes as AC-9 |
| AZ-3232/3233/3234 AC-11 | 8 threads seal equals single-thread | Covered | C# `FrameConcurrencyTests`; Java `FrameLifecycleTest`; Swift `ConcurrencyTests` (thread sanitizer) |
| AZ-3232/3233/3234 AC-12 | stream unchanged; targets (net10.0 and netstandard2.0; API 26 and release 17; strict concurrency) | Covered | existing session suites + step 11 csharp, java, swift stages |
| AZ-3235 AC-1 | README examples equal the example tests | Covered | `scripts/frame/readme-examples.sh` (PASS x3; CI step added in `test.yml`) |
| AZ-3235 AC-2 | components and layout list every new type and file | Covered | `components/{01,06,08}_*/description.md`, `module-layout.md` (reviewed) |
| AZ-3235 AC-3 | contract note names the three consumers, version unchanged | Covered | `pack-session.md` Change Log and Consumers |
| loop 71 S5 / AC-G3.2 | the C#, Java and Swift bodies equal the Rust ones | Covered | the 157 shared rows (FT-X-157 fixture) in all four packages |
| loop 71 open | Linux swift-crypto and Android device runs | Open (Linux: Covered by the Docker swift stage; device: not run) | step 11 swift stage; no device |
