# Handoff to loop 65

From the loop 64 record (`record64.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) is empty after close.

## Shipped in loop 64

The retrospective of loops 61 to 63 (`_docs/06_metrics/retro_2026-10-23_loop64.md`), two new lessons (LESSONS.md trimmed back to its 15 entries) and one `AGENT_GOTCHAS.md` line (figures in an AC come from a run on HEAD). No source change; Cortex-M4F flash 7,724 B (margin 468 B), stack 496 B (margin 16 B) as at the end of loop 63.

## First actions of loop 65

0. CI of the loop 64 push (`dev` and `main`, docs only): `gh run list --repo zxsanny/packbin --branch dev` and `--branch main`. No record-only commit was pushed for it (retro improvement 3): note the result in the first commit of loop 65.
1. Replay the Jira leftovers when the Atlassian connector is back: `2026-10-22_loop59_jira_in_testing.md`, then `2026-10-22_loop60_jira_create_tasks.md` (five tasks; search by key range first).
2. No retro is due (next after loop 68, or an incident).

## Owner input needed

- Retro improvement 2: is there a consumer for the 468 B of flash margin, or should a loop target the stack (margin 16 B)? Without one, no further flash loop.
- Retro improvement 3: `paths-ignore: ["_docs/**"]` on the `push` trigger of `.github/workflows/test.yml` (a push touching any other path still runs in full).
- Unchanged: size limits for the Rust feature sets (`loops/loop53/smoke53.md`); CS-D5 before the first `v*` tag; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; whether to close U24 in the C++ package.

## Candidates (not specs yet)

- **`item` pointer removal**: the last Array-only pointer in `Field`; needs the element offset and stride (up to 4 B more per entry), so it only pays under 4 B.
- **Out-of-line error helpers in `unpack.cpp` / `values.cpp`**: the trick saved 52 B in `pack.cpp`; unmeasured on the other two. Measure on a tree copy first (about 5 s a shape).
- **Flag-byte chain inside a `times` round** (not built).
- From loop 53: session stack (derive keys in place), `session_core` outside the clippy deny list (security O3), a ring driver for `nostd`.

## Risks

- **L63-1**: flash margin 468 B (pin 7,724 B), stack margin 16 B (`AGENT_GOTCHAS.md`). Helpers called from `unpack_one` keep three real arguments. The out-of-line `bad` adds a leaf frame on error paths that the stage does not measure (bounded at about 492 B).
- **L58-1**: the compose `go` stage needs outbound network from the container (`AGENT_GOTCHAS.md`).
- A Jira connector timeout can hide a create that landed: search by key range before creating again.
- Host `cpp/build/` can hold ELF objects after a `gcc:16` run: `make -C cpp clean` before a Mac `make test` (`AGENT_GOTCHAS.md`).
- Every figure an AC names comes from a run on HEAD in the same loop (`AGENT_GOTCHAS.md`, new in loop 64).
