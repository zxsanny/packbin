# Security Tests

The library has no authentication. These checks are about secrets and hostile buffers.

### NFT-SEC-01: The published archive has no registry token

**Summary**: The files uploaded to the six registries do not contain a registry token. Since loop 24 the Go package has no upload: its release is the tag `go/vX.Y.Z`, pushed with the job's `GITHUB_TOKEN` through the `GIT_ASKPASS` path of the existing publish scripts, never forced; `publish-go.test.sh` unsets every registry credential for its runs (the remote is a local path, so the Go tag needs none).
**Traces to**: R-19

**Steps**:

| Step | Consumer Action | Expected Response |
|------|----------------|------------------|
| 1 | scan the published archive for a GitHub token, an npm token, and a NuGet API key | no match |

**Pass criteria**: match count 0.

### NFT-SEC-02: A short buffer does not crash the process

**Summary**: Hostile length returns the short-packet error and the process is still alive.
**Traces to**: AC-8

**Steps**:

| Step | Consumer Action | Expected Response |
|------|----------------|------------------|
| 1 | unpack a one-byte buffer against the position list | an error |
| 2 | pack the position values | the golden hex |

**Pass criteria**: step 1 value count 0. Step 2 mismatched bytes 0. The process exit from the error itself is not a crash.

### NFT-SEC-03: A hostile packet cannot throw out of a typed C# unpack

**Summary**: A seven-byte packet whose element is `ffffffff` no longer throws `OverflowException` out of `Unpack`: a member too narrow for its field cannot be built, and a wide enough member returns the value (loop 18, AZ-2305).
**Traces to**: AZ-2305 AC-3

**Steps**:

| Step | Consumer Action | Expected Response |
|------|----------------|------------------|
| 1 | build a typed row with a `List<int>` member for a `u32` list field | `ArgumentException` naming the member and the element type |
| 2 | build the same row with a `List<long>` member and unpack `01 01 00 ff ff ff ff` | no exception; the member holds `[4294967295]` |

**Pass criteria**: step 1 raises at build, so no packet can reach the conversion; step 2 returns a value with no exception. Not covered here: a typed unpack of a set `times` or `repeat` bit still throws `InvalidCastException` in C# (typed rows hold one round; carried finding F17, batch 3 discovery 30).

### NFT-SEC-04: Hostile input cannot panic or hang the Go package (the session seed wipe retired in loop 74)

> Steps 3 (the session part) and 4 are **retired in loop 74 (ADR 009, AZ-3287)**: the Go stream session and its tests are removed. Steps 1 and 2 and the non-session part of step 3 stand. The Go crypto module that frame mode will use (`crypto.go`) is checked by `crypto_vectors_test.go` on the 27 rows of `fixtures/crypto/vectors.txt`, with its refusals.

**Summary**: No input makes Go `Pack`, `Unpack`, `UnpackMap`, `NewScheme` or (until loop 74) a session call panic (GO-4, GO-15); every bad buffer is an `*Error` value, an unpack of a hostile case returns within 1 second, and (retired in loop 74, ADR 009) `LoadSession` kept a copy of the seed that it zeroed once the session opened (loop 24, AZ-2440, AZ-2445, AZ-2446).
**Traces to**: GO-4, GO-6, GO-15, AZ-2445 AC-3, AZ-2446 AC-1

**Steps**:

| Step | Consumer Action | Expected Response |
|------|----------------|------------------|
| 1 | replay the 65 cases of `fixtures/hostile/cases.txt` in Go (`TestHostileUnpackVectors`, `TestHostileLimitVectors`, `TestHostileConstructVectors`, `TestHostilePackVectors`) | an allowed outcome each; unpack within the 1 s guard; no panic |
| 2 | build about 78 000 random schemes and read random packets (`TestRandomSchemesNeverPanic`, `TestRoundsNeverPanic`, `TestCollectionsNeverPanic`), and run `FuzzUnpack` for 60 s | 0 panics, 0 failures (1.19 M execs in the compose run after the review fixes) |
| 3 | give a nil row, a nil map, a wrong Go type or a nil scheme (`TestAC5InvalidGoValues`, `TestPackNilSchemeIsRefused`, `TestNilSchemeAccessorsDoNotPanic`), and (retired in loop 74) a nil session or a zero value (`TestSessionCallsOnNilAndZeroValuesAreErrorsNotPanics`) | an error value naming the field; nil bytes |
| 4 (retired in loop 74, ADR 009) | load a seed, open the session, read the caller's slice and the internal copy (`TestSessionLoadKeepsACopyAndThePacketUseWipesIt`) | the caller's slice is not wiped (as TypeScript); the internal copy and the derived key block are zeroed |

**Pass criteria**: panics 0; partial output 0 bytes. The "not covered" item of loop 24 (`StartWith(nonce)` let a caller reuse a nonce, review24 Low 4) is retired with the stream session (loop 74). The security findings of the Go package are in `_docs/05_security/` (another step).

### NFT-SEC-05: Hostile input cannot trap or hang the Swift package

**Summary**: Swift traps (it does not throw) on arithmetic overflow, an index out of range and a force unwrap, and a trap ends the process. No input makes Swift `pack`, `unpack`, `unpackMap`, `Scheme` construction or (until loop 74) a session call trap (SW-4, SW-15): every bad buffer throws a `PackbinError`, an unpack of a hostile case returns within 1 second (release and debug runs), and the ChaCha20 stream refuses data past the last block (the stream session's position check was retired in loop 74, ADR 009) (loop 26, AZ-2513, AZ-2517, AZ-2518, AZ-2519).
**Traces to**: SW-4, SW-5, SW-6, SW-15, AZ-2519 AC-1, AZ-2518 AC-3

**Steps**:

| Step | Consumer Action | Expected Response |
|------|----------------|------------------|
| 1 | replay the 65 cases of `fixtures/hostile/cases.txt` in Swift (`HostileTests`: `unpackCase_givesAnAllowedErrorWithItsRuleAndNoRow`, `limitCase_isRefusedWhenTheRoundPastTheLowLimitWouldStart`, `constructCase_isRefusedWithItsRule`, `packCase_givesItsBytesOrIsRefusedWithItsRule`) | an allowed outcome each; no trap |
| 2 | read random buffers and rows (`NoTrapTests`, `RoundNoTrapTests`, `CollectionHostileTests.unpack_randomBytesForCollectionSchemes_throwOnlyPackbinErrors`) and run `FuzzTests` for 60 s from `fixtures/hostile/fuzz/corpus.txt` | 0 traps; a row or a `PackbinError` within the bound |
| 3 | give an out-of-range getter value, a wrong Swift type, a missing key or `NSNull` (`InvalidValueTests.pack_invalidRow_throwsNamingTheFieldAndReturnsNoBytes`, `NoValueTests.pack_mapMemberGivenNSNull_isRefusedAsNoNumber`) | a thrown error naming the field; 0 bytes |
| 4 | hostile session input (retired in loop 74, ADR 009: `SessionHostileTests`, short, odd, large and random payloads, a seed or value of another length, unpack before join); still run: `ChaCha20Tests.xor_dataThatNeedsABlockAfterTheLast_isRefusedAndUnchanged` and the frame refusals of `FrameRefusalTests` | a thrown error, no trap; the caller's seed and payload are not changed |

**Pass criteria**: traps 0; partial output 0 bytes; the steps ran on the Mac and in the `swift:6.3.3` container at step 11. The "not covered" item of loop 26 (`PackSession.start(_ nonce:)` was public, so a caller could reuse a value; open decision O3, review26 #7) is retired with the stream session (loop 74). The security findings of the Swift package are in `_docs/05_security/` (another step).
