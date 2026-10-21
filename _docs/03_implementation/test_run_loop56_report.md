# Test run — loop 56 (step 11)

Date: 2026-10-21. Command: `scripts/loop-tests.sh` (stages planned by the stamps: the C++ package, the Go, Rust and Swift loaders, the scaffold, the ARM stage, rust-embedded and the ring).

RESULT: 8 passed, 6 skipped as unchanged, 0 failed, 540 s. Verdict: PASS.

| Stage | Result | Seconds |
|-------|--------|---------|
| cpp | PASS | 47 |
| rust | PASS | 68 |
| go | PASS | 180 |
| swift | PASS | 395 |
| scaffold | PASS | 396 |
| cpp-embedded-arm | PASS | 11 |
| rust-embedded | PASS | 2 |
| ring | PASS | 62 |
| typescript, csharp, python, java, ac10, publish-gate | SKIP (unchanged since daa302d) | — |

Specified / executed / not run: 14 stages specified, 8 executed, 6 skipped as unchanged (no file they cover changed); none not-run.

Cortex-M4F (arm stage log): flash 8,080 of 8,192 B (margin 112 B; 8,120 B before), deepest pack/unpack stack 504 of 512 B (raw 568 B less 64 B meter), `CHAIN_FAILURES 0`, `FLAG_CHAIN_FAILURES 0`, `ROUND_CHAIN_FAILURES 0`, vectors 287 of 287 on M3; avr-uno 15,608 of 32,256 B.

Host: load 4 to 17 during the run; no stage needed a re-run alone. The run found no failing test, so no fix was made.
