# Handoff to loop 56

From the loop 55 record (`record55.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) is empty.

## Shipped in loop 55

AZ-3132 (3-deep `when` chain on the Cortex-M4F image: 780 B of stack at first, 504 B total after `pack_children` / `unpack_children` enter a held child `when` in their own loop; packets unchanged), AZ-3141 (chain of `when`s that each read a flag byte: 668 B net on unpack at first, 500 B after `unpack_children` also enters the flag scope and the flag bit), AZ-3133 (three bool-source corpus cases in eight packages; the empty-group source pinned in C++ and Rust), AZ-3134 (the 65,535 x 200 case timed in seven packages, worst 0.25 s of 1 s; new tests in Go and Swift). Jira: all four In Testing; epic AZ-2645 open.

## Owner input needed

- Size limits for the Rust feature sets (`loops/loop53/smoke53.md`); CS-D5 before the first `v*` tag; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; whether to close U24 in the C++ package (the Rust core refuses the three `pack_novalue_count_clear_when_*` cases, the C++ runner still skips them).
- The Xcode licence of loop 54 is no longer a blocker: `/usr/bin/python3` runs and `xcode-select -p` is Xcode.app (Swift 6.4; `AGENT_GOTCHAS.md` updated).

## Candidates (not specs yet)

- **Flash first** (review #2, Low): `reads_flag_byte` rescans a `when`'s entries on every unpack call. A resolve-time bit in `Field` would remove it; the flash margin is 72 B, so find a saving in `cpp/src/core` before any other C++ edit.
- **One path for held whens** (review #1, Medium): the `when` and flag-bit handling is in `unpack_children` and in the `unpack_one` cases (still used by `unpack_table`, a `times` round and a flags member). Fold them into one function if the flash allows; measure the stack of a chain reached through a `times` round.
- **Corpus counts** (review #5, Low): the case counts are hard-coded in the Go, Swift and Rust no-heap loaders; derive them from `cases.txt`.
- From loop 53: session stack (derive keys in place), `session_core` outside the clippy deny list (security O3), a ring driver for `nostd`.

## Risks

- **L55-1**: flash margin 72 B, stack margin 8 B (`AGENT_GOTCHAS.md`).
- L54-1 (a C++ `when` source more than 255 entries behind its `when` is `SchemeInvalid`), L52-1, L51-1: as in `handoff55.md`.

## CI read after the push

Recorded in `record55.md` (`ci:` line); the seven AZ-3134 figures on CI come from the job logs of that run (`gh api repos/zxsanny/packbin/actions/jobs/<id>/logs --allow-escape-sequences`).
