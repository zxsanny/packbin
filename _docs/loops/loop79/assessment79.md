# Feature assessment — loop 79

loop: 79
feature: ring-and-test-build-fixes (AZ-3356, AZ-3357)
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-10-28
**Implement pass**: commit 692edcc; batch report `_docs/03_implementation/batch_01_loop79_report.md`
**Verdict**: CLARIFY — 8 covered / 1 out-of-scope / 0 gap-clear / 1 gap-unclear; answered the same turn (below), final COMPLETE — 13 covered / 2 out-of-scope / 0 / 0

The assessment is by the parent from the code at 692edcc and the runs recorded in the batch report (owner preference: one total review, no independent agent).

### Coverage matrix

| id | scenario | status | evidence |
|----|----------|--------|----------|
| S1 | a ring row with a number above its range | covered | AC-4; `number()` and `RANGES` in `ring_frame.py`; self-test cases `row-dir-256`, `row-out-len-65536` |
| S2 | a driver line with a number above its range or a sign | covered | AC-1; one number reader per driver (digit by digit against the top); driver script 64 out-of-range runs PASS |
| S3 | the top of each range | covered | AC-2, AC-5; rows `R.seal.dir255`, `R.seal.tag255`, `R.seal.kind255`, `R.seal.epochffffffff`, `R.mac.n255`, `E1.out65535`; 24 driver runs; ring 43 rows x 8, 0 mismatched |
| S4 | the existing rows after the change | covered | AC-5; `64 pairs, mismatched: 0`; the 44 old driver checks pass |
| S5 | more than 5 mismatches | covered | AC-7; `show()`; cases `refusals-7`, `pair-6`, `refusals-5` |
| S6 | an old lenient driver | covered | AC-3; cb6759b drivers fail 54 of 132 cases (batch report) |
| S7 | a test helper's cfg broader than its callers' | covered | AC-8, AC-9; `rust_test_build` in `run-suite.sh`; R4/R5 of `run-suite.test.sh`; 0 warnings in 9 sets |
| S8 | a std test file without its gate | covered | AC-10; `bound_names_tests.rs` without the gate fails `cargo check --no-default-features --tests` (exit 101) and the `none` set of the suite |
| S9 | multi-part MAC | out-of-scope | `scenarios.md` S9 |
| D2 | `take` warned in the default set | covered | `#[cfg(feature = "frame")]` in `counters.rs`; default set 0 warnings |
| D3 | `--no-run` costs +64 s cold on the CI wall job | covered | owner 2026-10-28: keep `cargo check --tests` (193 s against HEAD 185 s cold on 4 CPUs); AC-8 and AC-10 shown with it |
| D4 | Java and C++ read `out_len` after the load; C++ MAC buffer 32 B | covered | both read every number first; C++ buffer 255 |
| D5 | a `seal`/`mac` row the reference refuses crashes the loader unnamed | out-of-scope | before this loop; leftover for a later loop |
| U2 | the Java package's epoch is an `int`: an in-range epoch above 2,147,483,647 cannot reach it | covered | owner 2026-10-28: keep, the Java driver prints `BadValue` itself (as U1 for Rust directions 0 and 4); `fixtures/frame/README.md`; row `R.seal.epochffffffff` matches in Java |

### Question for the owner (U2, D3) — answered "Accept all recommended", 2026-10-28

U2: keep the Java driver's own `BadValue` above `Integer.MAX_VALUE` (alternative was lowering the epoch top to 2,147,483,647 everywhere). D3: keep `cargo check --tests` (alternative was `cargo test --no-run` at +64 s cold).

## Not walked

- Gotchas from the implement pass (`run_lang` reuses C# and C++ builds in a kept work dir; a `git archive` copy needs the root named `packbin` and its own Java, Go and Swift build paths): recorded for `AGENT_GOTCHAS.md` at loop close.
