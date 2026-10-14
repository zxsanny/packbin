# Batch 6 report — loop 26

Task: AZ-2518 (Swift PackSession matching C#, with an in-package ChaCha20, 5 points; stream A, `swift/**`, `Package.swift`, `Package.resolved`). No per-batch review (owner preference).

| Task | Status | Evidence |
|------|--------|----------|
| AZ-2518 | Done on macOS; Linux path not run | 5 of 5 ACs on macOS; 291 tests in 47 suites (parent re-run: pass in 29 s; strict release build 0 warnings); thread sanitizer 291 pass, 0 reports (worker); C# ciphertext `b55d0a29c56c203712b241232e` and TypeScript's keyed vectors match; RFC 8439 §2.3.2/§2.4.2 and a 5-block stream cross-checked against OpenSSL 3.6; 15 of 15 mutation proofs red (3 guards unreachable by a test and documented). The swift-crypto (Linux) path, including AC-1 on Linux and the `swift:5.9` library build, is proven by the first CI run. |

CI-parity: as batch 2. Parent change to `run-suite.sh`: SW-11's dependency check is now "exactly one, swift-crypto" (the real `swift package describe` lists exactly `swift-crypto`); `run-suite.test.sh` S7 updated (no dependency now fails).

## Dependency (owner decision S-2, network fetch)

`Package.swift` declares `swift-crypto` `exact: "3.12.5"` (the newest release at swift-tools-version 5.9; 3.13.0 and later need 5.10) for `.linux`, `.android`, `.windows`, `.wasi`; `Package.resolved` pins swift-crypto 3.12.5 and swift-asn1 1.3.2 (the newest at tools 5.9; SwiftPM alone would pick 1.7.3 at tools 6.1, which `swift:5.9` cannot load). Both were fetched from github.com by SwiftPM during the worker's build; nothing else was downloaded.

## Discovered during implementation

| # | Finding | Handling | clear/unclear |
|---|---------|----------|---------------|
| 1 | unpack with an unusable scheme list spends a position (TypeScript, C#); Go does not | Swift follows TypeScript and C#; `parity_differences.md` | clear |
| 2 | `@testable import` fails in `swift build -c release --build-tests`, so the RFC tests reach the cipher through `@_spi(Vectors) public enum ChaCha20` (outside the public API) | parent: accepted | resolved |
| 3 | `swift:5.9` consumers rely on SwiftPM skipping dependency versions whose tools version it cannot read (swift-asn1 pin) | the `swift-min` CI step shows it | unclear |
| 4 | SwiftPM clones swift-crypto on Apple platforms too (0 objects built) | the README says so (AZ-2524) | clear |
| 5 | platform list copies swift-crypto's `[.linux, .android, .windows, .wasi]`; FreeBSD/OpenBSD do not compile | leave | clear |
| 6 | tvOS/watchOS: CryptoKit HKDF needs tvOS 14 / watchOS 7; `PackSession` is `@available(tvOS 14, watchOS 7, *)`; not verified (no SDK here) | note in the README | clear |
| 7 | counter overflow refusals, session API shape, seed wipe "where Swift allows" | `parity_differences.md`, docs | clear |
| 8 | `build_linksCryptoOnlyWhereCryptoKitIsMissing` is weak on macOS (only the manifest test caught mutation 15) | meaningful on Linux | clear |
