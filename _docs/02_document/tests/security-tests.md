# Security Tests

The library has no authentication. These checks are about secrets and hostile buffers.

### NFT-SEC-01: The published archive has no registry token

**Summary**: The files uploaded to the six registries do not contain a registry token.
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
