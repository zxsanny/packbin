# Handoff to loop 62

From the loop 61 record (`record61.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) is empty after close.

## Shipped in loop 61

A measurement, no library change: the pack-side `held_of` was built in five shapes and measured on the Cortex-M4F image. Every shape grows flash over the pin (8,076 to 8,104 B against 8,032 B), so none is kept; the figures are in `_docs/02_tasks/done/AZ-PENDING_cpp_pack_held_of_measure.md`, the best-stack shape is the patch `_docs/loops/loop61/pack_held_of_a.patch`, and `AGENT_GOTCHAS.md` says not to retry without a 72 B saving first.

## First actions of loop 62

0. CI of the loop 61 push: read `dev` and `main` with `gh run list --repo zxsanny/packbin --branch main` and `--branch dev`. If `main` again has no `test.yml` run, tell the owner and ask before any manual trigger or empty-commit push (`meta-rule.md`).
1. Replay the Jira leftovers when the Atlassian connector is back, in this order: `2026-10-22_loop59_jira_in_testing.md`, then `2026-10-22_loop60_jira_create_tasks.md` (now three tasks: add the loop 61 measure task; search by key range first).

## Owner input needed

- Size limits for the Rust feature sets (`loops/loop53/smoke53.md`); CS-D5 before the first `v*` tag; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; whether to close U24 in the C++ package.
- Whether to raise the flash pin for a pack-side `held_of` (not recommended: +44 to +72 B for no limiting-side gain).

## Candidates (not specs yet)

- **`Field` layout**: dropping `item` and `count` from the 36 B probe entry would save about 8 B per entry (14 entries); needs `static_assert(offsetof(Field, eq) == 16)`. A saving here could pay for other work in `cpp/src/core`.
- **Flag-byte chain inside a `times` round** (not built).
- From loop 53: session stack (derive keys in place), `session_core` outside the clippy deny list (security O3), a ring driver for `nostd`.

## Risks

- **L57-1**: flash margin 160 B (pin 8,032 B), stack margin 8 B (`AGENT_GOTCHAS.md`). Helpers called from `unpack_one` keep three real arguments.
- **L58-1**: the compose `go` stage needs outbound network from the container (`AGENT_GOTCHAS.md`).
- A Jira connector timeout can hide a create that landed: search by key range before creating again.
- Host `cpp/build/` can hold ELF objects after a `gcc:16` run: `make -C cpp clean` before a Mac `make test` (`AGENT_GOTCHAS.md`).
