# Batch Report

**Batch**: 2 (loop 50)
**Tasks**: AZ-2751_rust_core_embedded_profile
**Date**: 2026-10-20

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2751_rust_core_embedded_profile | Done | 20 files (`rust/embedded/**` 12 new, `test.yml`, `docker-compose.test.yml`, `loop-tests.sh` and its test, `Cargo.toml`, `.gitignore`, 2 library files, docs) | `rust-m4f` PASS, `rust-mutants` PASS (Docker, QEMU), `checks.test.sh`, `loop-tests.test.sh`, `publish-jobs.test.sh`, `run-parts.test.sh`, `lib.test.sh` pass | None |

## Code Review Verdict: not run per batch

Owner rule (2026-10-06): one total review per loop.

## Test Suite

- Embedded image stage (`docker compose run --rm rust-embedded`, Cortex-M4F on QEMU mps2-an386, toolchain 1.79 on this Mac, GCC 13.2.1 in the image):
  - golden fixture decoded on the device image: `GOLDEN_OK 1`; the 14-field route packs to 44 bytes and unpacks equal
  - `base`: flash 2,652 B (limit 8,192, after the review fixes; 2,656 B before), stack 88 B (limit 512; raw 152 less the meter's 64)
  - no heap symbol and no panic symbol in the linked image
  - seeded panic defect (table indexed by input): caught, `panic_bounds_check`; seeded heap defect (`Vec` through a malloc-backed allocator): caught, `__rust_no_alloc_shim_is_unstable`, `malloc`
  - a limit lowered by one byte (flash 2,651, stack 87): the stage fails and prints `flash 2652 B over 2651 B` and `stack 88 B over 87 B`
- Library tests after the panic-path fixes: 11 flat and 3 differential pass; clippy (deny unwrap, expect, panic, indexing, arithmetic) clean; doc test passes.
- Guards: `publish-jobs.test.sh`, `publish-workflow.test.sh`, `run-parts.test.sh`, `lib.test.sh`, `loop-tests.test.sh` pass.
- CI-parity: PASS. The new CI steps (toolchain, `rust/embedded/run.sh host`, `checks.test.sh`) have not run on GitHub yet; the first push reads them.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | The panic check found three real panic paths in the AZ-2749 code: `copy_from_slice`, `slice::reverse` (its `revswap` indexes `[..n]`), and a range index | AZ-2751 AC-5 | Fixed in `Writer::put` and `pack_field` (zipped copies); the lint deny list did not find them, the link check did | clear |
| 2 | The first seeded heap defect (`Box::new`) was optimized away and left only an allocator marker | AZ-2751 AC-4 | The mutant copies the input into a `Vec` behind `black_box`; it now links `malloc`, `_malloc_r`, `__rust_no_alloc_shim_is_unstable` | clear |
| 3 | `ld` 2.41 warns `libc_a-init.o: missing .note.GNU-stack` once a Rust object is linked; `arm_link` fails on any warning | AZ-2751 AC-1 | `-Wl,--no-warn-execstack` on the Rust links only, with a comment (a Cortex-M image has no executable-stack notion) | clear |
| 4 | New CI steps go into `embedded-arm` instead of a new job (the free plan runs 20 jobs; `publish-jobs.test.sh` caps at 20) | AZ-2751 | The job's wall time grows by the Rust install, build and stage; read from the annotations after the push, split if it becomes the longest job | clear |
| 5 | The toolchain download: the approved rustup target on this Mac (1.79); in CI `rustup toolchain install 1.98` plus the target | AZ-2751 | As approved; no download in Docker | clear |
| 6 | Feature sets: only `base` has code; `text`, `ecc`, `session` lines are added to `feature-sets.txt` by AZ-2754, AZ-2755 and AZ-2756 | AZ-2751 AC-2 | Documented in `feature-sets.txt` | clear |
| 7 | `cargo package --list` would have carried `embedded/` into the crate | AZ-2751 | `exclude = ["embedded/"]` in `rust/Cargo.toml` | clear |
| 8 | `cargo package` says the `readme = "README.md"` file is missing in `rust/` (before this loop too) | AZ-2757 | Left for the publish check of AZ-2757; not changed here | unclear (check how the publish gate supplies it) |

## Commit

`[AZ-2751] Rust embedded stage: QEMU run, sizes, heap and panic link checks`. Body: one line + `Loop: 50`.

## Next Batch: All tasks complete (loop 50 scope)
