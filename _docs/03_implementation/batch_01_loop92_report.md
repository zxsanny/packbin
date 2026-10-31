# Batch Report

**Batch**: 1 (loop 92)
**Tasks**: AZ-3452_avr_chacha20_runtime_check
**Date**: 2026-10-31

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-3452_avr_chacha20_runtime_check | Done | 6 files (`Dockerfile`, `arm.sh`, `run.sh`, `README.md`, new `avr/chacha20_check.cpp`, new `avr/chacha20_expected.txt`) | real `cpp-avr-uno` row PASS; 4 of 4 failure runs FAIL as required | None |

## Evidence per AC

Runs are the `cpp-avr-uno` target in the rebuilt `packbin-embedded:local` image (`simavr` 1.6, Ubuntu 24.04), repo mounted at `/src`.

- AC-1: report line `SIZES size_t=2 int=2` read from the emulated ATmega328P.
- AC-2: `RFC 114/114`. The RFC 8439 2.4.2 ciphertext was also recomputed in Python independently of the C++ code and equals the repo's vector.
- AC-3: `STREAM 9/9`, `RESTORED 9/9` (lengths 0, 1, 63, 64, 65, 114, 127, 128, 129).
- AC-4: `EDGE 5/5`.
- AC-5, four runs through the real path, each reverted at once (`git status cpp` shows only the intended files after):
  - one expected byte changed (`0x6e` to `0x6f`): row FAIL, `RFC 113/114`, `BAD RFC 113`, "report differs from avr/chacha20_expected.txt", exit 1;
  - one changed line in `chacha20_xor` (`data[i] ^= block[i] ^ (i == 3 ? 1 : 0)`): row FAIL, `RFC 112/114`, `STREAM 2/9`, `EDGE 3/5`, the bad lengths and edge cases named, exit 1;
  - image that never ends: row FAIL, "did not end within 30 s", exit 1;
  - `simavr` removed from the image: row FAIL, "simavr is missing from the image", exit 1.
  - A silent run (no output) is not run separately: it produces an empty file, which the same `diff` against the expected file rejects.
- AC-6: 0 compile warnings (`compile warnings: 0`, includes the harness), 0 link warnings; check image 3,798 B of flash and 316 B of static RAM against 32,256 B and 2,048 B; Uno example unchanged (15,402 B, 196 B); `git diff --stat cpp/src cpp/include` empty; `lib.test.sh`, `run-parts.test.sh`, `scripts/loop-tests.test.sh`, `rust/embedded/checks.test.sh` pass unchanged.
- AC-7: both stale sentences replaced (`README.md`, the comment above `avr_arch` in `arm.sh`); the `run.sh` header comment also names the run.
- NFR performance: the stage time added to the row was not read separately; the emulator run in the probe ended in under 1 s of host time and the gate's bound is 30 s.

CI-parity: PASS — `cpp/embedded/lib.test.sh`, `cpp/embedded/run-parts.test.sh`, `scripts/loop-tests.test.sh`, `rust/embedded/checks.test.sh`, and the real `cpp-avr-uno` target in the rebuilt image. `shellcheck` is not installed on this host (`bash -n` only). The full arm stage (QEMU rows) was not run locally; CI runs it on push.

## Code Review Verdict: PASS

Low effort, one pass over the diff: no findings.

## Test Suite

- The new check: 1 image run, 5 report groups (sizes, 114 bytes, 9 streams, 9 restores, 5 edge cases), 0 failed.
- Self-tests listed above: all passed.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | simavr 1.6 prints nothing for its console register; its `avr_mcu_section.h` does not compile as C++ | Constraints | UART report, no library header (done) | clear |
| 2 | The spec's Unit Tests row named a separate report-parser test; the report check is one `diff`, and a new test script needs wiring in `test.yml`, `publish-jobs-layout.py`, `ring-wiring-check.py` and `scripts/loop-tests.sh` | AC-5 | the four real-path failure runs cover it; the spec row was changed to say so | clear |
| 3 | The wrap near 64 KiB cannot be reached on a 2 KB part | Flagged concerns | stays open, Medium | clear |

## Commit

`[AZ-3452] Run chacha20_xor on a 16-bit AVR under simavr`. Body: one line + `Loop: 92`.

## Next Batch: All tasks complete
