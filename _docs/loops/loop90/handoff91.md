# Handoff to loop 91

From the loop 90 record (`record90.md`). The hopper (`_docs/02_tasks/todo/`) and the backlog are empty after close.

## Shipped in loop 90

CS-D5 decided by the owner: the compact text tables stay for `v0.4.0` (docs only: `release_notes_0.4.0.md`, `compact-strings/scenarios.md`). No code, table or format change.

## Owner input needed

- Before the `v0.4.0` tag: F44 (a tag ruleset on `v*`; only the owner can apply it). The agent can write the exact settings and the `gh` command if asked.
- Whether to close the epic AZ-2750 in Jira.
- Unchanged: U24 in the C++ package; the M4F row; meshbell `FrameSession` rename; vcpkg `supports`; a public-key pairing step; multi-part MAC rows in the ring.
- The hopper is empty: loop 91 needs an owner decision from the list above or a new feature.

## Candidates (not specs yet; probe each on HEAD first)

The AVR runtime check of `chacha20_xor` on a 16-bit `size_t` (needs an emulator); a Go window floor of 10 s (conditional); a ring driver for `nostd`; a non-secure 128 KiB image; cycle timing on a real part.
