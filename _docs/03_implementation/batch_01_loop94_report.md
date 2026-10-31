# Batch 1 loop 94 - AZ-3479 drop the Cortex-M4F rows

Commit 6f1baf9. Parent alone (no workers). Review: code-review (low), 0 findings.

## Result

| AC | Evidence |
|----|----------|
| AC-1 | `cpp/embedded/run.sh` table and `rust/embedded/run.sh` list no M4F row; the report of the real run has cpp-m0plus, cpp-m3-qemu, cpp-m33f, cpp-s390x, cpp-avr-uno, rust-m33f, rust-mutants, all PASS |
| AC-2 | `git grep` of the 13 names in cpp, rust, scripts, .github, compose, README: 0 hits (the two `mps2-an386` comment hits were reworded) |
| AC-3 | scratch copy, Rust stage alone, no earlier log: rust-m33f PASS, 0 target(s) failed |
| AC-4 | scratch copy with the clean lib in place of `mutant-panic`: `NOTE FAIL the panic check found nothing in the image with the seeded panic defect`, 1 target(s) failed; with the seeded lib: PASS |
| AC-5 | baseline on a HEAD copy before the edit vs after: M33F 315 of 315, flash 25,760 B, stack 724 B, frame 8,416 B / 912 B, Rust pins equal, compile warnings 0; `diff` of the figure lines shows only the removed M4F lines |
| AC-6 | `lib.test.sh`, `run-parts.test.sh`, `checks.test.sh` pass |
| AC-7 | README (3 sentences), AGENT_GOTCHAS, rust/embedded README, Makefile, CMakeLists, test.yml (step names, `rustup target add`), loop-tests.sh; `_docs/02_document` in step 13 |
| AC-8 | `scripts/loop-tests.sh --only cpp-embedded-arm,rust-embedded,scaffold`: 3 passed, 0 failed, 198 s |

## Discovered during implementation

| scenario or question | spec ref | proposed handling | clear / unclear |
|----------------------|----------|-------------------|-----------------|
| `arm/size_main.cpp` is also the stack-meter baseline of `cpp-m33f` | AC-2 (`size_main` has 0 hits) | renamed to `baseline_main.cpp`, cut to the baseline; the 14-entry probe half had no reader | clear |
| `-fstack-usage` and the `.su` files were read only by `max_frame` | AC-2 | flag removed | clear |
| Rust libs were built into `build/` (M4F) and `build-m33f/` | AC-3, AC-4 | one folder `build/` for thumbv8m; `.gitignore` line for `build-m33f` removed; `limits.txt` deleted, `limits-m33f.txt` is the one file | clear |
| `PACKBIN_RUST_EMBEDDED_LIMITS` (M4F) | AC-2 | removed; `..._M33F` stays | clear |
| Dockerfile and `startup.c` comments named `mps2-an386` | AC-7 | reworded | clear |

Process note: a chained command whose first step failed (`rsync`, root-owned `rust/target`) ran its later steps in the real tree and copied the clean lib over the real `mutant-panic` lib; found from a failing scratch run, the dir was removed and rebuilt (cargo does not check output content), the libs differ again, and the final loop-tests run came after.
