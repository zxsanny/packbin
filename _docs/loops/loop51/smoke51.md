# Loop 51 smoke — checks

LOCAL_URL: none (a library; the proof is the test stages and CI)
Branch: dev
Script: `smoke51.sh` in this folder (`bash _docs/loops/loop51/smoke51.sh`; Docker and the rustup target `thumbv7em-none-eabihf` are needed).

## Checks

- [x] 1. No application source is dirty
- [x] 2. The crate builds as `no_std` with default features off and the 12 flat heap-free tests pass
- [x] 3. The default Rust suite passes (815 tests, 29 targets)
- [x] 4. AZ-2752 AC-1 to AC-4: flags, flag bytes, bits, u2, packed, sized and `when` pack and read as std does (11 tests)
- [x] 5. AZ-2753 AC-1, AC-2, AC-4: repeat, group, times and lists pack and read as std does; limits; the route example (12 tests)
- [x] 6. Mutants on a copy of `rust/`: a `repeat` on for empty rounds, and a `when` that ignores a skipped source, are both caught
- [x] 7. The Cortex-M4F image links, decodes the golden fixture under QEMU, has no heap or panic symbol: flash 13,724 B of 16,384, stack 472 B of 512
- [x] 8. The owner's base limit is in force: limits one byte below each figure fail and name them (`flash 13724 B over 13723 B`, `stack 472 B over 471 B`)
- [x] 9. `checks.test.sh`, `publish-jobs.test.sh`, `run-parts.test.sh` and `loop-tests.test.sh` pass

## Result

Agent run 2026-10-20 at `92d2cdd` (owner rule 2026-10-12 in `deployment_procedures.md`): **9/9 steps passed**, first run, 120 s. Step 11 at the same commit: 4 stages passed (`rust` 52 s, `rust-embedded` 4 s, `ring` 64 s, `publish-gate` 336 s; 456 s, host load 7 to 9). The other stages cover nothing this loop touched (only `rust/` and `_docs/` changed).

## For the operator

- Jira: AZ-2752 and AZ-2753 are In Testing; AZ-2754 to AZ-2757 are To Do (AZ-2754 now holds dictionaries too).
- Owner decision this loop: base flash limit 16,384 B (was 8,192).
- New candidate for a ticket: the C++ `when` of a skipped source (see `handoff52.md`).
- Still yours: text/ecc/session size limits, CS-D5, the first `v*` and `go/v*` tags, F44.
