# Handoff to loop 93

From the loop 92 record (`record92.md`). The hopper (`_docs/02_tasks/todo/`) and the backlog are empty after close.

## Shipped in loop 92

AZ-3452: the arm stage runs one image on `simavr` (ATmega328P) that checks `chacha20_xor` on a 16-bit `size_t`: RFC 8439 vector, 9 lengths, the 32-bit counter edge. First run found no defect. The row fails on a changed line, a hang, a missing or silent emulator.

## Owner input needed

- Apply the F44 ruleset (read the rulesets listing back), then tag `v0.4.0`. CS-D5 is decided (tables stay, loop 90).
- Whether to close the epic AZ-2750 in Jira.
- Unchanged: U24 in the C++ package; the M4F row; meshbell `FrameSession` rename; vcpkg `supports`; a public-key pairing step; multi-part MAC rows in the ring.
- The hopper is empty: loop 93 needs an owner decision from the list above or a new feature.

## Candidates (not specs yet; probe each on HEAD first)

A Go window floor of 10 s (conditional); a ring driver for `nostd`; a non-secure 128 KiB image; cycle timing on a real part. The AVR run is done: the wrap near 64 KiB stays unreachable on a 2 KB part.
