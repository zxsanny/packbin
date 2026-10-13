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

**Summary**: Unpack refuses a `repeat` or `times` at round `maxRounds + 1` (default 65 535) and a slot total above `maxSlots` (default 1 048 576 since loop 22, AZ-2415; 4 194 304 before) before it walks the rest of the packet, so the memory of a refused 1 MiB packet is bounded by the limits and not by the packet length (loop 15, AZ-2216 to AZ-2219).
**Traces to**: AZ-2216 AC-8, AZ-2217 AC-8, AZ-2218 AC-8, AZ-2219 AC-10

**Preconditions**:
- C#, TypeScript, Java and Rust with default limits; a 37-name `repeat` (Rust: eight bool groups under `flags`)

**Monitoring**:
- C#: `GC.GetAllocatedBytesForCurrentThread()` before and after
- the error returned and whether the handler was called

**Duration**: one unpack of 1 048 576 bytes
**Pass criteria**: the call returns a short-read error with `left` 983 041 (refused at round 65 536; loop 15 to 21 figures at `maxSlots` 4 194 304), the handler is not called, and the C# allocation stays below 128 MiB (measured 38.0 MiB; 608 MiB with the limits off). The same packets with 65 535 rounds are accepted. Scenario: FT-X-23.

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

### NFT-RES-LIM-04: The worst-case packet under the default `maxSlots` peaks under 400 MB

**Summary**: With the default `maxSlots` of 1 048 576 (loop 22, AZ-2415, finding F10) the unpack of the 4.3 MB packet of 65 535 items, each a round of 64 one-byte members (4 194 240 slots), is refused at item 16 385, and the peak resident set of a fresh process stays under 400 MB in every package that has a slot budget. The slot count is a quarter of the old default; the runtime floor does not shrink, so the peak is 19 to 33 percent of the old one.
**Traces to**: AZ-2415 AC-2

**Preconditions**:
- TypeScript (Node 22), Java (`-Xmx4g`), C# (typed unpack), Python and Rust (stand-in: a 64-wide `times` of 65 535 rounds, since a Rust list element cannot hold a `times`) with default limits; method in `_docs/03_implementation/reference_loop22.md` section 2

**Monitoring**:
- peak resident set of the process (`maxRSS`, `/usr/bin/time -l`, `getrusage`), idle figure before the call, the error and its `left`

**Duration**: one unpack of the 4 259 778-byte packet, one run per package (TypeScript three runs)
**Pass criteria**: refused with the slots text naming 1 048 576 and no row kept; peak TypeScript 353 MB (1 070 MB before), Java 317 MB (960), C# 235 MB (733), Python 162 MB (550), Rust 120 MB (628). With `maxSlots` raised to 4 194 304 the same packet unpacks as before (standing tests in TypeScript, Java and C# since loop 22, and in Python and Rust since loop 23, AZ-2435, FT-X-80). C++ has no slot budget (fixed `Array`). Scenario: FT-X-71. The TypeScript test asserts `peakMB < 535` in a child process (half of the old 1 070 MB; measured 353 to 355 MB), so the 400 MB ceiling is the measured figure, not the assertion.
