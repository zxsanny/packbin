# Feature assessment — loop 70

loop: 70
feature: rust-m33f-row (Rust Cortex-M33F row in the Rust embedded stage; AZ-3231, epic AZ-2750)
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-10-25
**Implement pass**: batch 01 (`a593847`), report `_docs/03_implementation/batch_01_loop70_report.md`
**Verdict**: COMPLETE — 9 covered / 0 out-of-scope / 0 gap-clear / 0 gap-unclear (S9 deferred by the owner's earlier choice, counted below)

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | first run of the stage with the new row | covered | AC-1, AC-2; `rust-m33f` ran 5 sets with `FAILURES 0`, `GOLDEN_OK 1` (batch report figures); `target_rust_m33f` and `rust_row` in `rust/embedded/target.sh`, libraries in `run.sh` | intake |
| S2 | a later edit raises a set's flash or stack above its pin | covered | AC-5, AC-6; the one-byte-low smoke printed `NOTE FAIL frame: flash 20236 B over 20235 B` and `1 target(s) failed`; `within` in `rust/embedded/checks.sh`, pins in `limits-m33f.txt` | intake |
| S3 | a figure goes above 64 KB or 8 KB | covered | AC-5; `rust_flash_ceiling` and `rust_stack_ceiling` from `m33f_*` in `cpp/embedded/lib.sh` checked with `within` in `rust_row`; `checks.test.sh` holds every pin under the ceilings; the bite itself shares the code of the pin check | intake |
| S4 | M33F and M4F pack the route and decode the golden | covered | AC-4; `rust_same_as` compares `ROUTE_HEX` per set; the run passed with equal packets; the row fails naming the earlier log when it is missing | intake |
| S5 | the M4F row, its limits and the mutants | covered | AC-7; `limits.txt` untouched; M4F figures of the same run equal CI's loop 69 figure (frame 20,164 B); `rust-mutants` PASS | intake |
| S6 | CI runs `embedded-arm` | covered | AC-8; `test.yml` installs both targets; `publish-jobs`, `publish-workflow`, `publish-pins` self-tests pass; the CI run itself is read after the push (a gap above a pin is a named blocker) | intake |
| S7 | a library for the M33F target is missing | covered | AC-1; `rust_row` fails naming the path and `run.sh libs`; same code as the M4F row, which existed | intake |
| S8 | CI's Rust 1.98 gives other figures than a local toolchain | covered | AC-5; pins built with `RUSTUP_TOOLCHAIN=1.98` (rustc 1.98.1); M4F figure under that toolchain equals the CI figure of loop 69; Rust 1.79 gives lower M33F figures (frame 19,844 B) so a local run with the Mac default stays under the pins | intake |
| S9 | the owner drops the M4F row later | deferred (owner, not this loop) | `rust_row` shares no state between rows except the earlier row's logs, which the M33F row needs for AC-4; dropping M4F would need that compare reduced | intake |

### Discovered during implementation

Three rows in the batch report, all `clear` and handled (ceiling bite shares the pin check's code; single-row runs need the M4F logs; probe and `rust/src` unchanged).

### Not walked

- Real nRF54L15 hardware, TrustZone non-secure images (128 KiB of RAM), the RISC-V coprocessor, cycle timing (problem and scenarios record them).
- CI figures of the M33F row: read after the push (loop close).
