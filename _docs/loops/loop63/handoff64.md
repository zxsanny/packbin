# Handoff to loop 64

From the loop 63 record (`record63.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) is empty after close.

## Shipped in loop 63

`pack.cpp` is 84 B smaller on the Cortex-M4F image: 7,724 B (was 7,808 B, margin 468 B, pin lowered), stack unchanged (496 B deepest, margin 16 B). `pack_u2` writes in place and `bad` is out of line. The pack-side `held_of` was measured on top (+44 B / +72 B) and dropped by the owner. Figures in `AGENT_GOTCHAS.md` and the C++ description.

## First actions of loop 64

0. **Push first.** The loop 63 close was committed locally only: `github.com` did not resolve at close (2026-10-23). When the network is back: `git fetch --prune`, then `git push origin dev` and `git push origin HEAD:main` (both fast-forward; `loop_end_merge: main`), then the CI of that push: `gh run list --repo zxsanny/packbin --branch dev` and `--branch main`.
1. Replay the Jira leftovers when the Atlassian connector is back: `2026-10-22_loop59_jira_in_testing.md`, then `2026-10-22_loop60_jira_create_tasks.md` (now five tasks: add the loop 63 `cpp_pack_flash_saving`; search by key range first).
2. A retro is due (loops 61 to 63 since the last one): `/retrospective` when the loop is not a short one.

## Owner input needed

- Size limits for the Rust feature sets (`loops/loop53/smoke53.md`); CS-D5 before the first `v*` tag; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; whether to close U24 in the C++ package.

## Candidates (not specs yet)

- **`item` pointer removal**: the last Array-only pointer in `Field`; needs the element offset and stride (up to 4 B more per entry) so it only pays when it stays under 4 B.
- **More flash in `pack.cpp`/`unpack.cpp`/`values.cpp`**: out-of-line error helpers saved 52 B in `pack.cpp`; the same trick on `unpack.cpp` and `values.cpp` is unmeasured. Measure on a tree copy first.
- **Flag-byte chain inside a `times` round** (not built).
- From loop 53: session stack (derive keys in place), `session_core` outside the clippy deny list (security O3), a ring driver for `nostd`.

## Risks

- **L63-1**: flash margin 468 B (pin 7,724 B), stack margin 16 B (`AGENT_GOTCHAS.md`). Helpers called from `unpack_one` keep three real arguments. The out-of-line `bad` adds a leaf frame on error paths that the stage does not measure (bounded at about 492 B).
- **L58-1**: the compose `go` stage needs outbound network from the container (`AGENT_GOTCHAS.md`).
- A Jira connector timeout can hide a create that landed: search by key range before creating again.
- Host `cpp/build/` can hold ELF objects after a `gcc:16` run: `make -C cpp clean` before a Mac `make test` (`AGENT_GOTCHAS.md`).
