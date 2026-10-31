# Feature assessment — loop 92

loop: 92
feature: avr-chacha20-runtime-check
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-10-31
**Implement pass**: batch 1, `_docs/03_implementation/batch_01_loop92_report.md` (no separate implementation report or completeness report: loops 89 to 91 wrote none either)
**Verdict**: COMPLETE — 10 covered / 1 out-of-scope / 0 gap-clear / 0 gap-unclear

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | A maintainer runs the arm stage with `simavr` in the image | covered | AC-1 to AC-4; check image `cpp/embedded/avr/chacha20_check.cpp`, expected `chacha20_expected.txt`; code path `cpp/src/core/crypto.cpp` `chacha20_xor`; real run PASS | intake |
| S2 | The stage runs twice on the same tree | covered | AC-1 to AC-4; five real runs gave the same six report lines (first run, row run, clean reruns); no clock or random input in `chacha20_check.cpp` | intake |
| S3 | The image never ends | covered | AC-5; proof run with the image looping before its sleep: "did not end within 30 s", exit 1; `avr_run_chacha20` in `arm.sh` | intake |
| S4 | `simavr` is missing from the image | covered | AC-5; proof run with `/usr/bin/simavr` removed: "simavr is missing from the image", exit 1; `avr_run_chacha20` | intake |
| S5 | `simavr` exits 0 and prints nothing | covered | AC-5; proof run with a `simavr` that exits 0 silently: row FAIL, the six expected lines show as missing in the diff, exit 1 | intake |
| S6 | Lengths 0 to 129 and the counter at `0xffffffff` and `0xfffffffe` | covered | AC-3, AC-4; `STREAM 9/9`, `RESTORED 9/9`, `EDGE 5/5`; `chacha20_xor` in `crypto.cpp` | intake |
| S7 | The existing Uno example builds and the budget checks run | covered | AC-6; Uno example 15,402 B and 196 B unchanged; `lib.test.sh`, `run-parts.test.sh`, `loop-tests.test.sh`, `rust/embedded/checks.test.sh` pass; `target_avr_uno` | intake |
| S8 | The run shows a wrong byte from `chacha20_xor` on AVR | covered | AC-5, AC-6; injected defect run: `RFC 112/114`, `STREAM 2/9`, `EDGE 3/5`, bad cases named, exit 1; no file under `cpp/src` changed | intake |
| D1 | simavr 1.6 console register prints nothing; its header does not compile as C++ | covered | spec `## Constraints`; UART report in `chacha20_check.cpp`; real run | batch_01 discoveries |
| D2 | The spec named a separate parser unit test; the check is one `diff` | covered | spec Unit Tests row changed to say the four real-path failure runs (now five with the silent run) cover AC-5 | batch_01 discoveries |
| D3 | The wrap near 64 KiB cannot be reached on a 2 KB part | out-of-scope | spec `### Excluded` line: "A buffer near 64 KiB (the part has 2 KB of RAM; see Flagged concerns)"; the Medium flagged concern stays `open` | batch_01 discoveries |

### Gaps that need a decision (gap-unclear)

none

### Gaps that are clear (gap-clear)

none

### Not walked

- A newer simavr that changes its UART line format: the row would fail loudly on the diff, so no separate case.

### Harness gaps

- No implementation report or completeness report exists for loops 89 to 92 (practice since loop 89); the batch report holds the evidence.
