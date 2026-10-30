# Handoff to loop 90

From the loop 89 record (`record89.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) and the backlog are empty after close.

## Shipped in loop 89

AZ-3443 (In Testing): the Rust suite adds the clippy component and runs `cargo clippy --lib --tests` over its nine feature sets in `rust_test_build`; a lint or a compiler warning fails the suite naming the set. Files: `.github/workflows/run-suite.sh`, `run-suite.test.sh`, `run-suite-rust-clippy.test.sh`. No change under `rust/`.

## First actions of loop 90

0. Read the CI of the loop 89 close push (`dev` and `main`) and record the Rust `suites` job time against the previous green run (AC-4: at most 120 s more). A change of `run-suite.sh` runs every stage in CI.
1. `uptime`, `df -h /tmp` and `ps -Ao pcpu,command --sort=-pcpu | head`.
2. Ring on this host: JDK on PATH (`~/.local/share/packbin-jdk26/bin`) and `LOOP_TESTS_PYTHON=/usr/bin/python3.14`; `scripts/loop-tests.sh --all --only ring` takes under a minute.

## Owner input needed

- Before the `v0.4.0` tag: CS-D5 and F44. Whether to close the epic AZ-2750 in Jira.
- Unchanged: U24 in the C++ package; whether to drop the M4F row; meshbell renames its Rust `Session` to `FrameSession`; vcpkg `supports`; a public-key pairing step; multi-part MAC rows in the ring.
- The hopper is empty: loop 90 needs an owner decision from the list above or a new feature.

## Candidates (not specs yet; probe each on HEAD first)

- The AVR runtime check of `chacha20_xor` on a 16-bit `size_t` (needs an emulator); a Go window floor of 10 s (conditional); a ring driver for `nostd`; a non-secure 128 KiB image; cycle timing on a real part.

## Risks

A Rust toolchain bump (`rust:1.98` tag, `RING_RUST`) can add clippy lints and turn the new gate red: the bump change fixes or justifies each one, with no `allow`. L84-1 (`m33f_flash_pin` has zero margin) is unchanged.
