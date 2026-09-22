# Resource Limit Tests

### NFT-RES-LIM-01: The speed loop needs no GPU

**Summary**: The 100000-iteration position loop runs on one core and does not require a GPU.
**Traces to**: AC-10, R-01

**Preconditions**:
- No GPU is attached to the test process

**Monitoring**:
- Elapsed time of NFT-PERF-01
- Whether the process requests a GPU

**Duration**: one loop of 100000 iterations
**Pass criteria**: elapsed time ≤ 1 second, and GPU request count is 0.
