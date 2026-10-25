# Acceptance criteria — loop 72, frame hardening in C#, Java and Swift

Inherited and unchanged: the frame-mode criteria of loop 71 (`../frame-mode-csharp-java-swift/acceptance_criteria.md`), which this loop must keep green. The criteria below are new.

## AC-1 No key or counter hook in a shipped build (review item 5)

- **AC-1.1 Swift**: `FrameSession.derivedKeys(for:previous:)` and `MacKey.storedKey` are not `public`. A consumer target that imports `Packbin` without `@testable` and calls either one fails to compile. The Swift frame tests still read both.
- **AC-1.2 C#**: the `Packbin.dll` built by `dotnet pack -c Release` exposes no member outside the assembly that returns a stored key array, a derived key array or the MAC count. That covers `FrameSession.KeyArrays`, `CurrentKeys` and `MacComputations` and `MacKey.KeyArray`, reached either directly or through an `InternalsVisibleTo` grant that a consumer could satisfy by naming its assembly `Packbin.Tests`. The C# frame tests still read them, and the `ac10` Release test build still compiles.
- **AC-1.3 Java**: no class outside the shipped jar can call `encKeyForTest`, `macKeyForTest`, `macComputationsForTest` or `MacKey.keyForTest`. A class compiled as `package packbin;` in a second jar on the classpath fails to call them, either because the package is sealed or because the hooks are not in the jar. The Java frame tests still read the keys.

## AC-2 Pad and HMAC temporaries are wiped (review item 6)

- **AC-2.1**: C# and Java `SessionPad` block functions overwrite the 16-word `state` and `work` arrays with zero before they return. C# uses `CryptographicOperations.ZeroMemory` on net10.0 and the package's existing zero helper on netstandard2.0.
- **AC-2.2**: Java `FrameSession` and `MacKey` overwrite each 32-byte `full` HMAC output with zero once the tag is copied or compared.
- **AC-2.3**: the Swift ChaCha20 pad is zeroed through `FrameCrypto.wipe` or an equal helper that the optimizer does not remove (`@inline(never) @_optimize(none)`, as the tag compare already is), not through a plain loop.
- **AC-2.4**: a code-read list in the task record names every temporary that held key-derived words, pad bytes or a full HMAC in the three packages' frame and pad code, each with its wipe.

## AC-3 No static mutable MAC counter in Java (review item 7)

- **AC-3.1**: `java/src/main/java/packbin` frame code (`FrameCrypto`, `FrameSession`, `MacKey`) holds no `static` field that changes after class load.
- **AC-3.2**: each `FrameSession` (and each `MacKey`) counts its own MAC computations. The existing test that "a replay refusal starts no MAC" still fails when a copy of `open` computes the tag before the window check: run it once against such a broken copy and record the result.

## AC-4 C# `Load` with no direction (review item 8)

- **AC-4.1**: `FrameSession.Load(key32, epoch, new FrameConfig(tagLength 4|8|16, FrameDirections.None))` returns a session (not null).
- **AC-4.2**: on that session, `Seal` and `Open` in each of the directions 1, 2 and 3 return `BadValue` and write nothing, matching Java (`load(key, epoch, tag)` with no direction) and Rust.
- **AC-4.3**: the other `Load` refusals (key not 32 bytes, epoch above 0xFFFFFF, tag length not 4, 8 or 16, a direction bit outside `All`) still return null.

## AC-5 C# `Seal` with overlapping buffers (review item 10)

- **AC-5.1**: `Seal` gives the same `output` bytes as with separate buffers in three cases: `plain` is `output[clear.Length ..]`, which is the in-place layout; `plain` starts at `output[0]`; and `clear` is `output[0 .. clear.Length]` with `plain` following it. In each case, check against frame vector row E1 of `fixtures/frame/vectors.txt`, or against any row with clear and plain bytes.
- **AC-5.2**: `Open` keeps its loop 71 behaviour (body copied once). An `Open` whose `plain` output overlaps `body` returns the plaintext of the vector row.

## AC-6 Bytes unchanged

- **AC-6.1**: all 157 rows of `fixtures/frame/vectors.txt` and all 27 rows of `fixtures/crypto/vectors.txt` pass in C#, Java and Swift, with output byte for byte equal to Rust.
- **AC-6.2**: the stream session vectors and the cross-language session match (`scripts/loop-tests.sh` stages `csharp`, `java`, `swift`, `ring`) pass unchanged.

## AC-7 Speed

- **AC-7.1**: every existing load-aware timing check of the three packages passes, using the helpers named in `AGENT_GOTCHAS.md` and no new fixed bound.

## Out of scope

Rust (`hkdf.rs` temporaries, `frame` with `std`); a replay window per key slot (F69-2); frame mode in Python, TypeScript, Go and C++; a cross-language frame ring; guaranteed wipe or constant time in a managed runtime (L71-1 stays the documented position).
