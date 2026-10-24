# Handoff to loop 68

From the loop 67 record (`record67.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) is empty after close.

## Shipped in loop 67

`unpack_children` keeps the outer flag bytes of a `when` in its own frame (copied for a `when` only, put back through a `keep` pointer): a flag-scope level costs 56 B of stack, was 80 B. Cortex-M4F: stack 540 B (612 B), flash 7,712 B (7,724 B, margin 480 B); `stack_pin` 540, `flash_pin` 7712. New `when`-scope test in `flag_scope_host_tests.cpp`. Jira AZ-3185 (In Testing).

## First actions of loop 68

0. CI of the loop 67 push (`dev` and `main`): `gh run list --repo zxsanny/packbin --branch dev` and `--branch main`; read the `embedded-arm`, `ring` and `suites (cpp ...)` jobs first.
1. Retro is due after loop 68 (last retro covered loops 61 to 63; loops 64 to 68 are the next window).

## Owner input needed

- Unchanged: CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; whether to close U24 in the C++ package.
- A named consumer for the 480 B of flash margin and the 12 B between the stack pin and the session frame, or say the C++ stack and flash work is done.

## Candidates (not specs yet)

- **Session `open` frame** (528 B, the largest single core frame, 12 B under the pin): read `session.cpp` first; no consumer yet.
- **Smaller `Result`** (returned through a hidden pointer; a 16 B temporary in every walk frame): wide change, measure on a tree copy first.
- Unchanged: Go window floor of 10 s; `item` pointer removal; out-of-line error helpers in `unpack.cpp` / `values.cpp`; `session_core` clippy; ring driver for `nostd`.

## Risks

- **L67-1**: `unpack_children` decides "flag scope" from `Kind::When`; a new caller with another kind gets no restore.
- **L65-1**: `stack_pin` is now 540 B and `flash_pin` 7,712 B: any edit to `unpack.cpp` or `pack.cpp` that deepens the walk or adds flash fails the arm stage by its own bytes.
- **L66-1**: the Go window cannot cover a single ask that stalls 10 s or more after the probe.
- **L66-2**: the container `pip install` failure of loop 65 has no known cause; `ph_quote` now keeps 25 lines.
- GCC 16 `-Werror=maybe-uninitialized` fires on an array copied under a condition and read under the same condition (host build, -O1 to -O3, not at `-Os`): run `docker run --rm -v "$PWD":/src -w /src/cpp gcc:16 make test` before the commit.
- Host `cpp/build/` can hold ELF objects after a `gcc:16` run: `make -C cpp clean` before a Mac `make test`.
