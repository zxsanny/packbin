# Resilience Tests

### NFT-RES-01: A short packet does not poison the next call

**Summary**: After a short buffer returns an error, a later pack of the position fixture still matches the golden hex.
**Traces to**: AC-8, AC-1

**Preconditions**:
- The same process will call unpack, then pack

**Fault injection**:
- The first buffer ends inside a field

**Steps**:

| Step | Action | Expected Behavior |
|------|--------|------------------|
| 1 | unpack the short buffer | error, value count 0 |
| 2 | pack the position values | hex `4001000065cd1d00a3e1110100` |

**Pass criteria**: step 2 mismatched bytes: 0. The library did not keep the failed packet.
