# Handoff to loop 63

From the loop 62 record (`record62.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) is empty after close.

## Shipped in loop 62

`Field::count` is gone: an Array's count is its first member and `array_count` reads it in place. `sizeof(Field)` 32 B on 32-bit ARM (36 B before, guarded by a `static_assert`), Cortex-M4F flash 7,808 B (was 8,032 B, margin now 384 B, pin lowered), stack 496 B (margin 16 B). Figures in `AGENT_GOTCHAS.md` and the C++ description.

## First actions of loop 63

0. CI of the loop 62 push: `gh run list --repo zxsanny/packbin --branch dev` and `--branch main`.
1. Replay the Jira leftovers when the Atlassian connector is back: `2026-10-22_loop59_jira_in_testing.md`, then `2026-10-22_loop60_jira_create_tasks.md` (now four tasks: add the loop 62 `cpp_field_layout_shrink`; search by key range first).

## Owner input needed

- Size limits for the Rust feature sets (`loops/loop53/smoke53.md`); CS-D5 before the first `v*` tag; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; whether to close U24 in the C++ package.
- Whether to spend the new 384 B flash margin on the pack-side `held_of` (loop 61: +44 to +72 B, saves 0 to 8 B of pack stack, not the limiting side).

## Candidates (not specs yet)

- **`item` pointer removal**: the last Array-only pointer in `Field`; needs the element offset and stride (up to 4 B more per entry) so it only pays when it stays under 4 B; the other Array-only members could share a union only if the scheme builders stay `constexpr` in C++17 (they do not today).
- **Flag-byte chain inside a `times` round** (not built).
- From loop 53: session stack (derive keys in place), `session_core` outside the clippy deny list (security O3), a ring driver for `nostd`.

## Risks

- **L62-1**: flash margin 384 B (pin 7,808 B), stack margin 16 B (`AGENT_GOTCHAS.md`). Helpers called from `unpack_one` keep three real arguments.
- **L58-1**: the compose `go` stage needs outbound network from the container (`AGENT_GOTCHAS.md`).
- A Jira connector timeout can hide a create that landed: search by key range before creating again.
- Host `cpp/build/` can hold ELF objects after a `gcc:16` run: `make -C cpp clean` before a Mac `make test` (`AGENT_GOTCHAS.md`).
