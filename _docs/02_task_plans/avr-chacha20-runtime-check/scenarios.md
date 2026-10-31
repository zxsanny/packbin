# Scenarios — avr-chacha20-runtime-check

Source of rows: `intake` (new-task Step 4.7, loop 92). Status: confirmed / out-of-scope / deferred. Fit analysis found no collision with today's behavior (no problem card): the change sits in the arm stage function `target_avr_uno`, the embedded image recipe, new AVR harness files and two stale sentences. Callers and tests of the stage (`run.sh` table, `lib.test.sh`, `run-parts.test.sh`) stub or list the function by id and do not read its body.

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | A maintainer runs the arm stage with `simavr` in the image | confirmed | the image runs, reports `size_t` 2 and `int` 2, every check passes, the `cpp-avr-uno` row passes | AC-1, AC-2, AC-3, AC-4 | intake |
| S2 | The stage runs twice on the same tree | confirmed | the same output both times (no clock, no random input) | AC-1 to AC-4 | intake |
| S3 | The image never ends (a loop that does not stop) | confirmed | the run is cut at 30 s of host time and the row fails | AC-5 | intake |
| S4 | `simavr` is missing from the image | confirmed | the stage fails with the missing tool named; it is not skipped | AC-5 | intake |
| S5 | `simavr` exits 0 and prints nothing (the silent console register of 1.6) | confirmed | the row fails: no output is not a pass | AC-5 | intake |
| S6 | Lengths 0 to 129 and the counter at `0xffffffff` and `0xfffffffe` | confirmed | each case matches the stream built from `chacha20_block`, or is refused with the data unchanged | AC-3, AC-4 | intake |
| S7 | The existing Uno example builds and the budget checks run | confirmed | unchanged figures and budgets; `lib.test.sh` and `run-parts.test.sh` pass unchanged | AC-6 | intake |
| S8 | The run shows a wrong byte from `chacha20_xor` on AVR | confirmed | the row fails with the case named; the loop stops and reports the defect, no expectation is relaxed | AC-5, AC-6 | intake |
| D1 | simavr 1.6 console register prints nothing and its header does not compile as C++ | confirmed | the report goes over the UART with no library header | Constraints | assess-round-1 |
| D2 | The report check needs no separate parser test | confirmed | one `diff` against the expected file, covered by the five real-path failure runs | AC-5 | assess-round-1 |
| D3 | A buffer near 64 KiB (the wrap the code comment names) | out-of-scope | cannot be reached on a 2 KB part; the Medium concern stays open | — | assess-round-1 |

## Fit decisions

| card | collision | chosen option | constraint recorded |
|------|-----------|---------------|---------------------|
| — | none found | — | — |

## Not walked

- A buffer near 64 KiB (the wrap the code comment names): an ATmega328P has 2 KB of RAM, so the run cannot reach it (flagged concern, Medium).
- Other crypto functions and the cycle count on AVR (out of scope).
