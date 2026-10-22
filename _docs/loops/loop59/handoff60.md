# Handoff to loop 60

From the loop 59 record (`record59.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) is empty.

## Shipped in loop 59

AZ-3163 (Rust nostd corpus count by the README name rule) and AZ-3164 (C++ dict key order test: `put_key` guard, `pack_error` returning the `Error`). Both test-only, commit 2a0d510. Jira: both still To Do, the move to In Testing is a leftover (`_docs/_process_leftovers/2026-10-22_loop59_jira_in_testing.md`); epic AZ-2645 open.

## First actions of loop 60

1. Replay the Jira leftover when the Atlassian connector is back (two `transitionJiraIssue` calls, read back).
2. A retrospective is due: the last was loop 55, and loop 60 makes five loops since.

## Owner input needed

- Size limits for the Rust feature sets (`loops/loop53/smoke53.md`); CS-D5 before the first `v*` tag; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; whether to close U24 in the C++ package.

## Candidates (not specs yet)

- **Review Lows of loop 59** (all test code): the C++ pair assertions print a fixed message, not the `Error` returned; an oversize key in `put_key` leaves an empty key and the pair is still packed; the Rust count rule does not check the kind field or lower-case hex; one `Vec` per corpus line.
- **`pack_children`** still decides When / FlagBit inline (the `held_of` idea on the pack side; flash cost unknown, margin 160 B).
- **`Field` layout**: dropping `item` and `count` from the 36 B probe entry would save about 8 B per entry (14 entries); a layout change with `static_assert(offsetof(Field, eq) == 16)`.
- **Flag-byte chain inside a `times` round** (not built).
- From loop 53: session stack (derive keys in place), `session_core` outside the clippy deny list (security O3), a ring driver for `nostd`.

## Risks

- **L57-1**: flash margin 160 B (pin 8,032 B), stack margin 8 B (`AGENT_GOTCHAS.md`). Helpers called from `unpack_one` keep three real arguments.
- **L58-1**: the compose `go` stage needs outbound network from the container (`AGENT_GOTCHAS.md`).
- A Jira connector timeout can hide a create that landed: search by key range before creating again.
- L54-1, L52-1, L51-1: as in `handoff55.md`.

## CI read after the push

Read for the loop 59 push after it lands: `gh run list --repo zxsanny/packbin --workflow test.yml`; job logs with `gh api repos/zxsanny/packbin/actions/jobs/<id>/logs --allow-escape-sequences`.
