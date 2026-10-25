# Handoff to loop 70

From the loop 69 record (`record69.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) is empty after close.

## Shipped in loop 69

Frame mode of the session in Rust (epic AZ-3199, umbrella AZ-3192): contract `pack-session.md` 2.0.0, ADR-008, `fixtures/crypto` (27 rows), `fixtures/frame` (170 rows, E1 to E5 from meshbell), the Rust `frame` feature (`Session::load_frame`, `seal_frame`, `open_frame`, `MacKey`, `ReplayWindow`), the embedded `frame` set (19,772 B flash, 1,896 B stack on the Cortex-M4F). Independent security review PASS_WITH_WARNINGS.

## First actions of loop 70

0. CI of the loop 69 push (`dev` and `main`): `gh run list --repo zxsanny/packbin --branch dev` and `--branch main`; read the `embedded-arm` job first and the `frame` row of `rust-embedded` (bound 20,480 B flash; a CI figure above it needs the owner), then `scaffold` and `ring`.
1. No retro is due (done in loop 69; the next is after loop 73 or an incident).
2. The original loop 69 pick, not done: **the Rust Cortex-M33F row** (nRF54L15 core) in the Rust embedded stage, next to `cpp-m33f` (`cpp/embedded/arm/mps2-an505.ld`, `m33f_*` in `cpp/embedded/lib.sh`); it needs its own flash and stack pins.

## Owner input needed

- Unchanged: CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; whether to drop the M4F row.
- Frame mode: the other seven packages and the order (meshbell's first consumers: C# server, Android through Java, iOS through Swift); PB-02 vector tests in those packages; whether `frame` should be on with `std`; a replay window per key slot (security review F69-2); hardening of the `hkdf.rs` temporaries.

## Candidates (not specs yet)

- Frame mode in C#, Java and Swift with the shared `fixtures/frame/vectors.txt`, then a cross-language frame ring (`fixtures/frame/ring-cases.txt` is optional in AZ-3202 and absent).
- Rust Cortex-M33F row (above); a non-secure image with 128 KiB of RAM; cycle timing on a real part.
- Unchanged: Go window floor of 10 s; `item` pointer removal; `session_core` clippy; ring driver for `nostd`.

## Risks

- **L69-1**: the CI runner's Rust 1.98 gives 2 to 4% more flash than this Mac's cargo 1.79; the `frame` limit of 20,480 B is the owner's bound, 19,772 B here.
- **L69-2**: a new public enum variant breaks exhaustive matches (see `AGENT_GOTCHAS.md`); `Error` is not `non_exhaustive`, so downstream matches on it break too (the crate is unpublished, 0.1.0).
- **L69-3**: the contract is wire-pinned by meshbell once it takes the commit: a changed fixture row is a wire change.
- The `covers()` rule of `scripts/loop-tests.sh` runs everything when `run-suite.sh` or `publish-jobs.test.sh` changes: about 14 minutes on a quiet host.
