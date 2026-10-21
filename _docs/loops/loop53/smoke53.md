# Loop 53 smoke — checks

LOCAL_URL: none (a library; the proof is the test stages and CI)
Branch: dev
Script: `smoke53.sh` in this folder (`bash _docs/loops/loop53/smoke53.sh`; Docker and the rustup target `thumbv7em-none-eabihf` are needed).

## Checks

- [x] 1. No application source is dirty
- [x] 2. The crate builds as `no_std` with default features off, with `session`, with `text,ecc,session`, and the 12 flat heap-free tests pass
- [x] 3. The default Rust suite passes (823 tests, 41 targets)
- [x] 4. AZ-2756 AC-1..AC-3: the session gives the bytes of the std `PackSession` (parity 0, 2, 4, 8, 32), opens std packets, refuses bad seeds, nonces, sessions not open, full buffers, tampered and short packets; no std and std with ecc (35 tests)
- [x] 5. AZ-2757 AC-1, AC-2, AC-4: 15 unpack, 2 limit and 14 construct cases, 20 pack cases, the fuzz corpus and mutations, golden, 346 + 42 text rows, 35 ECC rows, the raw memo, the documents (21 tests)
- [x] 6. AZ-2757 AC-3: `cargo publish --dry-run` from a staged copy with the root README packages 149 files; the build with default features off passes
- [x] 7. Mutants on a copy of `rust/`: a session that never moves its send position, and a `times` count that is never written, are both caught
- [x] 8. The Cortex-M4F images `base`, `text`, `ecc` and `session` link, run under QEMU, have no heap or panic symbol: base 14,700 B / 456 B, text 26,632 B / 2,760 B, ecc 17,980 B / 760 B, session 18,404 B / 1,832 B
- [x] 9. `checks.test.sh` and `run-suite.test.sh` pass

## Result

Agent run 2026-10-21 at `6526c08` (owner rule 2026-10-12 in `deployment_procedures.md`): **9/9 steps passed**, first run, about 180 s. Step 11 at the same commit (`scripts/loop-tests.sh`, all stages because `run-suite.sh` changed): 13 passed, 1 skipped as unchanged (ac10), 0 failed, 1,065 s; rust 149 s, scaffold 348 s, swift 416 s, ring 64 s, publish gate 379 s; vcpkg supports/consumer checks NOT RUN on this host.

## For the operator

- Jira: AZ-2756 and AZ-2757 are In Testing; the epic AZ-2750 is yours to close (all eight slices shipped).
- Owner input: size limits for `text`, `ecc` and `session` (figures above); CS-D5; the first `v*` and `go/v*` tags; F44; whether to close U24 in the C++ package.
- New candidate for a ticket still open: the C++ `when` of a skipped source (see `handoff54.md`).
