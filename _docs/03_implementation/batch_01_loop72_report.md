# Batch 01, loop 72: frame hardening in C#, Java and Swift

Tasks: AZ-3254 (C#), AZ-3255 (Java), AZ-3256 (Swift); epic AZ-3199. Three workers on disjoint trees; the parent wrote the docs. Plan: `_docs/02_task_plans/frame-hardening-csharp-java-swift/`.

## Owner decisions in the batch

- **Decision B (2026-10-26), test hooks.** Each language uses its official own-tests visibility: Swift `package` (SE-0386) replaces `@_spi(Vectors) public`, C# keeps `internal` + `InternalsVisibleTo`, and Java keeps package-private. This replaced the auto-applied fit decision A, under which C# and Java deleted the hooks and read private fields by reflection, and Swift used `internal` + `@testable`. With A, `@testable` broke the one release test build (`run-suite.sh` `swift_speed`: "unable to resolve module dependency 'Packbin'"). `-enable-testing` would have fixed that at 0 to +7% on the speed tests. On a HEAD copy, `package` passed the strict release test build with no flag, and the speed run was unchanged (2.08 s).
- **Decision 2.** The Swift stream `PackSession.wipe` goes through `FrameCrypto.wipe`.
- **Decision 3.** The workers' extra wipes stay.

## Results

| Package | Command | Result |
|---------|---------|--------|
| C# | `env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --nologo` | Passed 4,319, Failed 0 (net10.0) |
| C# | the same with `-p:PackbinTarget=netstandard2.0` | Passed 4,319, Failed 0 |
| C# | `ac10`: `dotnet test csharp -c Release --filter Nfr_PublicTyped` | Passed 1 |
| Java | `bash java/test.sh` | all classes passed, `api-check PASS`, new `FrameStaticStateTest` passed |
| Swift | `swift test` | 461 tests in 80 suites passed |
| Swift | `swift build -c release --build-tests -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete` | complete, 0 warnings, no `-enable-testing` |
| Swift | release speed run (`SpeedTests`, `TextSpeedTests`, `FuzzTests/mebibyte`) | 6 tests passed after 2.080 s |

Checks that the tests bite:
- **C# overlap tests:** with the old `Seal` write order, 3 of 8 seal-overlap cases fail (E1 `ad` inside; E3 `ad` inside; E3 `plain` at start).
- **Java replay counter:** a scratch copy whose `open` computes the tag before the window check fails with `MAC computations for Duplicate and TooOld: expected 0, got 2` and `B's count does not move …: expected 0, got 2`.
- **Swift probe:** a file outside the package, type-checked against the built module, fails with `'derivedKeys' is inaccessible due to 'package' protection level`, `'storedKey' is inaccessible …`, `cannot find 'FrameProbe' in scope` and `extra argument 'probe' in call`; the same holds with `@_spi(Vectors) import Packbin`.

Not run by the workers: the Linux Swift job (`swift:6.3.3`) and the `ring` stage, both of which need docker compose. They run in step 11.

## AC-2: temporaries that hold key words, pad bytes or a full HMAC

| Package | Temporary | Wipe |
|---------|-----------|------|
| C# | `SessionPad.Block` `state`, `work` (16 `uint` each) | `Compat.Zero(MemoryMarshal.AsBytes(...))` (new) |
| C# | `SessionPad.Xor` pad `block` (64 B) | `Compat.Zero` (new) |
| C# | `FrameSession.Seal` `full` (32 B) | `Compat.Zero` after the tag copy (new) |
| C# | `Matches`, `MacKey.Tag` ×2, `MacKey.Verify` ×2 `full`; `FrameCrypto.Finish` bytes | `Compat.Zero` (already there) |
| C# | `IncrementalHash` state | `Dispose` only; the platform keeps its pads |
| Java | `SessionPad.block` `state`, `work` | `Arrays.fill` (new) |
| Java | `SessionPad.xor` `block`; `hkdfSha256` `prk` | `Arrays.fill` (already there) |
| Java | `SessionPad.hkdfExpand` each T(i) | zeroed when the next is computed (new); the last one after the loop (already there) |
| Java | `FrameSession.seal` `tag`, `matching` `full`; `MacKey.tag`, `verify` `full` | `Arrays.fill` (new) |
| Java | `FrameCrypto.constantTimeEquals` range copies | `Arrays.fill` (new) |
| Java | platform `Mac`, `SecretKeySpec` | not reachable (runtime keeps them) |
| Swift | `ChaCha20` `Input` words | `defer { input.wipe() }` through `ChaCha20.zero` (already there) |
| Swift | `ChaCha20.xor` `pad` (64 B) | `FrameCrypto.wipe` (new, was a plain loop) |
| Swift | `ChaCha20.fill` locals `x0`…`x15` | none: registers and spill slots, L71-1 |
| Swift | `FrameSession.seal` `tag`, `tagMatches` `expected`, `MacKey.tag` and `verify` `full` | `FrameCrypto.wipe` (new) |
| Swift | `PackSession` seed, derived block, send and receive keys | `FrameCrypto.wipe` (new, was a plain loop) |
| Swift | CryptoKit `HMAC` and `SymmetricKey` state | CryptoKit zeroes its own key storage |

Not secret, so not wiped: `Seal` and `seal` ciphertext and body buffers (they hold plaintext only until the XOR runs), the `Open` copy of the received body, nonces, salt and info. Every wipe is best effort on a managed runtime (L71-1).
