# Handoff to loop 71

From the loop 70 record (`record70.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) is empty after close.

## Shipped in loop 70

The `rust-m33f` row of the Rust embedded stage (AZ-3231, epic AZ-2750): five feature sets for `thumbv8m.main-none-eabihf` on QEMU `mps2-an505`, ceilings 64 KB / 8 KB, pins in `rust/embedded/limits-m33f.txt` (base 15,132 B / 456 B, text 27,268 / 2,736, ecc 18,764 / 744, session 18,884 / 1,528, frame 20,236 / 1,752, Rust 1.98.1). `run.sh libs` builds with the CI toolchain on every host.

## First actions of loop 71

0. CI of the loop 70 push (`dev` and `main`): `gh run list --repo zxsanny/packbin --branch dev` and `--branch main`; read the `embedded-arm` job, the `rust-m33f` figures against the pins. A CI figure above a pin needs the owner.
1. Retro: not due (the last was loop 69; the next is after loop 73 or an incident).

## Owner input needed

- Unchanged: CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750 (all its slices, including the M33F row, are shipped); U24 in the C++ package; whether to drop the M4F row.
- Frame mode: the other seven packages and the order (meshbell's first consumers: C# server, Android through Java, iOS through Swift); PB-02 vector tests there; whether `frame` should be on with `std`; a replay window per key slot (F69-2); hardening of the `hkdf.rs` temporaries.

## Candidates (not specs yet)

- Frame mode in C#, Java and Swift with the shared `fixtures/frame/vectors.txt`, then a cross-language frame ring (`fixtures/frame/ring-cases.txt` is optional and absent).
- A non-secure image with 128 KiB of RAM; cycle timing on a real part.
- Unchanged: Go window floor of 10 s; `item` pointer removal; `session_core` clippy; ring driver for `nostd`.

## Risks

- **L70-1**: pins are exact Rust 1.98.1 figures; a toolchain bump in `test.yml` (`PACKBIN_EMBEDDED_RUST`) moves every figure, M4F and M33F, and needs a re-measure (flash and stack move in different directions between versions).
- **L70-2**: the M33F row compares its route packet with the M4F run of the same stage, so a single-row run fails by design.
- The `covers()` rule of `scripts/loop-tests.sh` runs everything when `run-suite.sh` or `publish-jobs.test.sh` changes: about 14 minutes on a quiet host.
