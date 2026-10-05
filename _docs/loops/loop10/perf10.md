# Performance check — loop 10

**Date**: 2026-10-05

| Criterion | Limit | Measured | Result |
|-----------|-------|----------|--------|
| AC-10 (project): 100 000 pack and unpack round trips on one core | ≤ 1 s | 13–24 ms (`nfr elapsed_ms`, Apple clang 21 and gcc:16 container) | PASS |
| Feature AC-5: core plus a 14-field table, Cortex-M4F `-Os` | ≤ 8192 B flash | 7728 B | PASS |
| Feature AC-5: deepest pack or unpack | ≤ 512 B stack | 488 B (raw 552 less 64 B meter) | PASS (24 B margin) |
| Feature AC-5: core `.data` + `.bss` | 0 B | 0 B | PASS |
| Hostile cases, 17 packets | each ≤ 1 s | whole runner under 1 s | PASS |

Since batch 4 (7600 B flash, 464 B stack) the core grew 128 B of flash and 24 B of stack: per-container flag-byte scope, the zero-progress rule, the count clamp and the placement checks.
