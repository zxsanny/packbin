# Handoff to loop 59

From the loop 58 record (`record58.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) is empty.

## Shipped in loop 58

AZ-3160 (Rust nostd corpus count by its own rule), AZ-3161 (Go refusal check names the ids), AZ-3162 (C++ `pack` key order with a high byte and prefix pairs, 7 checks). All test-only, commit ac3cc99. Jira: all three In Testing; epic AZ-2645 open.

## Owner input needed

- Size limits for the Rust feature sets (`loops/loop53/smoke53.md`); CS-D5 before the first `v*` tag; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; whether to close U24 in the C++ package.

## Candidates (not specs yet)

- **Review Lows of loop 58** (all test code): the Rust `listed_inputs` rule counts a three-field comment with a hex-looking last token (and drops a `-` placeholder), so it can disagree with the documented format; its `!f[2].is_empty()` is dead; C++ `put_key` has no `n <= 4` check; `packs_in_order` reports every refusal with one message.
- **`pack_children`** still decides When / FlagBit inline (the `held_of` idea on the pack side; flash cost unknown, margin 160 B).
- **`Field` layout**: dropping `item` and `count` from the 36 B probe entry would save about 8 B per entry (14 entries); a layout change with `static_assert(offsetof(Field, eq) == 16)`.
- **Flag-byte chain inside a `times` round** (not built).
- From loop 53: session stack (derive keys in place), `session_core` outside the clippy deny list (security O3), a ring driver for `nostd`.

## Risks

- **L57-1**: flash margin 160 B (pin 8,032 B), stack margin 8 B (`AGENT_GOTCHAS.md`). Helpers called from `unpack_one` keep three real arguments.
- **L58-1**: the compose `go` stage needs outbound network from the container (`AGENT_GOTCHAS.md`); on a hotspot it fails with `connection refused`.
- L54-1 (a C++ `when` source more than 255 entries behind its `when` is `SchemeInvalid`), L52-1, L51-1: as in `handoff55.md`.

## CI read after the push

(filled after the loop 58 push; the result is in `record58.md` `ci:`.)
