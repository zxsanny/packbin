# Handoff to loop 58

From the loop 57 record (`record57.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) is empty.

## Shipped in loop 57

AZ-3151 (inline byte loop in `keys_ascending` instead of `memcmp`: flash 8,080 B to 8,008 B), AZ-3152 (`held_of`, one decision function for both unpack walkers; flash 8,032 B, flag chain 476 B net; owner accepted it as the fold), AZ-3153 (Rust handler tables and `unused_handlers`, nostd expected-skip set, derived corpus counts in Swift and Rust nostd, one Go id helper), AZ-3154 (`flash_pin=8032` enforced by the arm stage). Jira: all four In Testing; epic AZ-2645 open.

## Owner input needed

- Size limits for the Rust feature sets (`loops/loop53/smoke53.md`); CS-D5 before the first `v*` tag; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; whether to close U24 in the C++ package.

## Candidates (not specs yet)

- **Review Lows of loop 57**: Rust nostd count check shares the loader's filter (guards the literal only); Go refusal check should print the named ids; `keys_ascending` helper-level test with a high byte (0x80 vs 0x7f) and a prefix pair; `pack_children` still decides When / FlagBit inline (the same `held_of` idea on the pack side, flash cost unknown).
- **`Field` layout**: dropping `item` and `count` from the 36 B probe entry would save about 8 B per entry (14 entries); a `Field` layout change with `static_assert(offsetof(Field, eq) == 16)`.
- **Flag-byte chain inside a `times` round** (not built).
- From loop 53: session stack (derive keys in place), `session_core` outside the clippy deny list (security O3), a ring driver for `nostd`.

## Risks

- **L57-1**: flash margin 160 B (pin 8,032 B), stack margin 8 B (`AGENT_GOTCHAS.md`). Helpers called from `unpack_one` keep three real arguments (a fourth blocks the tail call).
- L54-1 (a C++ `when` source more than 255 entries behind its `when` is `SchemeInvalid`), L52-1, L51-1: as in `handoff55.md`.

## CI read after the push

Read for the loop 57 push (83ea810): `dev` run 39771726639 and `main` run 39771458707 both green, 20 jobs each, 0 not success. First action of loop 58: nothing from CI; start from the candidates above. The result is in `record57.md` (`ci:`). `gh` lists runs with `gh run list --repo zxsanny/packbin --workflow test.yml`; job logs with `gh api repos/zxsanny/packbin/actions/jobs/<id>/logs --allow-escape-sequences`.
