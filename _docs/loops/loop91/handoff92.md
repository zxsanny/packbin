# Handoff to loop 92

From the loop 91 record (`record91.md`). The hopper (`_docs/02_tasks/todo/`) and the backlog are empty after close.

## Shipped in loop 91

F44 steps for the owner in the publisher section of `release_notes_0.4.0.md` (UI settings, one `gh api` command, the check, cautions). Nothing applied to GitHub.

## Owner input needed

- Apply the F44 ruleset (read the rulesets listing back), then tag `v0.4.0`. CS-D5 is decided (tables stay, loop 90).
- Whether to close the epic AZ-2750 in Jira.
- Unchanged: U24 in the C++ package; the M4F row; meshbell `FrameSession` rename; vcpkg `supports`; a public-key pairing step; multi-part MAC rows in the ring.
- The hopper is empty: loop 92 needs an owner decision from the list above or a new feature.

## Candidates (not specs yet; probe each on HEAD first)

The AVR runtime check of `chacha20_xor` on a 16-bit `size_t` (needs an emulator); a Go window floor of 10 s (conditional); a ring driver for `nostd`; a non-secure 128 KiB image; cycle timing on a real part.
