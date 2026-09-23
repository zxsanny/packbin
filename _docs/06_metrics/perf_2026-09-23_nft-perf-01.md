# Performance run — 2026-09-23

**Scenario**: NFT-PERF-01
**Threshold**: 100000 pack-then-unpack round trips ≤ 1 second
**Verdict**: Pass

| Language | Elapsed | Error rate | Throughput (trips/s) | Threshold |
|----------|---------|------------|----------------------|-----------|
| C# | 229 ms | 0 | 436681 | Pass |
| TypeScript | 390.1 ms | 0 | 256344 | Pass |
| Python | 547.8 ms | 0 | 182548 | Pass |
| Rust | 413.3 ms | 0 | 241955 | Pass |
| C++ | 68.6 ms | 0 | 1457726 | Pass |
| Java | 88.7 ms | 0 | 1127396 | Pass |

One sample per language, so there is no p95/p99 spread. The C#, TypeScript, Rust, C++, and Java numbers are the timed loops inside the language suites (`docker compose -f docker-compose.test.yml run`). Those loops do not make a separate warm-up call; the first iteration is inside the window. Python was measured again in the same `python:3.14` image with one warm-up call, then 100000 iterations: 547.8 ms. Each loop is single-threaded.
