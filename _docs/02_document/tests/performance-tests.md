# Performance Tests

### NFT-PERF-01: Position round trips

**Summary**: 100000 pack-then-unpack round trips of the 13-byte fixture stay inside one second on one core.
**Traces to**: AC-10
**Metric**: elapsed time

**Preconditions**:
- One core
- One warm-up call of the same fixture before the timed loop

**Steps**:

| Step | Consumer Action | Measurement |
|------|----------------|-------------|
| 1 | pack and unpack the position fixture 100000 times | elapsed time |

**Pass criteria**: elapsed time ≤ 1 second, in C# and in TypeScript
**Duration**: one loop of 100000 iterations
