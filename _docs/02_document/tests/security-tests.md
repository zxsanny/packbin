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
