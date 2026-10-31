# Handoff to loop 94

From the loop 93 record (`record93.md`). The hopper (`_docs/02_tasks/todo/`) and the backlog are empty after close.

## Shipped in loop 93

AZ-3469: `cpp-m33f` and `rust-m33f` link and run in a 128 KiB RAM window (stack top 0x38020000, checked per image); an overflow or a moved window turns the row red. Figures unchanged.

## Owner input needed

- Apply the F44 ruleset (read the rulesets listing back), then tag `v0.4.0`. CS-D5 is decided.
- Whether to close the epic AZ-2750 in Jira.
- Unchanged: U24 in the C++ package; the M4F row; meshbell `FrameSession` rename; vcpkg `supports`; a public-key pairing step; multi-part MAC rows in the ring.
- The hopper is empty: loop 94 needs an owner decision from the list above or a new feature.

## Candidates (not specs yet; probe each on HEAD first)

A Go window floor of 10 s (conditional; no CI run shows a stalled ask, probed in loop 93); cycle timing on a real part (hardware). Dropped: the `nostd` ring driver (the Rust ring driver already uses `packbin::nostd`).
