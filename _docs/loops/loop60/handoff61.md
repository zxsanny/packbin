# Handoff to loop 61

From the loop 60 record (`record60.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) is empty after close.

## Shipped in loop 60

Two test-only tasks (Jira keys pending), commit 740e7fe: the C++ dict key order test prints the `Error` returned and expected by name for each pair and never packs a pair whose key `put_key` refused; the Rust `listed_inputs` counts by name, kind and lowercase hex without a `Vec` per line. The retrospective for loops 56 to 60 is `_docs/06_metrics/retro_2026-10-22_loop60.md` (3 lessons).

## First actions of loop 61

0. Read the CI of the loop 60 push (9bb9626, `dev` and `main`): GitHub had started no `test.yml` run 28 minutes after the push. `gh run list --repo zxsanny/packbin --workflow test.yml`; if there is still none, report it, do not trigger a run by hand. A red job: read its log first (`AGENT_GOTCHAS.md`).
1. Replay the Jira leftovers when the Atlassian connector is back, in this order: `2026-10-22_loop59_jira_in_testing.md` (AZ-3163 and AZ-3164 to In Testing), then `2026-10-22_loop60_jira_create_tasks.md` (search by key range first, create the two tasks under AZ-2645, rename the two `AZ-PENDING_*` spec files in `done/`, move them to In Testing).
2. Do not open another Review-Lows loop for the four Lows below (retro lesson of loop 60): pick product work or an owner item.

## Owner input needed

- Size limits for the Rust feature sets (`loops/loop53/smoke53.md`); CS-D5 before the first `v*` tag; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; whether to close U24 in the C++ package.

## Candidates (not specs yet)

- **`pack_children`** still decides When / FlagBit inline (the `held_of` idea on the pack side; flash cost unknown, margin 160 B).
- **`Field` layout**: dropping `item` and `count` from the 36 B probe entry would save about 8 B per entry (14 entries); needs `static_assert(offsetof(Field, eq) == 16)`.
- **Flag-byte chain inside a `times` round** (not built).
- From loop 53: session stack (derive keys in place), `session_core` outside the clippy deny list (security O3), a ring driver for `nostd`.

## Accepted Lows of loop 60 (test code, do not open a loop for them)

`kKeyRefused` reuses `Error::TooLong`; the pair message is formatted on every pair and the `put_key` failure line does not name the pair; the Rust hex check accepts odd-length hex; a corpus count mismatch does not name the bad line.

## Risks

- **L57-1**: flash margin 160 B (pin 8,032 B), stack margin 8 B (`AGENT_GOTCHAS.md`). Helpers called from `unpack_one` keep three real arguments.
- **L58-1**: the compose `go` stage needs outbound network from the container (`AGENT_GOTCHAS.md`).
- A Jira connector timeout can hide a create that landed: search by key range before creating again.
- Host `cpp/build/` can hold ELF objects after a `gcc:16` run: `make -C cpp clean` before a Mac `make test` (`AGENT_GOTCHAS.md`).
