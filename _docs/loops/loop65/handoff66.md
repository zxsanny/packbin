# Handoff to loop 66

From the loop 65 record (`record65.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) is empty after close.

## Shipped in loop 65

`test.yml` push ignores `_docs/**`; Rust size limits for text, ecc and session (measured + 5%); scheme 0x5e (a 3-deep flag-byte `when` chain inside a `times` round) in the all-kinds image, unpack 612 B / pack 464 B; Cortex-M4F stack budget 2,048 B with `stack_pin` 612 B (owner); flash unchanged at 7,724 B.

## First actions of loop 66

0. CI of the loop 65 push (`dev` and `main`): `gh run list --repo zxsanny/packbin --branch dev` and `--branch main`. The push carries code, so `test.yml` runs in full; read the `publish-gate-*` jobs (one share each). The first docs-only commit after it shows whether `paths-ignore` works: it must start no `test` run.
1. Replay the Jira leftovers when the Atlassian connector is back (six tasks to create, two transitions).
2. No retro is due (next after loop 68, or an incident).

## Owner input needed

- Unchanged: CS-D5 (deferred to your 100 to 200 real messages); the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; whether to close U24 in the C++ package.
- A named consumer for the 468 B of flash margin, or a stack-reduction loop for the 612 B case (a part with 4 KB of RAM or less cannot use that scheme shape).

## Candidates (not specs yet)

- **Stack of a flag scope inside a `times` round** (612 B unpack): the walk from `unpack_items` through `unpack_one` into `unpack_children`; measure shapes on a tree copy first.
- **Publish gate under load**: make the 3 s proxy window of `publish-go.test.sh` and the container `pip install` of `publish-phases-failures.test.sh` load-aware, and keep the pip error in the log.
- Unchanged: `item` pointer removal; out-of-line error helpers in `unpack.cpp` / `values.cpp`; session stack; `session_core` clippy; ring driver for `nostd`.

## Risks

- **L65-1**: `stack_pin` 612 B (`cpp/embedded/lib.sh`): any edit to `unpack.cpp` or `pack.cpp` that deepens the walk fails the arm stage by its own bytes.
- **L65-2**: Rust limits are +5% of the loop 65 figures; a legitimate edit that grows an image needs a raise with a line in `limits.txt` saying what the bytes bought.
- **L58-1**: the compose `go` stage needs outbound network from the container (`AGENT_GOTCHAS.md`).
- A Jira connector timeout can hide a create that landed: search by key range before creating again.
- Host `cpp/build/` can hold ELF objects after a `gcc:16` run: `make -C cpp clean` before a Mac `make test`.
