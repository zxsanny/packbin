# Loop 52 smoke — checks

LOCAL_URL: none (a library; the proof is the test stages and CI)
Branch: dev
Script: `smoke52.sh` in this folder (`bash _docs/loops/loop52/smoke52.sh`; Docker and the rustup target `thumbv7em-none-eabihf` are needed).

## Checks

- [x] 1. No application source is dirty
- [x] 2. The crate builds as `no_std` with default features off, with `text,ecc` on, and the 12 flat heap-free tests pass
- [x] 3. The default Rust suite passes (820 tests, 35 targets)
- [x] 4. AZ-2754 AC-1..AC-5: strings and dictionaries pack and read as std does; 427 vector rows; scratch too small; six hostile dictionary packets; text off (27 tests)
- [x] 5. AZ-2755 AC-1..AC-4: parity, repair in place, 254-byte limit, 1,339 vector rows, std differential; ecc off (15 tests)
- [x] 6. Mutants on a copy of `rust/`: a dictionary that accepts a repeated key, and a repair that ignores the limit, are both caught
- [x] 7. The Cortex-M4F images `base`, `text` and `ecc` link, run under QEMU, have no heap or panic symbol: base 14,532 B / 456 B, text 24,888 B / 1,344 B, ecc 17,804 B / 760 B
- [x] 8. The owner's base limit is in force: limits one byte below each figure fail and name them
- [x] 9. `checks.test.sh`, `publish-jobs.test.sh`, `run-parts.test.sh`, `loop-tests.test.sh` and `run-suite.test.sh` pass

## Result

Agent run 2026-10-20 at `1d23c18` (owner rule 2026-10-12 in `deployment_procedures.md`): **9/9 steps passed**, first run, about 210 s. Step 11 at the same commit: rust 92 s, scaffold 315 s and rust-embedded 6 s passed at the first run; ring and publish-gate failed at the first run (host load 25 to 45: a NuGet "resource temporarily unavailable", a C# driver mismatch, a SwiftPM cache path, then a timing self-test pipe that passes 3 of 3 alone) and passed on the re-runs (ring 96 s, publish-gate 495 s at the third run; the vcpkg checks NOT RUN, no vcpkg on this host). The other stages cover nothing this loop touched (`rust/`, `.github/workflows/run-suite*.sh` rust lines and `_docs/` only).

## For the operator

- Jira: AZ-2754 and AZ-2755 are In Testing; AZ-2756 and AZ-2757 are To Do.
- Owner input: size limits for `text` (24,888 B / 1,344 B on the probe), `ecc` (17,804 B / 760 B) and `session`; CS-D5; the first `v*` and `go/v*` tags; F44.
- New candidate for a ticket still open: the C++ `when` of a skipped source (see `handoff53.md`).
