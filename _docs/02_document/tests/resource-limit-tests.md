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

### NFT-RES-LIM-02: A refused packet costs memory bounded by the round limits

**Summary**: Unpack refuses a `repeat` or `times` at round `maxRounds + 1` (default 65 535) and a slot total above `maxSlots` (default 4 194 304) before it walks the rest of the packet, so the memory of a refused 1 MiB packet is bounded by the limits and not by the packet length (loop 15, AZ-2216 to AZ-2219).
**Traces to**: AZ-2216 AC-8, AZ-2217 AC-8, AZ-2218 AC-8, AZ-2219 AC-10

**Preconditions**:
- C#, TypeScript, Java and Rust with default limits; a 37-name `repeat` (Rust: eight bool groups under `flags`)

**Monitoring**:
- C#: `GC.GetAllocatedBytesForCurrentThread()` before and after
- the error returned and whether the handler was called

**Duration**: one unpack of 1 048 576 bytes
**Pass criteria**: the call returns a short-read error with `left` 983 041 (refused at round 65 536), the handler is not called, and the C# allocation stays below 128 MiB (measured 38.0 MiB; 608 MiB with the limits off). The same packets with 65 535 rounds are accepted. Scenario: FT-X-23.

### NFT-RES-LIM-03: Pack of a hostile count allocates nothing proportional to the count

**Summary**: Pack refuses a `times` count above `maxRounds` before it writes or allocates a round, so a count of 4 000 000 000 returns at once with an error and no bytes (loop 19, AZ-2329; security finding F21).
**Traces to**: AZ-2329 AC-1

**Preconditions**:
- C#, TypeScript, Python, Java and Rust with default limits; C++ is bounded by its fixed `Array` capacity of at most 65 535 items

**Monitoring**:
- elapsed time and the process's peak memory for the call
- the error returned and the length of any output buffer

**Duration**: one pack with count 65 536, 70 000, 2 000 000 000 and 4 000 000 000 and a lone scalar
**Pass criteria**: each call returns an error naming the first body member within the 1 s guard, with no bytes; memory stays flat (the spec asks for it; the tests assert the error and the return, not a memory figure, so the flat-memory part is carried by the early check and not measured). A count at the limit still packs. Scenario: FT-X-24. Not covered: a `repeat` with more than `maxRounds` list entries still packs (assessment U1, open owner question).
