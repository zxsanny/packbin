# Batch Report

**Batch**: 1 and 2 (loop 78)
**Tasks**: AZ-3354_frame_ring_refusal_rows, AZ-3355_frame_ring_driver_hardening
**Date**: 2026-10-28

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-3354_frame_ring_refusal_rows | Done (a53fa8f) | 11 source files | self-test cases pass; real ring 8 of 8, `refusals <lang>: 38 rows, 0 mismatched` x 8, 64 pairs | None |
| AZ-3355_frame_ring_driver_hardening | Done | 12 source files, 1 new script | self-test 23 cases pass; driver script 44 of 44; mutation check: lenient TypeScript and Swift drivers fail it (8 FAIL) | None |

## Code Review Verdict: not run per batch (owner preference: one total review and one step-11 run per loop)

## Test Suite

- ring-frame.test.sh: all cases pass (honest, 8 liars and crashes, 4 corrupted rows, 2 new name changes, writer-prints-word, unloaded-direction-accepted, fit-refused, dir0-aborts, no-open/verify rows)
- ring-frame-drivers.test.sh: 44 passed, 0 failed
- ring-frame.sh: `64 pairs, mismatched: 0`; the full `scripts/loop-tests.sh --all` is step 11
- CI-parity: PASS locally: `g++ -std=c++17 -O2 -Wall -Wextra -Werror -fsyntax-only` in `gcc:16` on `handoff.cpp`; `gofmt -l` and `go vet` in `golang:1.27` on the Go driver; `cargo build` on the Rust driver; Swift driver built by `ring-swift.sh`; shellcheck on the two ring scripts; `publish-jobs.test.sh`, `loop-tests.test.sh`, `ring-lib.test.sh`, `ring-wiring*.test.sh` pass

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | Rust, Java and Swift have no direction value for 0 or 4. Java passes `null` and Swift calls `FrameDirection(number:)`, both answered by the package; Rust has no value to pass, so its driver prints `BadValue` itself (as `rust/tests/frame_vectors_tests.rs` does) | AZ-3354 AC-3 | kept, documented in `fixtures/frame/README.md` and the spec; owner may prefer to drop dir 0/4 for Rust | unclear (owner to confirm the Rust case) |
| 2 | `scripts/loop-tests.sh` never ran `ring-frame.sh` or `ring-frame.test.sh` (step 11 of loop 77 ran the ring and the ECC ring only) | AZ-3355 AC-5 | wired in: ring stage runs `ring-frame.sh` and `ring-frame-drivers.test.sh`, scaffold stage runs `ring-frame.test.sh` | clear (AZ-3355 AC-5 asks for step 11 wiring) |
| 3 | `refuse.open.short` of vectors.txt is not a new ring row: the open rows already hold the short packet (`E3.short`), so 22 of the 23 refusal cases are added | AZ-3354 AC-1 | 22 rows as the spec says | clear |
| 4 | The `seal` row kind gained an optional `out_len` (exact fit rows `fit.tag4`, `fit.clear`, opened into a buffer of exactly the plaintext), which the spec's AC-4 needed to prove the BufferFull boundary | AZ-3354 AC-4 | done | clear |
| 5 | The refusal display still shows five lines a reader (out of scope) | none | left | clear |

## Commit

`[AZ-3354] Frame ring refusal rows by name, dirs and out_len`; `[AZ-3355] Frame ring strict driver input and writer blame`. Both: `Loop: 78`.

## Next Batch: All tasks complete
